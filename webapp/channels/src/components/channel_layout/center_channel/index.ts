// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

import {connect} from 'react-redux';
import type {ConnectedProps} from 'react-redux';
import {withRouter} from 'react-router-dom';
import type {RouteComponentProps} from 'react-router-dom';
import {bindActionCreators} from 'redux';
import type {Dispatch} from 'redux';

import {getProfiles} from 'mattermost-redux/actions/users';
import {getRedirectChannelNameForTeam} from 'mattermost-redux/selectors/entities/channels';
import {isCollapsedThreadsEnabled} from 'mattermost-redux/selectors/entities/preferences';
import {getTeamByName} from 'mattermost-redux/selectors/entities/teams';
import {getCurrentUserId} from 'mattermost-redux/selectors/entities/users';

import {getIsLhsOpen} from 'selectors/lhs';
import {getLastViewedChannelNameByTeamName, getLastViewedTypeByTeamName, getPreviousTeamId, getPreviousTeamLastViewedType} from 'selectors/local_storage';
import {getIsRhsOpen, getIsRhsMenuOpen} from 'selectors/rhs';
import {getIsMobileView} from 'selectors/views/browser';

import {PreviousViewedTypes} from 'utils/constants';

import type {GlobalState} from 'types/store';

import CenterChannel from './center_channel';

type Params = {
    team: string;
}

export type OwnProps = RouteComponentProps<Params>;

const mapStateToProps = (state: GlobalState, ownProps: OwnProps) => {
    const lastViewedType = getLastViewedTypeByTeamName(state, ownProps.match.params.team);
    let channelName = getLastViewedChannelNameByTeamName(state, ownProps.match.params.team);

    const previousTeamId = getPreviousTeamId(state);
    const team = getTeamByName(state, ownProps.match.params.team);

    let previousTeamLastViewedType;

    if (previousTeamId !== team?.id) {
        previousTeamLastViewedType = getPreviousTeamLastViewedType(state);
    }

    if (!channelName) {
        channelName = getRedirectChannelNameForTeam(state, team!.id);
    }

    let lastChannelPath;
    if (isCollapsedThreadsEnabled(state) && (previousTeamLastViewedType === PreviousViewedTypes.THREADS || lastViewedType === PreviousViewedTypes.THREADS)) {
        lastChannelPath = `${ownProps.match.url}/threads`;
    } else {
        lastChannelPath = `${ownProps.match.url}/channels/${channelName}`;
    }

    return {
        lastChannelPath,
        lhsOpen: getIsLhsOpen(state),
        rhsOpen: getIsRhsOpen(state),
        rhsMenuOpen: getIsRhsMenuOpen(state),
        isCollapsedThreadsEnabled: isCollapsedThreadsEnabled(state),
        currentUserId: getCurrentUserId(state),
        isMobileView: getIsMobileView(state),
    };
};

function mapDispatchToProps(dispatch: Dispatch) {
    return {
        actions: bindActionCreators({
            getProfiles,
        }, dispatch),
    };
}

const connector = connect(mapStateToProps, mapDispatchToProps);

export type PropsFromRedux = ConnectedProps<typeof connector>;

export default withRouter(connector(CenterChannel));

