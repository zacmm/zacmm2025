// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

package model

import (
	"encoding/json"
	"io"
)

// WhitelistItem represents an IP address whitelisted for a specific user
type WhitelistItem struct {
	UserId string `json:"user_id"` // User ID
	IP     string `json:"ip"`      // IP address from the whitelist
}

func (o *WhitelistItem) ToJSON() string {
	b, _ := json.Marshal(o)
	return string(b)
}

func WhitelistItemFromJSON(data io.Reader) *WhitelistItem {
	var o *WhitelistItem
	json.NewDecoder(data).Decode(&o)
	return o
}

func (o *WhitelistItem) IsValid() *AppError {
	if !IsValidId(o.UserId) {
		return NewAppError("WhitelistItem.IsValid", "model.whitelist_item.is_valid.user_id.app_error", nil, "", 400)
	}

	if len(o.IP) == 0 || len(o.IP) > 39 {
		return NewAppError("WhitelistItem.IsValid", "model.whitelist_item.is_valid.ip.app_error", nil, "", 400)
	}

	return nil
} 