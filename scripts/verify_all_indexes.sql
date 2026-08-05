-- ================================================================
-- 验证所有 Migration 相关的索引
-- ================================================================

USE mattermost_prod_local;

SELECT '========================================' as '';
SELECT '检查所有关键索引' as Status;
SELECT '========================================' as '';

-- Commands 表索引
SELECT
    CASE
        WHEN COUNT(*) = 4 THEN '✓ Commands: 所有索引存在 (4/4)'
        ELSE CONCAT('✗ Commands: 索引缺失 (', COUNT(*), '/4)')
    END as check_result
FROM information_schema.statistics
WHERE table_schema = 'mattermost_prod_local'
  AND table_name = 'Commands'
  AND index_name IN (
    'idx_command_team_id',
    'idx_command_update_at',
    'idx_command_create_at',
    'idx_command_delete_at'
  );

-- IncomingWebhooks 表索引
SELECT
    CASE
        WHEN COUNT(*) = 5 THEN '✓ IncomingWebhooks: 所有索引存在 (5/5)'
        ELSE CONCAT('✗ IncomingWebhooks: 索引缺失 (', COUNT(*), '/5)')
    END as check_result
FROM information_schema.statistics
WHERE table_schema = 'mattermost_prod_local'
  AND table_name = 'IncomingWebhooks'
  AND index_name IN (
    'idx_incoming_webhook_user_id',
    'idx_incoming_webhook_team_id',
    'idx_incoming_webhook_update_at',
    'idx_incoming_webhook_create_at',
    'idx_incoming_webhook_delete_at'
  );

-- Reactions 表索引
SELECT
    CASE
        WHEN COUNT(*) > 0 THEN '✓ Reactions: idx_reactions_channel_id 存在'
        ELSE '✗ Reactions: idx_reactions_channel_id 缺失'
    END as check_result
FROM information_schema.statistics
WHERE table_schema = 'mattermost_prod_local'
  AND table_name = 'Reactions'
  AND index_name = 'idx_reactions_channel_id';

-- Sessions 表索引
SELECT
    CASE
        WHEN COUNT(*) = 5 THEN '✓ Sessions: 所有索引存在 (5/5)'
        ELSE CONCAT('✗ Sessions: 索引缺失 (', COUNT(*), '/5)')
    END as check_result
FROM information_schema.statistics
WHERE table_schema = 'mattermost_prod_local'
  AND table_name = 'Sessions'
  AND index_name IN (
    'idx_sessions_user_id',
    'idx_sessions_token',
    'idx_sessions_expires_at',
    'idx_sessions_create_at',
    'idx_sessions_last_activity_at'
  );

-- Preferences 表索引
SELECT
    CASE
        WHEN COUNT(*) = 2 THEN '✓ Preferences: 所有索引存在 (2/2)'
        ELSE CONCAT('✗ Preferences: 索引缺失 (', COUNT(*), '/2)')
    END as check_result
FROM information_schema.statistics
WHERE table_schema = 'mattermost_prod_local'
  AND table_name = 'Preferences'
  AND index_name IN (
    'idx_preferences_category',
    'idx_preferences_name'
  );

-- 验证 Preferences 不应该有的索引已删除
SELECT
    CASE
        WHEN COUNT(*) = 0 THEN '✓ Preferences: idx_preferences_user_id 已正确删除'
        ELSE '✗ Preferences: idx_preferences_user_id 仍然存在（应该删除）'
    END as check_result
FROM information_schema.statistics
WHERE table_schema = 'mattermost_prod_local'
  AND table_name = 'Preferences'
  AND index_name = 'idx_preferences_user_id';

-- UploadSessions 表索引
SELECT
    CASE
        WHEN COUNT(*) = 3 THEN '✓ UploadSessions: 所有索引存在 (3/3)'
        ELSE CONCAT('✗ UploadSessions: 索引缺失 (', COUNT(*), '/3)')
    END as check_result
FROM information_schema.statistics
WHERE table_schema = 'mattermost_prod_local'
  AND table_name = 'UploadSessions'
  AND index_name IN (
    'idx_uploadsessions_user_id',
    'idx_uploadsessions_create_at',
    'idx_uploadsessions_type'
  );

-- 验证 UploadSessions.idx_uploadsessions_user_id 指向正确的列
SELECT
    CASE
        WHEN column_name = 'UserId' THEN '✓ UploadSessions: idx_uploadsessions_user_id 指向正确的列 (UserId)'
        ELSE CONCAT('✗ UploadSessions: idx_uploadsessions_user_id 指向错误的列 (', column_name, ')')
    END as check_result
FROM information_schema.statistics
WHERE table_schema = 'mattermost_prod_local'
  AND table_name = 'UploadSessions'
  AND index_name = 'idx_uploadsessions_user_id';

-- Threads 表索引
SELECT
    CASE
        WHEN COUNT(*) > 0 THEN '✓ Threads: idx_threads_channel_id 相关索引存在'
        ELSE '✗ Threads: idx_threads_channel_id 相关索引缺失'
    END as check_result
FROM information_schema.statistics
WHERE table_schema = 'mattermost_prod_local'
  AND table_name = 'Threads'
  AND (index_name = 'idx_threads_channel_id' OR index_name LIKE 'idx_threads_channel_id%');

-- Users 表索引
SELECT
    CASE
        WHEN COUNT(*) = 3 THEN '✓ Users: 所有基础索引存在 (3/3)'
        ELSE CONCAT('✗ Users: 基础索引缺失 (', COUNT(*), '/3)')
    END as check_result
FROM information_schema.statistics
WHERE table_schema = 'mattermost_prod_local'
  AND table_name = 'Users'
  AND index_name IN (
    'idx_users_update_at',
    'idx_users_create_at',
    'idx_users_delete_at'
  );

-- Users 表全文索引
SELECT
    CASE
        WHEN COUNT(*) = 4 THEN '✓ Users: 所有全文索引存在 (4/4)'
        ELSE CONCAT('✗ Users: 全文索引缺失 (', COUNT(*), '/4)')
    END as check_result
FROM information_schema.statistics
WHERE table_schema = 'mattermost_prod_local'
  AND table_name = 'Users'
  AND index_name IN (
    'idx_users_all_txt',
    'idx_users_all_no_full_name_txt',
    'idx_users_names_txt',
    'idx_users_names_no_full_name_txt'
  );

-- 验证 Users 不应该有的索引已删除
SELECT
    CASE
        WHEN COUNT(*) = 0 THEN '✓ Users: idx_users_email 已正确删除'
        ELSE '✗ Users: idx_users_email 仍然存在（应该删除）'
    END as check_result
FROM information_schema.statistics
WHERE table_schema = 'mattermost_prod_local'
  AND table_name = 'Users'
  AND index_name = 'idx_users_email';

-- PublicChannels 表索引
SELECT
    CASE
        WHEN COUNT(*) = 2 THEN '✓ PublicChannels: 所有索引存在 (2/2)'
        ELSE CONCAT('✗ PublicChannels: 索引缺失 (', COUNT(*), '/2)')
    END as check_result
FROM information_schema.statistics
WHERE table_schema = 'mattermost_prod_local'
  AND table_name = 'PublicChannels'
  AND index_name IN (
    'idx_publicchannels_team_id',
    'idx_publicchannels_delete_at'
  );

-- 验证 PublicChannels 不应该有的索引已删除
SELECT
    CASE
        WHEN COUNT(*) = 0 THEN '✓ PublicChannels: idx_publicchannels_name 已正确删除'
        ELSE '✗ PublicChannels: idx_publicchannels_name 仍然存在（应该删除）'
    END as check_result
FROM information_schema.statistics
WHERE table_schema = 'mattermost_prod_local'
  AND table_name = 'PublicChannels'
  AND index_name = 'idx_publicchannels_name';

-- Posts 表索引
SELECT
    CASE
        WHEN COUNT(*) > 0 THEN '✓ Posts: idx_posts_root_id_delete_at 存在'
        ELSE '✗ Posts: idx_posts_root_id_delete_at 缺失'
    END as check_result
FROM information_schema.statistics
WHERE table_schema = 'mattermost_prod_local'
  AND table_name = 'Posts'
  AND index_name = 'idx_posts_root_id_delete_at';

-- 验证 Posts 不应该有的索引已删除
SELECT
    CASE
        WHEN COUNT(*) = 0 THEN '✓ Posts: idx_posts_root_id 已正确删除'
        ELSE '✗ Posts: idx_posts_root_id 仍然存在（应该删除）'
    END as check_result
FROM information_schema.statistics
WHERE table_schema = 'mattermost_prod_local'
  AND table_name = 'Posts'
  AND index_name = 'idx_posts_root_id';

SELECT '========================================' as '';
SELECT '索引检查完成！' as Status;
SELECT '========================================' as '';
