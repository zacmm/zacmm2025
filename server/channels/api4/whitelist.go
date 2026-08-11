// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

// 本檔案為 fork 客製功能：每位使用者的 IP 白名單。
// 刻意獨立成檔，讓上游檔案只留下 api.go 的一行註冊，降低升級衝突面積。

package api4

import (
	"encoding/json"
	"net/http"

	"github.com/mattermost/mattermost/server/public/model"
	"github.com/mattermost/mattermost/server/public/shared/mlog"
)

func (api *API) InitWhitelist() {
	api.BaseRoutes.User.Handle("/whitelist", api.APISessionRequired(getUserWhitelist)).Methods(http.MethodGet)
	api.BaseRoutes.User.Handle("/whitelist", api.APISessionRequired(addUserToWhitelist)).Methods(http.MethodPost)
	api.BaseRoutes.User.Handle("/whitelist", api.APISessionRequired(removeUserFromWhitelist)).Methods(http.MethodDelete)
}

// whitelistResponse 對應前端 client4.ts 的 getWhitelist 回應型別。
type whitelistResponse struct {
	UserId string   `json:"user_id"`
	IPs    []string `json:"ips"`
}

// whitelistItemFromRequest 解析請求 body 的 IP，並補上路徑上的 user id。
func whitelistItemFromRequest(c *Context, r *http.Request) *model.WhitelistItem {
	var item model.WhitelistItem
	if jsonErr := json.NewDecoder(r.Body).Decode(&item); jsonErr != nil {
		c.SetInvalidParamWithErr("request body", jsonErr)
		return nil
	}

	item.UserId = c.Params.UserId
	if appErr := item.IsValid(); appErr != nil {
		c.Err = appErr
		return nil
	}

	return &item
}

func getUserWhitelist(c *Context, w http.ResponseWriter, r *http.Request) {
	c.RequireUserId()
	if c.Err != nil {
		return
	}

	if !c.App.SessionHasPermissionToUser(*c.AppContext.Session(), c.Params.UserId) {
		c.SetPermissionError(model.PermissionEditOtherUsers)
		return
	}

	ips, err := c.App.GetUserWhitelistIPs(c.Params.UserId)
	if err != nil {
		c.Err = err
		return
	}

	if err := json.NewEncoder(w).Encode(whitelistResponse{UserId: c.Params.UserId, IPs: ips}); err != nil {
		c.Logger.Warn("Error while writing response", mlog.Err(err))
	}
}

func addUserToWhitelist(c *Context, w http.ResponseWriter, r *http.Request) {
	c.RequireUserId()
	if c.Err != nil {
		return
	}

	if !c.App.SessionHasPermissionToUser(*c.AppContext.Session(), c.Params.UserId) {
		c.SetPermissionError(model.PermissionEditOtherUsers)
		return
	}

	item := whitelistItemFromRequest(c, r)
	if c.Err != nil {
		return
	}

	auditRec := c.MakeAuditRecord("addUserToWhitelist", model.AuditStatusFail)
	defer c.LogAuditRec(auditRec)
	model.AddEventParameterToAuditRec(auditRec, "user_id", item.UserId)
	model.AddEventParameterToAuditRec(auditRec, "ip", item.IP)

	if err := c.App.AddUserToWhitelist(c.AppContext, item.UserId, item.IP); err != nil {
		c.Err = err
		return
	}

	auditRec.Success()

	ReturnStatusOK(w)
}

func removeUserFromWhitelist(c *Context, w http.ResponseWriter, r *http.Request) {
	c.RequireUserId()
	if c.Err != nil {
		return
	}

	if !c.App.SessionHasPermissionToUser(*c.AppContext.Session(), c.Params.UserId) {
		c.SetPermissionError(model.PermissionEditOtherUsers)
		return
	}

	item := whitelistItemFromRequest(c, r)
	if c.Err != nil {
		return
	}

	auditRec := c.MakeAuditRecord("removeUserFromWhitelist", model.AuditStatusFail)
	defer c.LogAuditRec(auditRec)
	model.AddEventParameterToAuditRec(auditRec, "user_id", item.UserId)
	model.AddEventParameterToAuditRec(auditRec, "ip", item.IP)

	if err := c.App.RemoveUserFromWhitelist(c.AppContext, item.UserId, item.IP); err != nil {
		c.Err = err
		return
	}

	auditRec.Success()

	ReturnStatusOK(w)
}
