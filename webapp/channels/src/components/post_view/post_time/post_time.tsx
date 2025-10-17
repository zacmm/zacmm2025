// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

import React from 'react';
import type {ComponentProps} from 'react';
import {Link} from 'react-router-dom';

import * as GlobalActions from 'actions/global_actions';

import Timestamp, {RelativeRanges} from 'components/timestamp';
import WithTooltip from 'components/with_tooltip';

import {Locations} from 'utils/constants';
import {isMobile} from 'utils/user_agent';

const POST_TOOLTIP_RANGES = [
    RelativeRanges.TODAY_TITLE_CASE,
    RelativeRanges.YESTERDAY_TITLE_CASE,
];
const getTimeFormat: ComponentProps<typeof Timestamp>['useTime'] = (_, {hour, minute, second}) => ({hour, minute, second});

// 自訂時間格式化函數：Mon Sep 08 2025 下午2:43
function formatCustomTime(timestamp: number): string {
    const date = new Date(timestamp);
    const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    const weekday = weekdays[date.getDay()];
    const month = months[date.getMonth()];
    const day = String(date.getDate()).padStart(2, '0');
    const year = date.getFullYear();
    const hours = date.getHours();
    const minutes = String(date.getMinutes()).padStart(2, '0');

    const period = hours >= 12 ? '下午' : '上午';
    const hour12 = hours % 12 || 12;

    return `${weekday} ${month} ${day} ${year} ${period}${hour12}:${minutes}`;
}

type Props = {

    /*
     * If true, time will be rendered as a permalink to the post
     */
    isPermalink: boolean;

    /*
     * The time to display
     */
    eventTime: number;

    isMobileView: boolean;
    location: string;

    /*
     * The post id of posting being rendered
     */
    postId: string;
    teamUrl: string;
    timestampProps?: ComponentProps<typeof Timestamp>;
}

export default class PostTime extends React.PureComponent<Props> {
    static defaultProps: Partial<Props> = {
        eventTime: 0,
        location: Locations.CENTER,
    };

    handleClick = () => {
        if (this.props.isMobileView) {
            GlobalActions.emitCloseRightHandSide();
        }
    };

    render() {
        const {
            eventTime,
            isPermalink,
            location,
            postId,
            teamUrl,
            timestampProps = {},
        } = this.props;

        const postTime = (
            <span className='post__time'>
                {formatCustomTime(eventTime)}
            </span>
        );

        const content = isMobile() || !isPermalink ? (
            <div
                role='presentation'
                className='post__permalink post_permalink_mobile_view'
            >
                {postTime}
            </div>
        ) : (
            <Link
                id={`${location}_time_${postId}`}
                to={`${teamUrl}/pl/${postId}`}
                className='post__permalink'
                onClick={this.handleClick}
                aria-labelledby={eventTime.toString()}
            >
                {postTime}
            </Link>
        );

        return (
            <WithTooltip
                title={
                    <Timestamp
                        value={eventTime}
                        ranges={POST_TOOLTIP_RANGES}
                        useSemanticOutput={false}
                        useTime={getTimeFormat}
                    />
                }
            >
                {content}
            </WithTooltip>
        );
    }
}
