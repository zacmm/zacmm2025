// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

import React from 'react';

import type {UserProfile} from '@mattermost/types/users';
import type {Reaction as ReactionType} from '@mattermost/types/reactions';

import Avatar from 'components/widgets/users/avatar/avatar';

import {imageURLForUser} from 'utils/utils';

import './reaction_details.scss';

type Props = {
    reactions: { [x: string]: ReactionType } | undefined | null;
    getUser: (userId: string) => UserProfile | undefined;
    getEmojiUrl: (emojiName: string) => string;
};

const ReactionDetails: React.FC<Props> = ({reactions, getUser, getEmojiUrl}) => {
    if (!reactions || Object.keys(reactions).length === 0) {
        return null;
    }

    // Group reactions by emoji
    const reactionsByEmoji = new Map<string, ReactionType[]>();
    
    Object.values(reactions).forEach((reaction) => {
        const emojiName = reaction.emoji_name;
        if (reactionsByEmoji.has(emojiName)) {
            reactionsByEmoji.get(emojiName)!.push(reaction);
        } else {
            reactionsByEmoji.set(emojiName, [reaction]);
        }
    });

    // Sort reactions by emoji name for consistent display
    const sortedEmojis = Array.from(reactionsByEmoji.keys()).sort();

    const formatDate = (createAt: number): string => {
        const date = new Date(createAt);
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        return `${month}/${day}`;
    };

    const formatTime = (createAt: number): string => {
        const date = new Date(createAt);
        const hours = String(date.getHours()).padStart(2, '0');
        const minutes = String(date.getMinutes()).padStart(2, '0');
        return `${hours}:${minutes}`;
    };

    return (
        <div className='reaction-details'>
            {sortedEmojis.map((emojiName) => {
                const emojiReactions = reactionsByEmoji.get(emojiName) || [];
                
                // Sort reactions by timestamp (oldest first)
                const sortedReactions = emojiReactions.sort((a, b) => a.create_at - b.create_at);

                return (
                    <div key={emojiName} className='reaction-details__emoji-group'>
                        <div className='reaction-details__reactions'>
                            {sortedReactions.map((reaction) => {
                                const user = getUser(reaction.user_id);
                                const displayName = user ? (user.nickname || user.username || 'Unknown User') : 'Unknown User';
                                const date = formatDate(reaction.create_at);
                                const time = formatTime(reaction.create_at);

                                return (
                                    <div key={`${reaction.user_id}-${reaction.emoji_name}`} className='reaction-details__reaction'>
                                        <div className='reaction-details__user-row'>
                                            <span className='reaction-details__date'>{date}</span>
                                            <span className='reaction-details__time'>{time}</span>
                                            <span className='reaction-details__username'>{displayName}</span>
                                            <Avatar
                                                username={user?.username}
                                                url={imageURLForUser(reaction.user_id, user?.last_picture_update)}
                                                size='sm'
                                                className='reaction-details__user-avatar'
                                            />
                                        </div>
                                        <div className='reaction-details__emoji-row'>
                                            <img
                                                src={getEmojiUrl(emojiName)}
                                                alt={emojiName}
                                                className='reaction-details__emoji-icon'
                                            />
                                        </div>
                                    </div>
                                );
                            })}
                        </div>
                    </div>
                );
            })}
        </div>
    );
};

export default ReactionDetails; 