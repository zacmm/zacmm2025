// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

import React, {useCallback, useState} from 'react';
import {defineMessages, useIntl} from 'react-intl';

import type {Team} from '@mattermost/types/teams';

import SettingItem from 'components/setting_item';
import SettingItemMax from 'components/setting_item_max';

import Constants from 'utils/constants';
import {copyToClipboard} from 'utils/utils';

import type {PropsFromRedux, OwnProps} from '.';

const translations = defineMessages({
    TeamInviteLink: {
        id: 'team_settings.team_invite_link',
        defaultMessage: 'Team Invite Link',
    },
    TeamInviteLinkDescription: {
        id: 'team_settings.team_invite_link_description',
        defaultMessage: 'Share this link with others to invite them to your team.',
    },
    RegenerateLink: {
        id: 'team_settings.regenerate_link',
        defaultMessage: 'Regenerate Link',
    },
    CopyLink: {
        id: 'team_settings.copy_link',
        defaultMessage: 'Copy Link',
    },
    LinkCopied: {
        id: 'team_settings.link_copied',
        defaultMessage: 'Link copied!',
    },
    LinkCopiedError: {
        id: 'team_settings.link_copied_error',
        defaultMessage: 'Failed to copy link',
    },
    GenerateLinkError: {
        id: 'team_settings.generate_link_error',
        defaultMessage: 'Failed to generate invite link',
    },
});

type Props = PropsFromRedux & OwnProps & {
    team: Team;
};

const TeamInviteSection = ({team, actions}: Props) => {
    const [inviteId, setInviteId] = useState<string>('');
    const [loading, setLoading] = useState<boolean>(false);
    const [copied, setCopied] = useState<boolean>(false);
    const {formatMessage} = useIntl();

    const generateInviteLink = useCallback(async () => {
        setLoading(true);
        try {
            const result = await actions.getTeamInviteId(team.id);
            if (result.error) {
                console.error('Failed to generate invite link:', result.error);
                return;
            }
            setInviteId(result.data || '');
        } catch (error) {
            console.error('Error generating invite link:', error);
        } finally {
            setLoading(false);
        }
    }, [actions, team.id]);

    const copyInviteLink = useCallback(async () => {
        if (!inviteId) {
            return;
        }

        const inviteLink = `${window.location.origin}/signup_user_complete/?id=${inviteId}`;
        const success = await copyToClipboard(inviteLink);
        
        if (success) {
            setCopied(true);
            setTimeout(() => setCopied(false), 2000);
        }
    }, [inviteId]);

    const inviteLink = inviteId ? `${window.location.origin}/signup_user_complete/?id=${inviteId}` : '';

    return (
        <SettingItemMax
            title={formatMessage(translations.TeamInviteLink)}
            describe={formatMessage(translations.TeamInviteLinkDescription)}
            section='team-invite'
        >
            <div className='team-invite-section'>
                <div className='team-invite-link-container'>
                    <input
                        type='text'
                        className='form-control'
                        value={inviteLink}
                        readOnly
                        placeholder={formatMessage(translations.TeamInviteLink)}
                    />
                    <button
                        type='button'
                        className='btn btn-primary'
                        onClick={copyInviteLink}
                        disabled={!inviteId}
                    >
                        {copied ? formatMessage(translations.LinkCopied) : formatMessage(translations.CopyLink)}
                    </button>
                </div>
                <button
                    type='button'
                    className='btn btn-secondary'
                    onClick={generateInviteLink}
                    disabled={loading}
                >
                    {loading ? 'Generating...' : formatMessage(translations.RegenerateLink)}
                </button>
            </div>
        </SettingItemMax>
    );
};

export default TeamInviteSection; 