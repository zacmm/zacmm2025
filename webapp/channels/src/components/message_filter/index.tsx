// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

import React, {useState, useCallback} from 'react';
import {FormattedMessage} from 'react-intl';

import SearchIcon from 'components/widgets/icons/search_icon';

import './message_filter.scss';

type Props = {
    onFilterChange: (filter: string) => void;
    placeholder?: string;
};

const MessageFilter: React.FC<Props> = ({
    onFilterChange,
    placeholder,
}) => {
    const [filterText, setFilterText] = useState('');

    const handleFilterChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
        const value = e.target.value;
        setFilterText(value);
        onFilterChange(value);
    }, [onFilterChange]);

    const handleKeyDown = useCallback((e: React.KeyboardEvent<HTMLInputElement>) => {
        // Prevent Enter key and other keys from triggering global search
        e.stopPropagation();
        if (e.key === 'Enter') {
            e.preventDefault();
        }
    }, []);

    const handleFocus = useCallback((e: React.FocusEvent<HTMLInputElement>) => {
        e.stopPropagation();
    }, []);

    const handleBlur = useCallback((e: React.FocusEvent<HTMLInputElement>) => {
        e.stopPropagation();
    }, []);

    const handleClear = useCallback(() => {
        setFilterText('');
        onFilterChange('');
    }, [onFilterChange]);

    const handleContainerClick = useCallback((e: React.MouseEvent) => {
        e.stopPropagation();
    }, []);

    return (
        <div className='message-filter' onClick={handleContainerClick}>
            <div className='message-filter__container'>
                <div className='message-filter__input-wrapper'>
                    <SearchIcon className='message-filter__icon'/>
                    <input
                        type='text'
                        className='message-filter__input'
                        placeholder={placeholder || 'Filter messages...'}
                        value={filterText}
                        onChange={handleFilterChange}
                        onKeyDown={handleKeyDown}
                        onFocus={handleFocus}
                        onBlur={handleBlur}
                        autoComplete='off'
                        data-testid='message-filter-input'
                    />
                    {filterText && (
                        <button
                            className='message-filter__clear'
                            onClick={handleClear}
                            aria-label='Clear filter'
                        >
                            ×
                        </button>
                    )}
                </div>
            </div>
        </div>
    );
};

export default MessageFilter; 