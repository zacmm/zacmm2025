// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

package notify_admin

import (
	"strconv"
	"time"

	"github.com/mattermost/mattermost/server/public/model"
	"github.com/mattermost/mattermost/server/public/shared/mlog"
	"github.com/mattermost/mattermost/server/v8/channels/jobs"
)

const installPluginSchedFreq = 24 * time.Hour

func MakeInstallPluginScheduler(jobServer *jobs.JobServer, license *model.License, jobType string) *jobs.PeriodicScheduler {
	isEnabled := func(cfg *model.Config) bool {
		enabled := jobType == model.JobTypeInstallPluginNotifyAdmin
		mlog.Debug("Scheduler: isEnabled: "+strconv.FormatBool(enabled), mlog.String("scheduler", jobType))
		return enabled
	}
	return jobs.NewPeriodicScheduler(jobServer, jobType, installPluginSchedFreq, isEnabled)
}
