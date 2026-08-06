// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

import classNames from 'classnames';
import React from 'react';

type Props = {
    unreadMentions: number;
    unreadMsgs?: number;
    hasUrgent?: boolean;
    icon?: React.ReactNode;
    className?: string;
};

export default function ChannelMentionBadge({unreadMentions, unreadMsgs, hasUrgent, icon, className}: Props) {
    // 優先顯示提及數（mentions），如果沒有提及則顯示未讀訊息數
    const displayCount = unreadMentions > 0 ? unreadMentions : (unreadMsgs || 0);

    if (displayCount > 0) {
        return (
            <span
                id='unreadMentions'
                className={classNames({badge: true, urgent: hasUrgent}, className)}
            >
                {icon}
                <span className='unreadMentions'>
                    {displayCount}
                </span>
            </span>
        );
    }

    return null;
}
