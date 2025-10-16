// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

package app

import (
	"net"
	"net/http"
	"strings"

	"github.com/mattermost/mattermost/server/public/model"
	"github.com/mattermost/mattermost/server/public/shared/mlog"
	"github.com/mattermost/mattermost/server/public/shared/request"
)

// AddUserToWhitelist adds an IP address to a user's whitelist
func (a *App) AddUserToWhitelist(c request.CTX, userId, ipAddress string) *model.AppError {
	// Validate user exists
	if _, err := a.GetUser(userId); err != nil {
		return err
	}

	// Validate IP address format
	if !isValidIPAddress(ipAddress) {
		return model.NewAppError("AddUserToWhitelist", "app.whitelist.invalid_ip.app_error", nil, "ip="+ipAddress, http.StatusBadRequest)
	}

	whitelistItem := &model.WhitelistItem{
		UserId: userId,
		IP:     ipAddress,
	}

	if err := a.Srv().Store().Whitelist().Add(whitelistItem); err != nil {
		return model.NewAppError("AddUserToWhitelist", "app.whitelist.add.app_error", nil, "", http.StatusInternalServerError).Wrap(err)
	}

	c.Logger().Info("Added IP to user whitelist", mlog.String("user_id", userId), mlog.String("ip", ipAddress))
	return nil
}

// RemoveUserFromWhitelist removes an IP address from a user's whitelist
func (a *App) RemoveUserFromWhitelist(c request.CTX, userId, ipAddress string) *model.AppError {
	whitelistItem := &model.WhitelistItem{
		UserId: userId,
		IP:     ipAddress,
	}

	if err := a.Srv().Store().Whitelist().Delete(whitelistItem); err != nil {
		return model.NewAppError("RemoveUserFromWhitelist", "app.whitelist.delete.app_error", nil, "", http.StatusInternalServerError).Wrap(err)
	}

	c.Logger().Info("Removed IP from user whitelist", mlog.String("user_id", userId), mlog.String("ip", ipAddress))
	return nil
}

// GetUserWhitelistIPs gets all whitelisted IP addresses for a user
func (a *App) GetUserWhitelistIPs(userId string) ([]string, *model.AppError) {
	ips, err := a.Srv().Store().Whitelist().GetByUserId(userId)
	if err != nil {
		return nil, model.NewAppError("GetUserWhitelistIPs", "app.whitelist.get.app_error", nil, "", http.StatusInternalServerError).Wrap(err)
	}

	return ips, nil
}

// CheckUserIPWhitelisted checks if a user's IP is whitelisted
func (a *App) CheckUserIPWhitelisted(c request.CTX, userId string, ipAddresses []string) (bool, *model.AppError) {
	if userId == "" {
		return true, nil
	}

	user, err := a.GetUser(userId)
	if err != nil {
		return false, err
	}

	// System admins bypass IP whitelist
	if a.RolesGrantPermission(user.GetRoles(), model.PermissionManageSystem.Id) {
		c.Logger().Debug("System admin bypassing IP whitelist", mlog.String("user_id", userId))
		return true, nil
	}

	// Team admins bypass IP whitelist
	teamMembers, teamErr := a.GetTeamMembersForUser(c, userId, "", false)
	if teamErr != nil {
		c.Logger().Warn("Failed to get team members for IP whitelist check", mlog.String("user_id", userId), mlog.Err(teamErr))
		// Continue with normal whitelist check even if we can't get team members
	} else {
		// Check if user is admin of any team
		for _, teamMember := range teamMembers {
			if teamMember.SchemeAdmin {
				c.Logger().Debug("Team admin bypassing IP whitelist", mlog.String("user_id", userId), mlog.String("team_id", teamMember.TeamId))
				return true, nil
			}
		}
	}

	// Get user's whitelisted IPs
	whitelistedIPs, appErr := a.GetUserWhitelistIPs(userId)
	if appErr != nil {
		return false, appErr
	}

	// If no IPs are whitelisted, deny access (user needs to set up whitelist to use the system)
	if len(whitelistedIPs) == 0 {
		return false, nil
	}

	// Check if current IP is in the whitelist
	for _, whitelistedIP := range whitelistedIPs {
		for _, ipAddress := range ipAddresses {
			if ipAddress == whitelistedIP {
				c.Logger().Debug("IP found in whitelist", mlog.String("user_id", userId), mlog.String("ip", ipAddress))
				return true, nil
			}
		}
	}

	// IP not in whitelist - deny access
	return false, nil
}

// GetClientIPAddress extracts the real client IP from the request
func (a *App) GetClientIPAddress(r *http.Request) string {
	// Check X-Forwarded-For header first (for load balancers/proxies)
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		// X-Forwarded-For can contain multiple IPs, take the first one
		ips := strings.Split(xff, ",")
		if len(ips) > 0 {
			ip := strings.TrimSpace(ips[0])
			if isValidIPAddress(ip) {
				return ip
			}
		}
	}

	// Check X-Real-IP header (common with nginx)
	if xri := r.Header.Get("X-Real-IP"); xri != "" {
		if isValidIPAddress(xri) {
			return xri
		}
	}

	// Fall back to RemoteAddr
	ip, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		// If SplitHostPort fails, RemoteAddr might be just an IP
		if isValidIPAddress(r.RemoteAddr) {
			return r.RemoteAddr
		}
		return ""
	}

	return ip
}

// isValidIPAddress validates if a string is a valid IPv4 or IPv6 address
func isValidIPAddress(ip string) bool {
	return net.ParseIP(ip) != nil
}

// WhitelistMiddleware is the middleware function that checks IP whitelist for authenticated users
// This is a standalone middleware that can be used independently if needed
func (a *App) WhitelistMiddleware(handler http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// For now, this middleware is not used since we integrated the check directly into the Handler
		// This is kept for potential future use or alternative integration approaches
		handler.ServeHTTP(w, r)
	})
}

// shouldSkipWhitelistCheck determines if the whitelist check should be skipped for certain paths
func (a *App) shouldSkipWhitelistCheck(path string) bool {
	skipPaths := []string{
		"/api/v4/users/login",
		"/api/v4/users/logout",
		"/api/v4/system/ping",
		"/api/v4/config/client",
		"/login",
		"/signup",
		"/static/",
		"/fonts/",
		"/images/",
	}

	for _, skipPath := range skipPaths {
		if strings.HasPrefix(path, skipPath) {
			return true
		}
	}

	return false
} 