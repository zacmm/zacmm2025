// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

import {connect} from 'react-redux';

import type {Emoji as EmojiType} from '@mattermost/types/emojis';
import type {GlobalState} from '@mattermost/types/store';

import {getCustomEmojisByName} from 'mattermost-redux/selectors/entities/emojis';
import {getUser} from 'mattermost-redux/selectors/entities/users';
import {getEmojiImageUrl} from 'mattermost-redux/utils/emoji_utils';

import * as Emoji from 'utils/emoji';

import ReactionDetails from './reaction_details';

type OwnProps = {
    reactions: { [x: string]: import('@mattermost/types/reactions').Reaction } | undefined | null;
};

function mapStateToProps(state: GlobalState, ownProps: OwnProps) {
    const getEmojiUrl = (emojiName: string): string => {
        let emoji;
        if (Emoji.EmojiIndicesByAlias.has(emojiName)) {
            emoji = Emoji.Emojis[Emoji.EmojiIndicesByAlias.get(emojiName) as number];
        } else {
            const emojis = getCustomEmojisByName(state);
            emoji = emojis.get(emojiName);
        }

        if (emoji) {
            return getEmojiImageUrl(emoji as EmojiType);
        }
        return '';
    };

    return {
        getUser: (userId: string) => getUser(state, userId),
        getEmojiUrl,
    };
}

export default connect(mapStateToProps)(ReactionDetails); 