// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

// 本檔案為 fork 客製功能：管理後台的訊息篩選與批次刪除（/api/v4/posts_all）。
// 刻意獨立成檔，讓上游檔案只留下 api.go 的一行註冊，降低升級衝突面積。

package api4

import (
	"bytes"
	"io"
	"net/http"
	"strconv"

	"github.com/mattermost/mattermost/server/public/model"
	"github.com/mattermost/mattermost/server/public/shared/mlog"
)

func (api *API) InitPostsAdmin() {
	api.BaseRoutes.PostsAll.Handle("", api.APISessionRequired(getAllPosts)).Methods(http.MethodPost)
	api.BaseRoutes.PostsAll.Handle("", api.APISessionRequired(removePostsBetween)).Methods(http.MethodDelete)
}

func getAllPosts(c *Context, w http.ResponseWriter, r *http.Request) {
	c.Logger.Debug("=== getAllPosts handler START ===")

	if !c.IsSystemAdmin() {
		c.Logger.Debug("getAllPosts: User is not system admin", mlog.String("user_id", c.AppContext.Session().UserId))
		c.SetPermissionError(model.PermissionEditOtherUsers)
		return
	}
	c.Logger.Debug("getAllPosts: System admin check passed", mlog.String("user_id", c.AppContext.Session().UserId))

	// Read raw body for debugging
	bodyBytes, err := io.ReadAll(r.Body)
	if err != nil {
		c.Logger.Error("getAllPosts: Failed to read request body", mlog.Err(err))
		c.SetInvalidParam("body")
		return
	}
	c.Logger.Debug("getAllPosts: Raw request body", mlog.String("body", string(bodyBytes)))

	// Restore body for parsing
	r.Body = io.NopCloser(bytes.NewReader(bodyBytes))

	options := model.GetAllPostsOptionsFromJson(r.Body)
	if options == nil {
		c.Logger.Error("getAllPosts: Failed to parse options from JSON", mlog.String("raw_body", string(bodyBytes)))
		c.SetInvalidParam("options")
		return
	}

	c.Logger.Debug("getAllPosts: Parsed options",
		mlog.String("userId", options.UserId),
		mlog.String("keyword", options.Keyword),
		mlog.Int("startDate", int(options.StartDate)),
		mlog.Int("endDate", int(options.EndDate)),
		mlog.Int("page", options.Page),
		mlog.Int("perPage", options.PerPage))

	c.Logger.Debug("getAllPosts: Calling c.App.GetAllPosts")
	list, totalPosts, postInfoMap, appErr := c.App.GetAllPosts(c.AppContext, options)
	if appErr != nil {
		c.Logger.Error("getAllPosts: c.App.GetAllPosts failed", mlog.Err(appErr))
		c.Err = appErr
		return
	}
	c.Logger.Debug("getAllPosts: c.App.GetAllPosts succeeded",
		mlog.Int("totalPosts", totalPosts),
		mlog.Int("listCount", len(list.Posts)))

	totalPages := 0
	if len(list.Posts) > 0 && options.PerPage > 0 {
		totalPages = totalPosts/options.PerPage + 1
	}

	allPosts := model.AllPosts{
		List:        list,
		PostInfoMap: postInfoMap,
		TotalPages:  totalPages,
	}

	c.Logger.Debug("getAllPosts: Returning response", mlog.Int("totalPages", totalPages))
	w.Write([]byte(allPosts.ToJson()))
	c.Logger.Debug("=== getAllPosts handler END ===")
}

func removePostsBetween(c *Context, w http.ResponseWriter, r *http.Request) {
	if !c.IsSystemAdmin() {
		c.SetPermissionError(model.PermissionEditOtherUsers)
		return
	}

	options := model.RemovePostsBetweenOptionsFromJson(r.Body)
	if options == nil {
		c.SetInvalidParam("options")
		return
	}

	removed, err := c.App.RemovePostsBetween(c.AppContext, options)
	if err != nil {
		c.Err = err
		return
	}

	w.Write([]byte(strconv.Itoa(removed)))
}
