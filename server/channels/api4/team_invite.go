// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

// 本檔案為 fork 客製功能：取得團隊邀請碼。
// 刻意獨立成檔，讓上游檔案只留下 api.go 的一行註冊，降低升級衝突面積。

package api4

import (
	"encoding/json"
	"net/http"

	"github.com/mattermost/mattermost/server/public/model"
	"github.com/mattermost/mattermost/server/public/shared/mlog"
)

func (api *API) InitTeamInvite() {
	api.BaseRoutes.Team.Handle("/invite_id", api.APISessionRequired(getInviteId)).Methods(http.MethodGet)
}

func getInviteId(c *Context, w http.ResponseWriter, r *http.Request) {
	c.RequireTeamId()
	if c.Err != nil {
		return
	}

	if !c.App.SessionHasPermissionToTeam(*c.AppContext.Session(), c.Params.TeamId, model.PermissionInviteUser) {
		c.SetPermissionError(model.PermissionInviteUser)
		return
	}

	auditRec := c.MakeAuditRecord("getInviteId", model.AuditStatusFail)
	defer c.LogAuditRec(auditRec)
	model.AddEventParameterToAuditRec(auditRec, "team_id", c.Params.TeamId)

	inviteId, err := c.App.GetInviteId(c.Params.TeamId)
	if err != nil {
		c.Err = err
		return
	}

	auditRec.Success()

	// 不記錄 invite_id 本身——它是可直接用來加入團隊的憑證。
	if err := json.NewEncoder(w).Encode(model.InviteItem{InviteId: inviteId, TeamId: c.Params.TeamId}); err != nil {
		c.Logger.Warn("Error while writing response", mlog.Err(err))
	}
}
