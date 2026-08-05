// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

package sqlstore

import (
	"github.com/pkg/errors"
	sq "github.com/mattermost/squirrel"
	"github.com/mattermost/mattermost/server/public/model"
	"github.com/mattermost/mattermost/server/v8/channels/store"
)

type SqlInviteStore struct {
	*SqlStore
}

func newSqlInviteStore(sqlStore *SqlStore) store.InviteStore {
	return &SqlInviteStore{
		SqlStore: sqlStore,
	}
}

func (s SqlInviteStore) Add(inviteItem *model.InviteItem) error {
	_, err := s.GetMaster().Exec(
		"INSERT INTO Invites (InviteId, TeamId) VALUES (?, ?)",
		inviteItem.InviteId, inviteItem.TeamId,
	)
	if err != nil {
		return errors.Wrapf(err, "failed to save invite item with invite_id=%s and team_id=%s", inviteItem.InviteId, inviteItem.TeamId)
	}
	return nil
}

func (s SqlInviteStore) Delete(inviteId string) error {
	_, err := s.GetMaster().Exec("DELETE FROM Invites WHERE InviteId = ?", inviteId)
	if err != nil {
		return errors.Wrapf(err, "failed to delete from Invites with invite id=%s", inviteId)
	}
	return nil
}

func (s SqlInviteStore) GetTeamId(inviteId string) (string, error) {
	var teamId string
	query := s.getQueryBuilder().
		Select("TeamId").
		From("Invites").
		Where(sq.Eq{"InviteId": inviteId})
	queryString, args, err := query.ToSql()
	if err != nil {
		return "", errors.Wrap(err, "get_team_id_tosql")
	}
	if err := s.GetReplica().Get(&teamId, queryString, args...); err != nil {
		return "", errors.Wrap(err, "failed to find team for invite")
	}
	return teamId, nil
} 