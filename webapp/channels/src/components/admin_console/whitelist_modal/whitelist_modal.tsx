// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

import React, {useRef, useState} from 'react';
import {Modal} from 'react-bootstrap';
import {FormattedMessage} from 'react-intl';

import type {UserProfile} from '@mattermost/types/users';

import {adminAddToWhitelist, adminDeleteFromWhitelist} from 'actions/admin_actions';

interface Props {
    user?: UserProfile;
    whitelist: string[];
    onModalDismissed: () => void;
    getWhitelist: (userId: string) => void;
}

const WhitelistModal: React.FC<Props> = ({
    user,
    whitelist,
    onModalDismissed,
    getWhitelist,
}) => {
    const [error, setError] = useState<string | null>(null);
    const newIpRef = useRef<HTMLInputElement>(null);

    const doAdd = (e: React.FormEvent) => {
        e.preventDefault();
        if (!newIpRef.current || !user) {
            return;
        }
        const ip = newIpRef.current.value.trim();
        setError(null);
        newIpRef.current.value = '';

        adminAddToWhitelist(
            {
                user_id: user.id,
                ip,
            },
            () => {
                getWhitelist(user.id);
            },
            (err: any) => {
                setError(err);
            },
        );
    };

    const doDelete = (ip: string) => {
        if (!user) {
            return;
        }
        setError(null);
        adminDeleteFromWhitelist(
            {
                user_id: user.id,
                ip,
            },
            () => {
                getWhitelist(user.id);
            },
            (err: any) => {
                setError(err);
            },
        );
    };

    const doClose = () => {
        setError(null);
        onModalDismissed();
    };

    let urlClass = 'input-group input-group--limit';
    let errorMsg = null;
    if (error) {
        urlClass += ' has-error';
        errorMsg = <div className='has-error'><p className='input__help error'>{error}</p></div>;
    }

    const title = (
        <FormattedMessage
            id='admin.whitelist.title'
            defaultMessage='IP白名單'
        />
    );

    return (
        <Modal
            dialogClassName='a11y__modal'
            show={true}
            onHide={doClose}
            role='dialog'
            aria-labelledby='whitelistModalLabel'
            data-testid='whitelistModal'
        >
            <Modal.Header closeButton={true}>
                <Modal.Title
                    componentClass='h1'
                    id='whitelistModalLabel'
                >
                    {title}
                </Modal.Title>
            </Modal.Header>
            <form
                role='form'
                className='form-horizontal'
            >
                <Modal.Body>
                    <div className='form-group'>
                        <div className='col-sm-10'>
                            <div
                                className={urlClass}
                                data-testid='whitelistForm'
                            >
                                <span
                                    data-toggle='tooltip'
                                    title='New IP'
                                    className='input-group-addon email__group-addon'
                                >
                                    <FormattedMessage
                                        id='admin.whitelist.newIP'
                                        defaultMessage='New IP'
                                    />
                                </span>
                                <div className="flex">
                                    <input
                                        type='text'
                                        ref={newIpRef}
                                        className='form-control'
                                        maxLength={128}
                                        autoFocus={true}
                                    />
                                    <button
                                        onClick={doAdd}
                                        type='submit'
                                        className='btn btn-primary'
                                        data-testid='addWhitelistButton'
                                    >
                                        <FormattedMessage
                                            id='admin.whitelist.add'
                                            defaultMessage='Add'
                                        />
                                    </button>
                                </div>
                            </div>
                            {errorMsg}
                        </div>
                    </div>
                    <div className="whitelist-wrapper">
                        {whitelist.map((ip) => (
                            <div
                                key={ip}
                                className="whitelist-item"
                            >
                                <span>{ip}</span>
                                <span
                                    onClick={() => doDelete(ip)}
                                    className="whitelist-del"
                                >
                                    X
                                </span>
                            </div>
                        ))}
                    </div>
                </Modal.Body>
                <Modal.Footer>
                    <button
                        onClick={doClose}
                        type='button'
                        className='btn btn-primary'
                        data-testid='closeWhitelistButton'
                    >
                        <FormattedMessage
                            id='admin.whitelist.close'
                            defaultMessage='Close'
                        />
                    </button>
                </Modal.Footer>
            </form>
        </Modal>
    );
};

export default WhitelistModal; 