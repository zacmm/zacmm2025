// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

package active_users

import (
	"github.com/mattermost/mattermost/server/public/model"
	"github.com/mattermost/mattermost/server/public/shared/mlog"
	"github.com/mattermost/mattermost/server/v8/channels/jobs"
	"github.com/mattermost/mattermost/server/v8/channels/store"
	"github.com/mattermost/mattermost/server/v8/einterfaces"
)

func MakeWorker(jobServer *jobs.JobServer, store store.Store, getMetrics func() einterfaces.MetricsInterface) *jobs.SimpleWorker {
	const workerName = "ActiveUsers"

	isEnabled := func(cfg *model.Config) bool {
		return *cfg.MetricsSettings.Enable
	}
	execute := func(logger mlog.LoggerIFace, job *model.Job) error {
		defer jobServer.HandleJobPanic(logger, job)

		count, err := store.User().Count(model.UserCountOptions{IncludeDeleted: false})
		if err != nil {
			return err
		}

		if getMetrics() != nil {
			getMetrics().ObserveEnabledUsers(count)
		}
		return nil
	}
	worker := jobs.NewSimpleWorker(workerName, jobServer, execute, isEnabled)
	return worker
}
