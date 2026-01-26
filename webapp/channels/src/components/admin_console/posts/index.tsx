// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

import React, {useEffect, useState} from 'react';
import {FormattedMessage} from 'react-intl';
import {Permissions} from 'mattermost-redux/constants';
import {FileTypes, UserTypes, ChannelTypes, TeamTypes} from 'mattermost-redux/action_types';
import {useDispatch} from 'react-redux';

import {adminGetAllPosts} from 'actions/admin_actions';
import {Client4} from 'mattermost-redux/client';

import AdminHeader from 'components/widgets/admin_console/admin_header';
import SystemPermissionGate from 'components/permissions_gates/system_permission_gate';
import Post from 'components/post';

import './posts.scss';

type PostInfo = {
    channel_name: string;
    team_name: string;
    members: string;
};

type AllPostsResponse = {
    List: {
        order: string[];
        posts: {[key: string]: any};
    };
    TotalPages: number;
    PostInfoMap: {[key: string]: PostInfo};
};

type User = {
    id: string;
    username: string;
    is_bot: boolean;
};

export default function Posts() {
    const dispatch = useDispatch();
    const [posts, setPosts] = useState<any[]>([]);
    const [postInfoMap, setPostInfoMap] = useState<{[key: string]: PostInfo} | null>(null);
    const [user, setUser] = useState<User | null>(null);
    const [page, setPage] = useState(0);
    const [totalPages, setTotalPages] = useState(0);
    const [keyword, setKeyword] = useState('');
    const [startDate, setStartDate] = useState(() => {
        const threeMonthsAgo = new Date();
        threeMonthsAgo.setMonth(threeMonthsAgo.getMonth() - 3);
        return threeMonthsAgo.toLocaleDateString('en-CA');
    });
    const [endDate, setEndDate] = useState(new Date().toLocaleDateString('en-CA'));
    const [users, setUsers] = useState<User[]>([]);
    const [showUserDropdown, setShowUserDropdown] = useState(false);
    const [userSearchQuery, setUserSearchQuery] = useState('');
    const [userPage, setUserPage] = useState(0);
    const [usersPerPage] = useState(50); // Increased from 10 to 50 users per page

    useEffect(() => {
        getUsers();
        getPosts();
    }, []);

    const getUsers = async () => {
        const options = {};
        // Fetch all users with a high limit to ensure we get everyone
        const profiles = await Client4.getProfiles(0, 100000, options);
        const filteredUsers = profiles.filter((user: User) => !user.is_bot);
        // Sort users alphabetically by username
        filteredUsers.sort((a, b) => a.username.localeCompare(b.username));
        setUsers(filteredUsers);
        dispatch({
            type: UserTypes.RECEIVED_PROFILES_LIST,
            data: profiles,
        });
    };

    const getPosts = (overrideUserId?: string) => {
        const userId = overrideUserId !== undefined ? overrideUserId : (user ? user.id : '');
        const parsedStartDate = Date.parse(startDate);
        const parsedEndDate = Date.parse(endDate);
        
        // Ensure valid timestamps, fallback to default values if invalid
        const startTimestamp = isNaN(parsedStartDate) ? 0 : parsedStartDate;
        const endTimestamp = isNaN(parsedEndDate) ? Date.now() : parsedEndDate + 86400000;
        
        adminGetAllPosts({
            page,
            userId,
            keyword,
            startDate: startTimestamp,
            endDate: endTimestamp,
        }, (response: AllPostsResponse) => {
            const {List, TotalPages, PostInfoMap} = response;
            const {order} = List;
            const postMap = List.posts;
            const postsList = order.map((postId: string) => postMap[postId]);
            
            // Create channel and team objects from PostInfoMap and dispatch to Redux store
            const channels: {[key: string]: any} = {};
            const teams: {[key: string]: any} = {};
            
            postsList.forEach((post: any) => {
                const postInfo = PostInfoMap[post.id];
                if (postInfo && !channels[post.channel_id]) {
                    // Create a mock channel object with the information we have
                    channels[post.channel_id] = {
                        id: post.channel_id,
                        display_name: postInfo.channel_name,
                        name: postInfo.channel_name.toLowerCase().replace(/\s+/g, '-'),
                        type: postInfo.members ? 'D' : 'O', // Direct message if has members, otherwise open channel
                        team_id: `team_${post.channel_id}`, // Create a mock team_id
                        delete_at: 0,
                        create_at: 0,
                        update_at: 0,
                    };
                    
                    // Create a mock team object
                    const teamId = `team_${post.channel_id}`;
                    if (!teams[teamId]) {
                        teams[teamId] = {
                            id: teamId,
                            display_name: postInfo.team_name,
                            name: postInfo.team_name.toLowerCase().replace(/\s+/g, '-'),
                            type: 'O',
                            delete_at: 0,
                            create_at: 0,
                            update_at: 0,
                        };
                    }
                }
            });
            
            // Dispatch channels and teams to Redux store
            if (Object.keys(channels).length > 0) {
                dispatch({
                    type: ChannelTypes.RECEIVED_CHANNELS,
                    data: Object.values(channels),
                });
            }
            
            if (Object.keys(teams).length > 0) {
                dispatch({
                    type: TeamTypes.RECEIVED_TEAMS,
                    data: Object.values(teams),
                });
            }
            
            postsList.forEach(async (post: any) => {
                if (post.file_ids && post.file_ids.length) {
                    const fileInfos = await Client4.getFileInfosForPost(post.id);
                    dispatch({
                        type: FileTypes.RECEIVED_FILES_FOR_POST,
                        data: fileInfos,
                        postId: post.id,
                    });
                }
            });
            
            setPosts(postsList);
            setTotalPages(TotalPages);
            setPostInfoMap(PostInfoMap);
        });
    };

    const doSearch = () => {
        setPage(0);
        setTimeout(() => getPosts(), 0);
    };

    const keywordKeyup = (e: React.KeyboardEvent<HTMLInputElement>) => {
        setKeyword(e.currentTarget.value);
        if (e.keyCode === 13) {
            doSearch();
        }
    };

    const changeUser = (selectedUser: User | null) => {
        setUser(selectedUser);
        setShowUserDropdown(false);
        setTimeout(() => getPosts(selectedUser ? selectedUser.id : ''), 0);
    };

    const setPreviousPage = () => {
        if (page > 0) {
            setPage(page - 1);
            setTimeout(() => getPosts(), 0);
        }
    };

    const setNextPage = () => {
        if (page < totalPages - 1) {
            setPage(page + 1);
            setTimeout(() => getPosts(), 0);
        }
    };

    const setStartDateHandler = (e: React.ChangeEvent<HTMLInputElement>) => {
        const newStartDate = e.target.value;
        if (newStartDate <= endDate) {
            setStartDate(newStartDate);
            setTimeout(() => getPosts(), 0);
        }
    };

    const setEndDateHandler = (e: React.ChangeEvent<HTMLInputElement>) => {
        const newEndDate = e.target.value;
        if (newEndDate >= startDate) {
            setEndDate(newEndDate);
            setTimeout(() => getPosts(), 0);
        }
    };

    const getFilteredUsers = () => {
        if (!userSearchQuery) {
            return users;
        }
        return users.filter(user => 
            user.username.toLowerCase().includes(userSearchQuery.toLowerCase())
        );
    };

    const getPaginatedUsers = () => {
        const filteredUsers = getFilteredUsers();
        const startIndex = userPage * usersPerPage;
        const endIndex = startIndex + usersPerPage;
        return filteredUsers.slice(startIndex, endIndex);
    };

    const getUserTotalPages = () => {
        const filteredUsers = getFilteredUsers();
        return Math.ceil(filteredUsers.length / usersPerPage);
    };

    const handleUserSearchChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        setUserSearchQuery(e.target.value);
        setUserPage(0); // Reset to first page when searching
    };

    const handleUserPagePrevious = () => {
        if (userPage > 0) {
            setUserPage(userPage - 1);
        }
    };

    const handleUserPageNext = () => {
        if (userPage < getUserTotalPages() - 1) {
            setUserPage(userPage + 1);
        }
    };

    const isFirstPage = page === 0;
    const isLastPage = page === totalPages - 1;

    const paginator = totalPages > 1 ? (
        <div className="paginator">
            <span className={isFirstPage ? 'inactive' : 'active'} onClick={isFirstPage ? undefined : setPreviousPage}>{'<'}</span>
            <span>{page + 1}</span>
            <span>{'/'}</span>
            <span>{totalPages}</span>
            <span className={isLastPage ? 'inactive' : 'active'} onClick={isLastPage ? undefined : setNextPage}>{'>'}</span>
        </div>
    ) : null;

    const userText = user ? `${user.username}` : '所有使用者';
    const paginatedUsers = getPaginatedUsers();
    const userTotalPages = getUserTotalPages();
    const isUserFirstPage = userPage === 0;
    const isUserLastPage = userPage === userTotalPages - 1;
    
    const usersList = paginatedUsers.map((userItem) => (
        <div key={userItem.id} className="user-in-dropdown" onClick={() => changeUser(userItem)}>
            {userItem.username}
        </div>
    ));
    
    // Only show "all users" option on first page when no search query
    if (isUserFirstPage && !userSearchQuery) {
        usersList.splice(0, 0, <div key="all" className="user-in-dropdown" onClick={() => changeUser(null)}>{'所有使用者'}</div>);
    }

    const userSelect = (
        <div>
            <p className="user-name" onClick={() => setShowUserDropdown(!showUserDropdown)}>{userText}</p>
            {showUserDropdown ? (
                <div>
                    <div className="shade" onClick={() => setShowUserDropdown(false)} />
                    <div className="users-dropdown-wrapper">
                        <div className="users-dropdown">
                            <div className="user-search-container">
                                <input
                                    type="text"
                                    className="user-search-input"
                                    placeholder="搜尋使用者..."
                                    value={userSearchQuery}
                                    onChange={handleUserSearchChange}
                                    onClick={(e) => e.stopPropagation()}
                                />
                            </div>
                            <div className="users-list-container">
                                {usersList}
                            </div>
                            {userTotalPages > 1 && (
                                <div className="user-pagination">
                                    <span 
                                        className={isUserFirstPage ? 'inactive' : 'active'} 
                                        onClick={isUserFirstPage ? undefined : handleUserPagePrevious}
                                    >
                                        {'<'}
                                    </span>
                                    <span>{userPage + 1} / {userTotalPages}</span>
                                    <span 
                                        className={isUserLastPage ? 'inactive' : 'active'} 
                                        onClick={isUserLastPage ? undefined : handleUserPageNext}
                                    >
                                        {'>'}
                                    </span>
                                </div>
                            )}
                        </div>
                    </div>
                </div>
            ) : null}
        </div>
    );

    return (
        <div className='wrapper--fixed'>
            <AdminHeader>
                <FormattedMessage
                    id='admin.posts.title'
                    defaultMessage='訊息篩選'
                />
            </AdminHeader>

            <div className='admin-console__wrapper'>
                <div className='admin-console__content'>
                    <SystemPermissionGate permissions={[Permissions.REVOKE_USER_ACCESS_TOKEN]}>
                        <div className='form-horizontal'>
                            <div className='form-group'>
                                <div className='col-sm-10'>
                                    <div className='input-group input-group--limit' data-testid='keywordForm'>
                                        <span
                                            data-toggle='tooltip'
                                            title='Search by keyword'
                                            className='input-group-addon email__group-addon'
                                        >
                                            <FormattedMessage
                                                id='admin.posts.keyword'
                                                defaultMessage='Keyword'
                                            />
                                        </span>
                                        <div className="flex">
                                            <input
                                                className='form-control'
                                                maxLength={128}
                                                autoFocus={true}
                                                onKeyUp={keywordKeyup}
                                            />
                                            <button
                                                onClick={doSearch}
                                                type='button'
                                                className='btn btn-primary'
                                                data-testid='resetEmailButton'
                                            >
                                                <FormattedMessage
                                                    id='admin.posts.save'
                                                    defaultMessage='Search'
                                                />
                                            </button>
                                            {userSelect}
                                        </div>
                                    </div>
                                </div>
                            </div>
                            <div className="date-selector">
                                <label htmlFor="startDate">開始日期:</label>
                                <input name="startDate" type="date" value={startDate} onChange={setStartDateHandler} />
                                <label htmlFor="endDate">結束日期:</label>
                                <input name="endDate" type="date" value={endDate} onChange={setEndDateHandler} />
                            </div>
                            {paginator}
                            <div>
                                {posts.map(post => (
                                    <Post 
                                        key={post.id} 
                                        post={post} 
                                        location="center"
                                    />
                                ))}
                            </div>
                        </div>
                    </SystemPermissionGate>
                </div>
            </div>
        </div>
    );
} 