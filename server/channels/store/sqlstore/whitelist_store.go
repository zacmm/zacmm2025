// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

package sqlstore

import (
	"github.com/pkg/errors"

	sq "github.com/mattermost/squirrel"
	"github.com/mattermost/mattermost/server/public/model"
	"github.com/mattermost/mattermost/server/v8/channels/store"
)

type SqlWhitelistStore struct {
	*SqlStore
}

func newSqlWhitelistStore(sqlStore *SqlStore) store.WhitelistStore {
	s := &SqlWhitelistStore{
		SqlStore: sqlStore,
	}

	return s
}

func (s SqlWhitelistStore) createIndexesIfNotExists() {
	// Indexes are created via database migrations
}

func (s SqlWhitelistStore) Add(whitelistItem *model.WhitelistItem) error {
	if len(whitelistItem.UserId) == 0 {
		return store.NewErrInvalidInput("whitelist item", "user id", whitelistItem.UserId)
	}

	if len(whitelistItem.IP) == 0 {
		return store.NewErrInvalidInput("whitelist item", "ip", whitelistItem.IP)
	}

	if _, err := s.GetMaster().NamedExec(`INSERT INTO Whitelist (UserId, IP) VALUES (:UserId, :IP)`, whitelistItem); err != nil {
		return errors.Wrapf(err, "failed to save whitelist item with user_id=%s and ip=%s", whitelistItem.UserId, whitelistItem.IP)
	}

	return nil
}

func (s SqlWhitelistStore) Delete(whitelistItem *model.WhitelistItem) error {
	_, err := s.GetMaster().Exec("DELETE FROM Whitelist WHERE UserId = ? AND IP = ?", whitelistItem.UserId, whitelistItem.IP)
	if err != nil {
		return errors.Wrapf(err, "failed to delete from Whitelist with user id=%s and ip=%s", whitelistItem.UserId, whitelistItem.IP)
	}

	return nil
}

func (s SqlWhitelistStore) GetByUserId(userId string) ([]string, error) {
	var ips []string

	query := s.getQueryBuilder().
		Select("IP").
		From("Whitelist").
		Where(sq.Eq{"UserId": userId})

	queryString, args, err := query.ToSql()
	if err != nil {
		return []string{}, errors.Wrap(err, "whitelist_tosql")
	}

	if err := s.GetReplica().Select(&ips, queryString, args...); err != nil {
		return []string{}, errors.Wrap(err, "failed to find ips")
	}

	return ips, nil
} 