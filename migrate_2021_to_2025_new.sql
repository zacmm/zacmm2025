-- Mattermost Database Migration Script: 2021 to 2025
-- This script upgrades a Mattermost 2021 database to 2025 schema
-- Run this script on your 2021 database to migrate to 2025

-- Start transaction for safety
START TRANSACTION;

-- ============================================================================
-- NEW TABLES (2025 additions)
-- ============================================================================

-- AccessControlPolicies table
CREATE TABLE IF NOT EXISTS AccessControlPolicies (
    ID varchar(26) NOT NULL PRIMARY KEY,
    Name varchar(128) NOT NULL,
    Type varchar(128) NOT NULL,
    Active tinyint(1) NOT NULL,
    CreateAt bigint NOT NULL,
    Revision int NOT NULL,
    Version varchar(8) NOT NULL,
    Data json,
    Props json
);

-- AccessControlPolicyHistory table
CREATE TABLE IF NOT EXISTS AccessControlPolicyHistory (
    ID varchar(26) NOT NULL,
    Name varchar(128) NOT NULL,
    Type varchar(128) NOT NULL,
    CreateAt bigint NOT NULL,
    Revision int NOT NULL,
    Version varchar(8) NOT NULL,
    Data json,
    Props json,
    PRIMARY KEY (ID, Revision)
);

-- AttributeView table
CREATE TABLE IF NOT EXISTS AttributeView (
    GroupID varchar(26) NOT NULL,
    TargetID varchar(255) NOT NULL,
    TargetType varchar(255) NOT NULL,
    Attributes json
);

-- ChannelBookmarks table
CREATE TABLE IF NOT EXISTS ChannelBookmarks (
    Id varchar(26) NOT NULL PRIMARY KEY,
    OwnerId varchar(26) NOT NULL,
    ChannelId varchar(26) NOT NULL,
    FileInfoId varchar(26),
    CreateAt bigint DEFAULT 0,
    UpdateAt bigint DEFAULT 0,
    DeleteAt bigint DEFAULT 0,
    DisplayName text,
    SortOrder bigint DEFAULT 0,
    LinkUrl text,
    ImageUrl text,
    Emoji varchar(64),
    Type enum('link','file'),
    OriginalId varchar(26),
    ParentId varchar(26),
    INDEX idx_channelbookmarks_channelid (ChannelId),
    INDEX idx_channelbookmarks_updateat (UpdateAt),
    INDEX idx_channelbookmarks_deleteat (DeleteAt)
);

-- DesktopTokens table
CREATE TABLE IF NOT EXISTS DesktopTokens (
    Token varchar(64) NOT NULL PRIMARY KEY,
    CreateAt bigint NOT NULL,
    UserId varchar(26) NOT NULL
);

-- Drafts table
CREATE TABLE IF NOT EXISTS Drafts (
    CreateAt bigint,
    UpdateAt bigint,
    DeleteAt bigint,
    UserId varchar(26) NOT NULL,
    ChannelId varchar(26) NOT NULL,
    RootId varchar(26) NOT NULL DEFAULT '',
    Message text,
    Props text,
    FileIds text,
    Priority text,
    PRIMARY KEY (UserId, ChannelId, RootId)
);

-- NotifyAdmin table
CREATE TABLE IF NOT EXISTS NotifyAdmin (
    UserId varchar(26) NOT NULL,
    CreateAt bigint,
    RequiredPlan varchar(100) NOT NULL,
    RequiredFeature varchar(255) NOT NULL,
    Trial tinyint(1) NOT NULL,
    SentAt bigint,
    PRIMARY KEY (UserId, RequiredPlan, RequiredFeature)
);

-- OutgoingOAuthConnections table
CREATE TABLE IF NOT EXISTS OutgoingOAuthConnections (
    Id varchar(26) NOT NULL PRIMARY KEY,
    Name varchar(64),
    CreatorId varchar(26),
    CreateAt bigint,
    UpdateAt bigint,
    ClientId varchar(255),
    ClientSecret varchar(255),
    CredentialsUsername varchar(255),
    CredentialsPassword varchar(255),
    OAuthTokenURL text,
    GrantType varchar(32) DEFAULT 'client_credentials',
    Audiences text,
    INDEX idx_outgoingoauthconnections_name (Name)
);

-- PersistentNotifications table
CREATE TABLE IF NOT EXISTS PersistentNotifications (
    PostId varchar(26) NOT NULL PRIMARY KEY,
    CreateAt bigint,
    LastSentAt bigint,
    DeleteAt bigint,
    SentCount smallint
);

-- PostAcknowledgements table
CREATE TABLE IF NOT EXISTS PostAcknowledgements (
    PostId varchar(26) NOT NULL,
    UserId varchar(26) NOT NULL,
    AcknowledgedAt bigint,
    RemoteId varchar(26) DEFAULT '',
    ChannelId varchar(26) DEFAULT '',
    PRIMARY KEY (PostId, UserId)
);

-- PostReminders table
CREATE TABLE IF NOT EXISTS PostReminders (
    PostId varchar(26) NOT NULL,
    UserId varchar(26) NOT NULL,
    TargetTime bigint,
    PRIMARY KEY (PostId, UserId),
    INDEX idx_postreminders_targettime (TargetTime)
);

-- PostsPriority table
CREATE TABLE IF NOT EXISTS PostsPriority (
    PostId varchar(26) NOT NULL PRIMARY KEY,
    ChannelId varchar(26) NOT NULL,
    Priority varchar(32) NOT NULL,
    RequestedAck tinyint(1),
    PersistentNotifications tinyint(1)
);

-- PropertyFields table
CREATE TABLE IF NOT EXISTS PropertyFields (
    ID varchar(26) NOT NULL PRIMARY KEY,
    GroupID varchar(26) NOT NULL,
    Name varchar(255) NOT NULL,
    Type enum('text','select','multiselect','date','user','multiuser'),
    Attrs json,
    TargetID varchar(255),
    TargetType varchar(255),
    CreateAt bigint,
    UpdateAt bigint,
    DeleteAt bigint,
    INDEX idx_propertyfields_groupid (GroupID),
    INDEX idx_propertyfields_createat (CreateAt)
);

-- PropertyGroups table
CREATE TABLE IF NOT EXISTS PropertyGroups (
    ID varchar(26) NOT NULL PRIMARY KEY,
    Name varchar(64) NOT NULL UNIQUE
);

-- PropertyValues table
CREATE TABLE IF NOT EXISTS PropertyValues (
    ID varchar(26) NOT NULL PRIMARY KEY,
    TargetID varchar(255) NOT NULL,
    TargetType varchar(255) NOT NULL,
    GroupID varchar(26) NOT NULL,
    FieldID varchar(26) NOT NULL,
    Value json,
    CreateAt bigint,
    UpdateAt bigint,
    DeleteAt bigint,
    INDEX idx_propertyvalues_targetid (TargetID),
    INDEX idx_propertyvalues_groupid (GroupID),
    INDEX idx_propertyvalues_createat (CreateAt)
);

-- RecentSearches table
CREATE TABLE IF NOT EXISTS RecentSearches (
    UserId char(26) NOT NULL,
    SearchPointer int NOT NULL,
    Query json,
    CreateAt bigint NOT NULL,
    PRIMARY KEY (UserId, SearchPointer)
);

-- RemoteClusters table
CREATE TABLE IF NOT EXISTS RemoteClusters (
    RemoteId varchar(26) NOT NULL PRIMARY KEY,
    RemoteTeamId varchar(26),
    Name varchar(64) NOT NULL,
    DisplayName varchar(64),
    SiteURL text,
    CreateAt bigint,
    LastPingAt bigint,
    Token varchar(26),
    RemoteToken varchar(26),
    Topics text,
    CreatorId varchar(26),
    PluginID varchar(190) NOT NULL DEFAULT '',
    Options smallint NOT NULL DEFAULT 0,
    DefaultTeamId varchar(26) DEFAULT '',
    DeleteAt bigint DEFAULT 0,
    LastGlobalUserSyncAt bigint DEFAULT 0,
    UNIQUE KEY unique_remote_cluster_name (Name)
);

-- RetentionIdsForDeletion table
CREATE TABLE IF NOT EXISTS RetentionIdsForDeletion (
    Id varchar(26) NOT NULL PRIMARY KEY,
    TableName varchar(64),
    Ids json,
    INDEX idx_retentionidsfordeletion_tablename (TableName)
);

-- RetentionPolicies table
CREATE TABLE IF NOT EXISTS RetentionPolicies (
    Id varchar(26) NOT NULL PRIMARY KEY,
    DisplayName varchar(64),
    PostDuration bigint,
    INDEX idx_retentionpolicies_displayname (DisplayName)
);

-- RetentionPoliciesChannels table
CREATE TABLE IF NOT EXISTS RetentionPoliciesChannels (
    PolicyId varchar(26),
    ChannelId varchar(26) NOT NULL PRIMARY KEY,
    INDEX idx_retentionpoliceschannels_policyid (PolicyId)
);

-- RetentionPoliciesTeams table
CREATE TABLE IF NOT EXISTS RetentionPoliciesTeams (
    PolicyId varchar(26),
    TeamId varchar(26) NOT NULL PRIMARY KEY,
    INDEX idx_retentionpolicesteams_policyid (PolicyId)
);

-- ScheduledPosts table
CREATE TABLE IF NOT EXISTS ScheduledPosts (
    id varchar(26) NOT NULL PRIMARY KEY,
    createat bigint,
    updateat bigint,
    userid varchar(26) NOT NULL,
    channelid varchar(26) NOT NULL,
    rootid varchar(26),
    message text,
    props text,
    fileids text,
    priority text,
    scheduledat bigint NOT NULL,
    processedat bigint,
    errorcode varchar(200),
    INDEX idx_scheduledposts_userid (userid)
);

-- SharedChannelAttachments table
CREATE TABLE IF NOT EXISTS SharedChannelAttachments (
    Id varchar(26) NOT NULL PRIMARY KEY,
    FileId varchar(26),
    RemoteId varchar(26),
    CreateAt bigint,
    LastSyncAt bigint,
    INDEX idx_sharedchannelattachments_fileid (FileId)
);

-- SharedChannelRemotes table
CREATE TABLE IF NOT EXISTS SharedChannelRemotes (
    Id varchar(26) NOT NULL,
    ChannelId varchar(26) NOT NULL,
    CreatorId varchar(26),
    CreateAt bigint,
    UpdateAt bigint,
    IsInviteAccepted tinyint(1),
    IsInviteConfirmed tinyint(1),
    RemoteId varchar(26),
    LastPostUpdateAt bigint,
    LastPostId varchar(26),
    LastPostCreateAt bigint NOT NULL DEFAULT 0,
    LastPostCreateID varchar(26),
    DeleteAt bigint DEFAULT 0,
    LastMembersSyncAt bigint DEFAULT 0,
    PRIMARY KEY (Id, ChannelId)
);

-- SharedChannelUsers table
CREATE TABLE IF NOT EXISTS SharedChannelUsers (
    Id varchar(26) NOT NULL PRIMARY KEY,
    UserId varchar(26),
    RemoteId varchar(26),
    CreateAt bigint,
    LastSyncAt bigint,
    ChannelId varchar(26),
    LastMembershipSyncAt bigint DEFAULT 0,
    INDEX idx_sharedchannelusers_userid (UserId),
    INDEX idx_sharedchannelusers_remoteid (RemoteId)
);

-- SharedChannels table
CREATE TABLE IF NOT EXISTS SharedChannels (
    ChannelId varchar(26) NOT NULL PRIMARY KEY,
    TeamId varchar(26),
    Home tinyint(1),
    ReadOnly tinyint(1),
    ShareName varchar(64),
    ShareDisplayName varchar(64),
    SharePurpose varchar(250),
    ShareHeader text,
    CreatorId varchar(26),
    CreateAt bigint,
    UpdateAt bigint,
    RemoteId varchar(26),
    INDEX idx_sharedchannels_sharename (ShareName)
);

-- db_lock table
CREATE TABLE IF NOT EXISTS db_lock (
    Id varchar(64) NOT NULL PRIMARY KEY,
    ExpireAt bigint NOT NULL
);

-- db_migrations table
CREATE TABLE IF NOT EXISTS db_migrations (
    Version bigint NOT NULL PRIMARY KEY,
    Name varchar(64) NOT NULL
);

-- ============================================================================
-- MODIFY EXISTING TABLES (2025 changes) - CORRECTED SYNTAX
-- ============================================================================

-- Modify ChannelMembers table - CORRECTED
-- Check if NotifyProps column already exists as text/varchar, if so, modify it to json
SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'ChannelMembers' AND COLUMN_NAME = 'NotifyProps' AND TABLE_SCHEMA = DATABASE()) > 0,
    'ALTER TABLE ChannelMembers MODIFY COLUMN NotifyProps json',
    'ALTER TABLE ChannelMembers ADD COLUMN NotifyProps json'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Add other columns to ChannelMembers
SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'ChannelMembers' AND COLUMN_NAME = 'MentionCountRoot' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE ChannelMembers ADD COLUMN MentionCountRoot bigint',
    'SELECT "MentionCountRoot already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'ChannelMembers' AND COLUMN_NAME = 'MsgCountRoot' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE ChannelMembers ADD COLUMN MsgCountRoot bigint',
    'SELECT "MsgCountRoot already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'ChannelMembers' AND COLUMN_NAME = 'UrgentMentionCount' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE ChannelMembers ADD COLUMN UrgentMentionCount bigint',
    'SELECT "UrgentMentionCount already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Modify Channels table - CORRECTED
ALTER TABLE Channels MODIFY COLUMN Type enum('D','O','G','P');

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'Channels' AND COLUMN_NAME = 'Shared' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE Channels ADD COLUMN Shared tinyint(1)',
    'SELECT "Shared already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'Channels' AND COLUMN_NAME = 'TotalMsgCountRoot' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE Channels ADD COLUMN TotalMsgCountRoot bigint',
    'SELECT "TotalMsgCountRoot already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'Channels' AND COLUMN_NAME = 'LastRootPostAt' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE Channels ADD COLUMN LastRootPostAt bigint DEFAULT 0',
    'SELECT "LastRootPostAt already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'Channels' AND COLUMN_NAME = 'BannerInfo' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE Channels ADD COLUMN BannerInfo json',
    'SELECT "BannerInfo already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'Channels' AND COLUMN_NAME = 'DefaultCategoryName' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE Channels ADD COLUMN DefaultCategoryName varchar(64) NOT NULL DEFAULT \'\'',
    'SELECT "DefaultCategoryName already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Modify CommandWebhooks table - CORRECTED
SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'CommandWebhooks' AND COLUMN_NAME = 'ParentId' AND TABLE_SCHEMA = DATABASE()) > 0,
    'ALTER TABLE CommandWebhooks DROP COLUMN ParentId',
    'SELECT "ParentId column does not exist" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Modify FileInfo table - CORRECTED
SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'FileInfo' AND COLUMN_NAME = 'RemoteId' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE FileInfo ADD COLUMN RemoteId varchar(26)',
    'SELECT "RemoteId already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'FileInfo' AND COLUMN_NAME = 'Archived' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE FileInfo ADD COLUMN Archived tinyint(1) NOT NULL DEFAULT 0',
    'SELECT "Archived already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'FileInfo' AND COLUMN_NAME = 'ChannelId' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE FileInfo ADD COLUMN ChannelId varchar(26)',
    'SELECT "ChannelId already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Add index for FileInfo.ChannelId
SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS 
     WHERE TABLE_NAME = 'FileInfo' AND INDEX_NAME = 'idx_fileinfo_channelid' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE FileInfo ADD INDEX idx_fileinfo_channelid (ChannelId)',
    'SELECT "Index idx_fileinfo_channelid already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Modify Jobs table - CORRECTED
ALTER TABLE Jobs MODIFY COLUMN Data json;

-- Modify LinkMetadata table - CORRECTED
ALTER TABLE LinkMetadata MODIFY COLUMN Data json;

-- Modify OAuthApps table - CORRECTED
SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'OAuthApps' AND COLUMN_NAME = 'MattermostAppID' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE OAuthApps ADD COLUMN MattermostAppID varchar(32) NOT NULL DEFAULT \'\'',
    'SELECT "MattermostAppID already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Modify OAuthAccessData table - CORRECTED
ALTER TABLE OAuthAccessData 
MODIFY COLUMN Token varchar(26) NOT NULL,
MODIFY COLUMN RefreshToken varchar(26),
MODIFY COLUMN RedirectUri text,
MODIFY COLUMN ClientId varchar(26),
MODIFY COLUMN UserId varchar(26),
MODIFY COLUMN ExpiresAt bigint,
MODIFY COLUMN Scope varchar(128);

-- Modify Posts table - CORRECTED
ALTER TABLE Posts MODIFY COLUMN Props json;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'Posts' AND COLUMN_NAME = 'RemoteId' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE Posts ADD COLUMN RemoteId varchar(26)',
    'SELECT "RemoteId already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Modify Reactions table - CORRECTED
SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'Reactions' AND COLUMN_NAME = 'UpdateAt' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE Reactions ADD COLUMN UpdateAt bigint',
    'SELECT "UpdateAt already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'Reactions' AND COLUMN_NAME = 'DeleteAt' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE Reactions ADD COLUMN DeleteAt bigint',
    'SELECT "DeleteAt already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'Reactions' AND COLUMN_NAME = 'RemoteId' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE Reactions ADD COLUMN RemoteId varchar(26)',
    'SELECT "RemoteId already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'Reactions' AND COLUMN_NAME = 'ChannelId' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE Reactions ADD COLUMN ChannelId varchar(26) NOT NULL DEFAULT \'\'',
    'SELECT "ChannelId already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Add index for Reactions.ChannelId
SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS 
     WHERE TABLE_NAME = 'Reactions' AND INDEX_NAME = 'idx_reactions_channelid' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE Reactions ADD INDEX idx_reactions_channelid (ChannelId)',
    'SELECT "Index idx_reactions_channelid already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Modify RemoteClusters table (if it exists from previous versions) - CORRECTED
SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'RemoteClusters' AND COLUMN_NAME = 'PluginID' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE RemoteClusters ADD COLUMN PluginID varchar(190) NOT NULL DEFAULT \'\'',
    'SELECT "PluginID already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'RemoteClusters' AND COLUMN_NAME = 'Options' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE RemoteClusters ADD COLUMN Options smallint NOT NULL DEFAULT 0',
    'SELECT "Options already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'RemoteClusters' AND COLUMN_NAME = 'DefaultTeamId' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE RemoteClusters ADD COLUMN DefaultTeamId varchar(26) DEFAULT \'\'',
    'SELECT "DefaultTeamId already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'RemoteClusters' AND COLUMN_NAME = 'DeleteAt' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE RemoteClusters ADD COLUMN DeleteAt bigint DEFAULT 0',
    'SELECT "DeleteAt already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'RemoteClusters' AND COLUMN_NAME = 'LastGlobalUserSyncAt' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE RemoteClusters ADD COLUMN LastGlobalUserSyncAt bigint DEFAULT 0',
    'SELECT "LastGlobalUserSyncAt already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Modify Roles table - CORRECTED
ALTER TABLE Roles MODIFY COLUMN Permissions longtext;

-- Modify Schemes table - CORRECTED
SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'Schemes' AND COLUMN_NAME = 'DefaultPlaybookAdminRole' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE Schemes ADD COLUMN DefaultPlaybookAdminRole varchar(64) DEFAULT \'\'',
    'SELECT "DefaultPlaybookAdminRole already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'Schemes' AND COLUMN_NAME = 'DefaultPlaybookMemberRole' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE Schemes ADD COLUMN DefaultPlaybookMemberRole varchar(64) DEFAULT \'\'',
    'SELECT "DefaultPlaybookMemberRole already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'Schemes' AND COLUMN_NAME = 'DefaultRunAdminRole' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE Schemes ADD COLUMN DefaultRunAdminRole varchar(64) DEFAULT \'\'',
    'SELECT "DefaultRunAdminRole already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'Schemes' AND COLUMN_NAME = 'DefaultRunMemberRole' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE Schemes ADD COLUMN DefaultRunMemberRole varchar(64) DEFAULT \'\'',
    'SELECT "DefaultRunMemberRole already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Modify Sessions table - CORRECTED
ALTER TABLE Sessions MODIFY COLUMN Props json;

-- Modify SharedChannelRemotes table - CORRECTED
SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'SharedChannelRemotes' AND COLUMN_NAME = 'LastPostCreateAt' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE SharedChannelRemotes ADD COLUMN LastPostCreateAt bigint NOT NULL DEFAULT 0',
    'SELECT "LastPostCreateAt already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'SharedChannelRemotes' AND COLUMN_NAME = 'LastPostCreateID' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE SharedChannelRemotes ADD COLUMN LastPostCreateID varchar(26)',
    'SELECT "LastPostCreateID already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'SharedChannelRemotes' AND COLUMN_NAME = 'DeleteAt' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE SharedChannelRemotes ADD COLUMN DeleteAt bigint DEFAULT 0',
    'SELECT "DeleteAt already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'SharedChannelRemotes' AND COLUMN_NAME = 'LastMembersSyncAt' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE SharedChannelRemotes ADD COLUMN LastMembersSyncAt bigint DEFAULT 0',
    'SELECT "LastMembersSyncAt already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Modify SharedChannelUsers table - CORRECTED
SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'SharedChannelUsers' AND COLUMN_NAME = 'ChannelId' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE SharedChannelUsers ADD COLUMN ChannelId varchar(26)',
    'SELECT "ChannelId already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'SharedChannelUsers' AND COLUMN_NAME = 'LastMembershipSyncAt' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE SharedChannelUsers ADD COLUMN LastMembershipSyncAt bigint DEFAULT 0',
    'SELECT "LastMembershipSyncAt already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Modify SidebarCategories table - CORRECTED
SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'SidebarCategories' AND COLUMN_NAME = 'Collapsed' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE SidebarCategories ADD COLUMN Collapsed tinyint(1)',
    'SELECT "Collapsed already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Modify Status table - CORRECTED
SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'Status' AND COLUMN_NAME = 'DNDEndTime' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE Status ADD COLUMN DNDEndTime bigint',
    'SELECT "DNDEndTime already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'Status' AND COLUMN_NAME = 'PrevStatus' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE Status ADD COLUMN PrevStatus varchar(32)',
    'SELECT "PrevStatus already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Modify TeamMembers table - CORRECTED
SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'TeamMembers' AND COLUMN_NAME = 'CreateAt' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE TeamMembers ADD COLUMN CreateAt bigint DEFAULT 0',
    'SELECT "CreateAt already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Add index for TeamMembers.CreateAt
SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS 
     WHERE TABLE_NAME = 'TeamMembers' AND INDEX_NAME = 'idx_teammembers_createat' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE TeamMembers ADD INDEX idx_teammembers_createat (CreateAt)',
    'SELECT "Index idx_teammembers_createat already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Modify Teams table - CORRECTED
ALTER TABLE Teams MODIFY COLUMN Type enum('I','O');

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'Teams' AND COLUMN_NAME = 'CloudLimitsArchived' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE Teams ADD COLUMN CloudLimitsArchived tinyint(1) NOT NULL DEFAULT 0',
    'SELECT "CloudLimitsArchived already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Modify ThreadMemberships table - CORRECTED
SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'ThreadMemberships' AND COLUMN_NAME = 'UnreadMentions' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE ThreadMemberships ADD COLUMN UnreadMentions bigint',
    'SELECT "UnreadMentions already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Modify Threads table - CORRECTED
ALTER TABLE Threads MODIFY COLUMN Participants json;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'Threads' AND COLUMN_NAME = 'ThreadDeleteAt' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE Threads ADD COLUMN ThreadDeleteAt bigint',
    'SELECT "ThreadDeleteAt already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'Threads' AND COLUMN_NAME = 'ThreadTeamId' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE Threads ADD COLUMN ThreadTeamId varchar(26)',
    'SELECT "ThreadTeamId already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Modify UploadSessions table - CORRECTED
ALTER TABLE UploadSessions MODIFY COLUMN Type enum('attachment','import');

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'UploadSessions' AND COLUMN_NAME = 'RemoteId' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE UploadSessions ADD COLUMN RemoteId varchar(26)',
    'SELECT "RemoteId already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'UploadSessions' AND COLUMN_NAME = 'ReqFileId' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE UploadSessions ADD COLUMN ReqFileId varchar(26)',
    'SELECT "ReqFileId already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Modify Users table - CORRECTED
ALTER TABLE Users 
MODIFY COLUMN Props json,
MODIFY COLUMN NotifyProps json;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'Users' AND COLUMN_NAME = 'Position' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE Users ADD COLUMN Position varchar(128)',
    'SELECT "Position already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'Users' AND COLUMN_NAME = 'Timezone' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE Users ADD COLUMN Timezone json',
    'SELECT "Timezone already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'Users' AND COLUMN_NAME = 'RemoteId' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE Users ADD COLUMN RemoteId varchar(26)',
    'SELECT "RemoteId already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'Users' AND COLUMN_NAME = 'LastLogin' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE Users ADD COLUMN LastLogin bigint NOT NULL DEFAULT 0',
    'SELECT "LastLogin already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_NAME = 'Users' AND COLUMN_NAME = 'MfaUsedTimestamps' AND TABLE_SCHEMA = DATABASE()) = 0,
    'ALTER TABLE Users ADD COLUMN MfaUsedTimestamps json',
    'SELECT "MfaUsedTimestamps already exists" AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ============================================================================
-- UPDATE SYSTEM VERSION
-- ============================================================================

-- Update the version in Systems table
INSERT INTO Systems (Name, Value) VALUES ('Version', '5.30.0') 
ON DUPLICATE KEY UPDATE Value = '5.30.0';

-- ============================================================================
-- COMMIT TRANSACTION
-- ============================================================================

COMMIT;

-- Display completion message
SELECT 'Migration completed successfully! Mattermost database upgraded from 2021 to 2025 schema.' AS Status;
