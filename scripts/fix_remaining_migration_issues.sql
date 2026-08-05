-- ================================================================
-- Mattermost Migration 完整性修复脚本
-- ================================================================
-- 日期: 2025-11-04
-- 目的: 修复数据导入后遗留的 migration 问题
-- 数据库: mattermost_prod_local
-- ================================================================

USE mattermost_prod_local;

-- ================================================================
-- 1. 修复 Roles.Permissions 字段类型
-- ================================================================
-- 问题: Permissions 字段类型为 text，应该是 longtext
-- 来源: Migration 000017_create_roles.up.sql
-- 影响: text 最大 65,535 字节，可能导致权限列表过长时无法保存

SELECT '修复 Roles.Permissions 字段类型...' as Status;

ALTER TABLE Roles MODIFY Permissions longtext;

SELECT 'Roles.Permissions 字段类型已修复为 longtext' as Status;

-- ================================================================
-- 验证修复结果
-- ================================================================

SELECT '========================================' as '';
SELECT '验证修复结果' as Status;
SELECT '========================================' as '';

-- 验证 Roles.Permissions 字段类型
SELECT
    CASE
        WHEN column_type = 'longtext' THEN '✓ Roles.Permissions 字段类型正确 (longtext)'
        ELSE CONCAT('✗ Roles.Permissions 字段类型错误: ', column_type)
    END as verification_result
FROM information_schema.columns
WHERE table_schema = 'mattermost_prod_local'
  AND table_name = 'Roles'
  AND column_name = 'Permissions';

-- ================================================================
-- 完整性检查 - 验证所有关键字段
-- ================================================================

SELECT '========================================' as '';
SELECT '完整性检查 - 所有关键字段' as Status;
SELECT '========================================' as '';

-- 检查 Reactions 表（之前修复的）
SELECT
    CONCAT(
        '✓ Reactions: ',
        SUM(CASE WHEN column_name = 'UpdateAt' THEN 1 ELSE 0 END), ' UpdateAt, ',
        SUM(CASE WHEN column_name = 'DeleteAt' THEN 1 ELSE 0 END), ' DeleteAt, ',
        SUM(CASE WHEN column_name = 'RemoteId' THEN 1 ELSE 0 END), ' RemoteId'
    ) as check_result
FROM information_schema.columns
WHERE table_schema = 'mattermost_prod_local'
  AND table_name = 'Reactions'
  AND column_name IN ('UpdateAt', 'DeleteAt', 'RemoteId');

-- 检查 Commands 表
SELECT
    CONCAT(
        '✓ Commands: ',
        SUM(CASE WHEN column_name = 'PluginId' THEN 1 ELSE 0 END), ' PluginId'
    ) as check_result
FROM information_schema.columns
WHERE table_schema = 'mattermost_prod_local'
  AND table_name = 'Commands'
  AND column_name = 'PluginId';

-- 检查 IncomingWebhooks 表
SELECT
    CONCAT(
        '✓ IncomingWebhooks: ',
        SUM(CASE WHEN column_name = 'IconURL' THEN 1 ELSE 0 END), ' IconURL, ',
        SUM(CASE WHEN column_name = 'ChannelLocked' THEN 1 ELSE 0 END), ' ChannelLocked'
    ) as check_result
FROM information_schema.columns
WHERE table_schema = 'mattermost_prod_local'
  AND table_name = 'IncomingWebhooks'
  AND column_name IN ('IconURL', 'ChannelLocked');

-- 检查 Roles 表
SELECT
    CONCAT(
        '✓ Roles: ',
        SUM(CASE WHEN column_name = 'BuiltIn' THEN 1 ELSE 0 END), ' BuiltIn, ',
        SUM(CASE WHEN column_name = 'Permissions' AND column_type = 'longtext' THEN 1 ELSE 0 END), ' Permissions(longtext)'
    ) as check_result
FROM information_schema.columns
WHERE table_schema = 'mattermost_prod_local'
  AND table_name = 'Roles'
  AND (column_name = 'BuiltIn' OR (column_name = 'Permissions' AND column_type = 'longtext'));

-- 检查 Sessions 表
SELECT
    CONCAT(
        '✓ Sessions: ',
        SUM(CASE WHEN column_name = 'ExpiredNotify' THEN 1 ELSE 0 END), ' ExpiredNotify'
    ) as check_result
FROM information_schema.columns
WHERE table_schema = 'mattermost_prod_local'
  AND table_name = 'Sessions'
  AND column_name = 'ExpiredNotify';

-- 检查 UploadSessions 表
SELECT
    CONCAT(
        '✓ UploadSessions: ',
        SUM(CASE WHEN column_name = 'RemoteId' THEN 1 ELSE 0 END), ' RemoteId, ',
        SUM(CASE WHEN column_name = 'ReqFileId' THEN 1 ELSE 0 END), ' ReqFileId'
    ) as check_result
FROM information_schema.columns
WHERE table_schema = 'mattermost_prod_local'
  AND table_name = 'UploadSessions'
  AND column_name IN ('RemoteId', 'ReqFileId');

-- 检查 Threads 表
SELECT
    CONCAT(
        '✓ Threads: ',
        SUM(CASE WHEN column_name = 'ChannelId' THEN 1 ELSE 0 END), ' ChannelId'
    ) as check_result
FROM information_schema.columns
WHERE table_schema = 'mattermost_prod_local'
  AND table_name = 'Threads'
  AND column_name = 'ChannelId';

-- 检查 Users 表
SELECT
    CONCAT(
        '✓ Users: ',
        SUM(CASE WHEN column_name = 'Position' THEN 1 ELSE 0 END), ' Position, ',
        SUM(CASE WHEN column_name = 'Timezone' THEN 1 ELSE 0 END), ' Timezone, ',
        SUM(CASE WHEN column_name = 'RemoteId' THEN 1 ELSE 0 END), ' RemoteId'
    ) as check_result
FROM information_schema.columns
WHERE table_schema = 'mattermost_prod_local'
  AND table_name = 'Users'
  AND column_name IN ('Position', 'Timezone', 'RemoteId');

-- 检查 ChannelMembers 表
SELECT
    CONCAT(
        '✓ ChannelMembers: ',
        SUM(CASE WHEN column_name = 'MentionCountRoot' THEN 1 ELSE 0 END), ' MentionCountRoot, ',
        SUM(CASE WHEN column_name = 'MsgCountRoot' THEN 1 ELSE 0 END), ' MsgCountRoot'
    ) as check_result
FROM information_schema.columns
WHERE table_schema = 'mattermost_prod_local'
  AND table_name = 'ChannelMembers'
  AND column_name IN ('MentionCountRoot', 'MsgCountRoot');

-- 检查 Channels 表
SELECT
    CONCAT(
        '✓ Channels: ',
        SUM(CASE WHEN column_name = 'TotalMsgCountRoot' THEN 1 ELSE 0 END), ' TotalMsgCountRoot, ',
        SUM(CASE WHEN column_name = 'LastRootPostAt' THEN 1 ELSE 0 END), ' LastRootPostAt'
    ) as check_result
FROM information_schema.columns
WHERE table_schema = 'mattermost_prod_local'
  AND table_name = 'Channels'
  AND column_name IN ('TotalMsgCountRoot', 'LastRootPostAt');

SELECT '========================================' as '';
SELECT '所有修复完成！' as Status;
SELECT '========================================' as '';
