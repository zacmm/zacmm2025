// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

import React from 'react';

import type {Emoji} from '@mattermost/types/emojis';
import type {Post} from '@mattermost/types/posts';
import type {Reaction as ReactionType} from '@mattermost/types/reactions';

import {getEmojiName} from 'mattermost-redux/utils/emoji_utils';

import {localizeMessage} from 'utils/utils';

import AddReactionButton from './add_reaction_button';

type Props = {

    /**
     * The post to render reactions for
     */
    post: Post;

    /*
     * The id of the team which belongs the post
     */
    teamId: string;

    /**
     * The reactions to render
     */
    reactions: { [x: string]: ReactionType } | undefined | null;

    /**
     * Whether or not the user can add reactions to this post.
     */
    canAddReactions: boolean;

    actions: {

        /**
         * Function to add a reaction to the post
         */
        toggleReaction: (postId: string, emojiName: string) => void;
    };
};

type State = {
    emojiNames: string[];
};

export default class ReactionList extends React.PureComponent<Props, State> {
    constructor(props: Props) {
        super(props);

        this.state = {
            emojiNames: [],
        };
    }

    static getDerivedStateFromProps(props: Props, state: State): Partial<State> | null {
        let emojiNames = state.emojiNames;

        for (const {emoji_name: emojiName} of Object.values(props.reactions ?? {})) {
            if (!emojiNames.includes(emojiName)) {
                emojiNames = [...emojiNames, emojiName];
            }
        }

        return (emojiNames === state.emojiNames) ? null : {emojiNames};
    }

    handleEmojiClick = (emoji: Emoji): void => {
        const emojiName = getEmojiName(emoji);
        this.props.actions.toggleReaction(this.props.post.id, emojiName);
    };

    render(): React.ReactNode {
        const reactionsByName = new Map();

        if (this.props.reactions) {
            for (const reaction of Object.values(this.props.reactions)) {
                const emojiName = reaction.emoji_name;

                if (reactionsByName.has(emojiName)) {
                    reactionsByName.get(emojiName).push(reaction);
                } else {
                    reactionsByName.set(emojiName, [reaction]);
                }
            }
        }

        // Only show the add reaction button if there are reactions or if user can add reactions
        if (reactionsByName.size === 0 && !this.props.canAddReactions) {
            return null;
        }

        let addReaction = null;
        if (this.props.canAddReactions) {
            addReaction = (
                <AddReactionButton
                    post={this.props.post}
                    teamId={this.props.teamId}
                    onEmojiClick={this.handleEmojiClick}
                />
            );
        }

        // Only render the add reaction button, not the individual reaction buttons
        return (
            <div
                aria-label={localizeMessage({id: 'reaction.container.ariaLabel', defaultMessage: 'reactions'})}
                className='post-reaction-list'
            >
                {addReaction}
            </div>
        );
    }
}
