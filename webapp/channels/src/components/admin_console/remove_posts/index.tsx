// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

import React, {useState} from 'react';
import {FormattedMessage} from 'react-intl';
import {Permissions} from 'mattermost-redux/constants';

import {adminRemovePostsBetween} from 'actions/admin_actions';

import AdminHeader from 'components/widgets/admin_console/admin_header';
import SystemPermissionGate from 'components/permissions_gates/system_permission_gate';

import './remove_posts.scss';

export default function RemovePosts() {
    const [startTime, setStartTime] = useState(() => {
        const now = new Date();
        now.setHours(0, 0, 0, 0);
        return getTimeForInput(now);
    });
    const [endTime, setEndTime] = useState(() => {
        const now = new Date();
        now.setHours(23, 59, 59, 999);
        return getTimeForInput(now);
    });
    const [postsRemoved, setPostsRemoved] = useState(0);
    const [showPostsRemoved, setShowPostsRemoved] = useState(false);

    function getTimeForInput(date: Date): string {
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        const hours = String(date.getHours()).padStart(2, '0');
        const minutes = String(date.getMinutes()).padStart(2, '0');
        return `${year}-${month}-${day}T${hours}:${minutes}`;
    }

    const setStartTimeHandler = (e: React.ChangeEvent<HTMLInputElement>) => {
        setStartTime(e.target.value);
    };

    const setEndTimeHandler = (e: React.ChangeEvent<HTMLInputElement>) => {
        setEndTime(e.target.value);
    };

    const removePosts = () => {
        const startTimestamp = new Date(startTime).getTime();
        const endTimestamp = new Date(endTime).getTime();
        
        if (startTimestamp >= endTimestamp) {
            alert('Start time must be before end time');
            return;
        }

        adminRemovePostsBetween({
            startTime: startTimestamp,
            endTime: endTimestamp,
        }, (response: number) => {
            setPostsRemoved(response);
            setShowPostsRemoved(true);
        });
    };

    return (
        <div className='wrapper--fixed'>
            <AdminHeader>
                <FormattedMessage
                    id='admin.remove_posts.title'
                    defaultMessage='手動刪除訊息'
                />
            </AdminHeader>

            <div className='admin-console__wrapper'>
                <div className='admin-console__content'>
                    <SystemPermissionGate permissions={[Permissions.REVOKE_USER_ACCESS_TOKEN]}>
                        <div className='form-horizontal'>
                            <div className="date-selector">
                                <label htmlFor="startTime">From:</label>
                                <input 
                                    name="startTime" 
                                    type="datetime-local" 
                                    value={startTime} 
                                    onChange={setStartTimeHandler} 
                                />
                                <label htmlFor="endTime">To:</label>
                                <input 
                                    name="endTime" 
                                    type="datetime-local" 
                                    value={endTime} 
                                    onChange={setEndTimeHandler} 
                                />
                                <button
                                    onClick={removePosts}
                                    type='button'
                                    className='btn btn-primary'
                                    data-testid='removePostsButton'
                                >
                                    <FormattedMessage
                                        id='admin.posts.remove'
                                        defaultMessage='Remove'
                                    />
                                </button>
                            </div>
                            {showPostsRemoved && (
                                <p>
                                    <FormattedMessage
                                        id='admin.remove_posts.result'
                                        defaultMessage='Posts removed: {count}'
                                        values={{count: postsRemoved}}
                                    />
                                </p>
                            )}
                        </div>
                    </SystemPermissionGate>
                </div>
            </div>
        </div>
    );
} 