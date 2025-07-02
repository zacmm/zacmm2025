// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

import type {ReactNode} from 'react';
import {connect} from 'react-redux';
import type {ConnectedProps} from 'react-redux';

import type {Post} from '@mattermost/types/posts';

import {toggleInlineImageVisibility} from 'actions/post_actions';
import {isInlineImageVisible} from 'selectors/posts';

import type {GlobalState} from 'types/store';

import MarkdownImageExpand from './markdown_image_expand';

export type OwnProps = {
    postId: Post['id'];
    imageKey: string;
    alt: string;
    onToggle?: (visible: boolean) => void;
    children: ReactNode;
}

const mapStateToProps = (state: GlobalState, {postId, imageKey}: OwnProps) => {
    return {
        isExpanded: isInlineImageVisible(state, postId, imageKey),
    };
};

const mapDispatchToProps = {
    toggleInlineImageVisibility,
};

const connector = connect(mapStateToProps, mapDispatchToProps);

export type PropsFromRedux = ConnectedProps<typeof connector>;

export default connector(MarkdownImageExpand);
