// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

package model

type PostInfo struct {
	ChannelId          string      `json:"channel_id"`
	ChannelType        ChannelType `json:"channel_type"`
	ChannelDisplayName string      `json:"channel_display_name"`
	HasJoinedChannel   bool        `json:"has_joined_channel"`
	TeamId             string      `json:"team_id"`
	TeamType           string      `json:"team_type"`
	TeamDisplayName    string      `json:"team_display_name"`
	HasJoinedTeam      bool        `json:"has_joined_team"`
	// Legacy fields for admin posts functionality
	ChannelName string `json:"channel_name,omitempty"`
	TeamName    string `json:"team_name,omitempty"`
	Members     string `json:"members,omitempty"`
}
