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
-- MODIFY EXISTING TABLES (2025 changes)
-- ============================================================================

-- Modify ChannelMembers table
ALTER TABLE ChannelMembers 
ADD COLUMN IF NOT EXISTS NotifyProps json AFTER NotifyProps,
ADD COLUMN IF NOT EXISTS MentionCountRoot bigint AFTER SchemeGuest,
ADD COLUMN IF NOT EXISTS MsgCountRoot bigint AFTER MentionCountRoot,
ADD COLUMN IF NOT EXISTS UrgentMentionCount bigint AFTER MsgCountRoot;

-- Modify Channels table
ALTER TABLE Channels 
MODIFY COLUMN Type enum('D','O','G','P') AFTER TeamId,
ADD COLUMN IF NOT EXISTS Shared tinyint(1) AFTER GroupConstrained,
ADD COLUMN IF NOT EXISTS TotalMsgCountRoot bigint AFTER TotalMsgCount,
ADD COLUMN IF NOT EXISTS LastRootPostAt bigint DEFAULT 0 AFTER LastPostAt,
ADD COLUMN IF NOT EXISTS BannerInfo json AFTER LastRootPostAt,
ADD COLUMN IF NOT EXISTS DefaultCategoryName varchar(64) NOT NULL DEFAULT '' AFTER BannerInfo;

-- Modify CommandWebhooks table
ALTER TABLE CommandWebhooks 
DROP COLUMN IF EXISTS ParentId;

-- Modify FileInfo table
ALTER TABLE FileInfo 
ADD COLUMN IF NOT EXISTS RemoteId varchar(26) AFTER Content,
ADD COLUMN IF NOT EXISTS Archived tinyint(1) NOT NULL DEFAULT 0 AFTER RemoteId,
ADD COLUMN IF NOT EXISTS ChannelId varchar(26) AFTER Archived,
ADD INDEX IF NOT EXISTS idx_fileinfo_channelid (ChannelId);

-- Modify Jobs table
ALTER TABLE Jobs 
MODIFY COLUMN Data json;

-- Modify LinkMetadata table
ALTER TABLE LinkMetadata 
MODIFY COLUMN Data json;

-- Modify OAuthApps table
ALTER TABLE OAuthApps 
ADD COLUMN IF NOT EXISTS MattermostAppID varchar(32) NOT NULL DEFAULT '' AFTER IsTrusted;

-- Modify OAuthAccessData table
ALTER TABLE OAuthAccessData 
MODIFY COLUMN Token varchar(26) NOT NULL PRIMARY KEY,
MODIFY COLUMN RefreshToken varchar(26),
MODIFY COLUMN RedirectUri text,
MODIFY COLUMN ClientId varchar(26),
MODIFY COLUMN UserId varchar(26),
MODIFY COLUMN ExpiresAt bigint,
MODIFY COLUMN Scope varchar(128);

-- Modify Posts table
ALTER TABLE Posts 
MODIFY COLUMN Props json,
ADD COLUMN IF NOT EXISTS RemoteId varchar(26) AFTER HasReactions;

-- Modify Reactions table
ALTER TABLE Reactions 
ADD COLUMN IF NOT EXISTS UpdateAt bigint AFTER CreateAt,
ADD COLUMN IF NOT EXISTS DeleteAt bigint AFTER UpdateAt,
ADD COLUMN IF NOT EXISTS RemoteId varchar(26) AFTER DeleteAt,
ADD COLUMN IF NOT EXISTS ChannelId varchar(26) NOT NULL DEFAULT '' AFTER RemoteId,
ADD INDEX IF NOT EXISTS idx_reactions_channelid (ChannelId);

-- Modify RemoteClusters table (if it exists from previous versions)
ALTER TABLE RemoteClusters 
ADD COLUMN IF NOT EXISTS PluginID varchar(190) NOT NULL DEFAULT '' AFTER CreatorId,
ADD COLUMN IF NOT EXISTS Options smallint NOT NULL DEFAULT 0 AFTER PluginID,
ADD COLUMN IF NOT EXISTS DefaultTeamId varchar(26) DEFAULT '' AFTER Options,
ADD COLUMN IF NOT EXISTS DeleteAt bigint DEFAULT 0 AFTER DefaultTeamId,
ADD COLUMN IF NOT EXISTS LastGlobalUserSyncAt bigint DEFAULT 0 AFTER DeleteAt;

-- Modify Roles table
ALTER TABLE Roles 
MODIFY COLUMN Permissions longtext;

-- Modify Schemes table
ALTER TABLE Schemes 
ADD COLUMN IF NOT EXISTS DefaultPlaybookAdminRole varchar(64) DEFAULT '' AFTER DefaultChannelGuestRole,
ADD COLUMN IF NOT EXISTS DefaultPlaybookMemberRole varchar(64) DEFAULT '' AFTER DefaultPlaybookAdminRole,
ADD COLUMN IF NOT EXISTS DefaultRunAdminRole varchar(64) DEFAULT '' AFTER DefaultPlaybookMemberRole,
ADD COLUMN IF NOT EXISTS DefaultRunMemberRole varchar(64) DEFAULT '' AFTER DefaultRunAdminRole;

-- Modify Sessions table
ALTER TABLE Sessions 
MODIFY COLUMN Props json;

-- Modify SharedChannelRemotes table
ALTER TABLE SharedChannelRemotes 
ADD COLUMN IF NOT EXISTS LastPostCreateAt bigint NOT NULL DEFAULT 0 AFTER LastPostId,
ADD COLUMN IF NOT EXISTS LastPostCreateID varchar(26) AFTER LastPostCreateAt,
ADD COLUMN IF NOT EXISTS DeleteAt bigint DEFAULT 0 AFTER LastPostCreateID,
ADD COLUMN IF NOT EXISTS LastMembersSyncAt bigint DEFAULT 0 AFTER DeleteAt;

-- Modify SharedChannelUsers table
ALTER TABLE SharedChannelUsers 
ADD COLUMN IF NOT EXISTS ChannelId varchar(26) AFTER LastSyncAt,
ADD COLUMN IF NOT EXISTS LastMembershipSyncAt bigint DEFAULT 0 AFTER ChannelId;

-- Modify SidebarCategories table
ALTER TABLE SidebarCategories 
ADD COLUMN IF NOT EXISTS Collapsed tinyint(1) AFTER Muted;

-- Modify Status table
ALTER TABLE Status 
ADD COLUMN IF NOT EXISTS DNDEndTime bigint AFTER LastActivityAt,
ADD COLUMN IF NOT EXISTS PrevStatus varchar(32) AFTER DNDEndTime;

-- Modify TeamMembers table
ALTER TABLE TeamMembers 
ADD COLUMN IF NOT EXISTS CreateAt bigint DEFAULT 0 AFTER SchemeGuest,
ADD INDEX IF NOT EXISTS idx_teammembers_createat (CreateAt);

-- Modify Teams table
ALTER TABLE Teams 
MODIFY COLUMN Type enum('I','O') AFTER Email,
ADD COLUMN IF NOT EXISTS CloudLimitsArchived tinyint(1) NOT NULL DEFAULT 0 AFTER GroupConstrained;

-- Modify ThreadMemberships table
ALTER TABLE ThreadMemberships 
ADD COLUMN IF NOT EXISTS UnreadMentions bigint AFTER LastUpdated;

-- Modify Threads table
ALTER TABLE Threads 
MODIFY COLUMN Participants json,
ADD COLUMN IF NOT EXISTS ThreadDeleteAt bigint AFTER ChannelId,
ADD COLUMN IF NOT EXISTS ThreadTeamId varchar(26) AFTER ThreadDeleteAt;

-- Modify UploadSessions table
ALTER TABLE UploadSessions 
MODIFY COLUMN Type enum('attachment','import'),
ADD COLUMN IF NOT EXISTS RemoteId varchar(26) AFTER FileOffset,
ADD COLUMN IF NOT EXISTS ReqFileId varchar(26) AFTER RemoteId;

-- Modify Users table
ALTER TABLE Users 
MODIFY COLUMN Props json,
MODIFY COLUMN NotifyProps json,
ADD COLUMN IF NOT EXISTS Position varchar(128) AFTER MfaSecret,
ADD COLUMN IF NOT EXISTS Timezone json AFTER Position,
ADD COLUMN IF NOT EXISTS RemoteId varchar(26) AFTER Timezone,
ADD COLUMN IF NOT EXISTS LastLogin bigint NOT NULL DEFAULT 0 AFTER RemoteId,
ADD COLUMN IF NOT EXISTS MfaUsedTimestamps json AFTER LastLogin;

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