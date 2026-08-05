-- =====================================================
-- Mattermost 資料庫修復驗證腳本
-- =====================================================
-- 用途：驗證 fix_database_issues.sql 的修復結果
-- 使用方式：mysql -h <host> -u <user> -p <database> < verify_database_fixes.sql
-- =====================================================

-- 顯示開始時間
SELECT '========================================' AS '';
SELECT 'Mattermost 資料庫修復驗證' AS '';
SELECT CONCAT('驗證時間: ', NOW()) AS '';
SELECT '========================================' AS '';
SELECT '' AS '';

-- =====================================================
-- 檢查 1: 資料庫預設校對規則
-- =====================================================

SELECT '檢查 1: 資料庫預設校對規則' AS '';
SELECT '----------------------------------------' AS '';

SELECT
  SCHEMA_NAME AS '資料庫',
  DEFAULT_CHARACTER_SET_NAME AS '字符集',
  DEFAULT_COLLATION_NAME AS '校對規則',
  CASE
    WHEN DEFAULT_COLLATION_NAME = 'utf8mb4_0900_ai_ci' THEN '✓ 正確'
    ELSE '✗ 錯誤'
  END AS '狀態'
FROM INFORMATION_SCHEMA.SCHEMATA
WHERE SCHEMA_NAME = DATABASE();

SELECT '' AS '';

-- =====================================================
-- 檢查 2: 欄位校對規則
-- =====================================================

SELECT '檢查 2: 欄位校對規則一致性' AS '';
SELECT '----------------------------------------' AS '';

-- 檢查是否還有使用 utf8mb4_unicode_ci 的 ID 相關欄位
SELECT
  TABLE_NAME AS '表名',
  COLUMN_NAME AS '欄位名',
  COLLATION_NAME AS '校對規則',
  '✗ 需要修復' AS '狀態'
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND COLLATION_NAME = 'utf8mb4_unicode_ci'
  AND COLUMN_NAME IN ('Id', 'ID', 'UserId', 'TeamId', 'ChannelId', 'PostId', 'id', 'userid', 'channelid')
UNION ALL
SELECT
  '所有檢查的欄位' AS '表名',
  '校對規則' AS '欄位名',
  '均為 utf8mb4_0900_ai_ci' AS '校對規則',
  '✓ 正確' AS '狀態'
WHERE NOT EXISTS (
  SELECT 1
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND COLLATION_NAME = 'utf8mb4_unicode_ci'
    AND COLUMN_NAME IN ('Id', 'ID', 'UserId', 'TeamId', 'ChannelId', 'PostId', 'id', 'userid', 'channelid')
);

SELECT '' AS '';

-- =====================================================
-- 檢查 3: NULL 值檢查
-- =====================================================

SELECT '檢查 3: NULL 值檢查' AS '';
SELECT '----------------------------------------' AS '';

-- 3.1 檢查 Channels 表
SELECT
  'Channels' AS '表名',
  'TotalMsgCountRoot' AS '欄位',
  COUNT(*) AS 'NULL 數量',
  CASE
    WHEN COUNT(*) = 0 THEN '✓ 正確'
    ELSE '✗ 仍有 NULL'
  END AS '狀態'
FROM Channels
WHERE TotalMsgCountRoot IS NULL;

-- 3.2 檢查 ChannelMembers 表 - MentionCountRoot
SELECT
  'ChannelMembers' AS '表名',
  'MentionCountRoot' AS '欄位',
  COUNT(*) AS 'NULL 數量',
  CASE
    WHEN COUNT(*) = 0 THEN '✓ 正確'
    ELSE '✗ 仍有 NULL'
  END AS '狀態'
FROM ChannelMembers
WHERE MentionCountRoot IS NULL;

-- 3.3 檢查 ChannelMembers 表 - MsgCountRoot
SELECT
  'ChannelMembers' AS '表名',
  'MsgCountRoot' AS '欄位',
  COUNT(*) AS 'NULL 數量',
  CASE
    WHEN COUNT(*) = 0 THEN '✓ 正確'
    ELSE '✗ 仍有 NULL'
  END AS '狀態'
FROM ChannelMembers
WHERE MsgCountRoot IS NULL;

SELECT '' AS '';

-- =====================================================
-- 檢查 4: 額外的 NULL 值檢查
-- =====================================================

SELECT '檢查 4: ChannelMembers 其他欄位 NULL 檢查' AS '';
SELECT '----------------------------------------' AS '';

SELECT
  SUM(CASE WHEN MentionCount IS NULL THEN 1 ELSE 0 END) AS 'MentionCount_NULL',
  SUM(CASE WHEN MsgCount IS NULL THEN 1 ELSE 0 END) AS 'MsgCount_NULL',
  SUM(CASE WHEN LastViewedAt IS NULL THEN 1 ELSE 0 END) AS 'LastViewedAt_NULL',
  SUM(CASE WHEN LastUpdateAt IS NULL THEN 1 ELSE 0 END) AS 'LastUpdateAt_NULL',
  CASE
    WHEN SUM(CASE WHEN MentionCount IS NULL THEN 1 ELSE 0 END) = 0
     AND SUM(CASE WHEN MsgCount IS NULL THEN 1 ELSE 0 END) = 0
     AND SUM(CASE WHEN LastViewedAt IS NULL THEN 1 ELSE 0 END) = 0
     AND SUM(CASE WHEN LastUpdateAt IS NULL THEN 1 ELSE 0 END) = 0
    THEN '✓ 全部正確'
    ELSE '✗ 有 NULL 值'
  END AS '狀態'
FROM ChannelMembers;

SELECT '' AS '';

-- =====================================================
-- 檢查 5: Channels 其他欄位 NULL 檢查
-- =====================================================

SELECT '檢查 5: Channels 其他欄位 NULL 檢查' AS '';
SELECT '----------------------------------------' AS '';

SELECT
  SUM(CASE WHEN TotalMsgCount IS NULL THEN 1 ELSE 0 END) AS 'TotalMsgCount_NULL',
  CASE
    WHEN SUM(CASE WHEN TotalMsgCount IS NULL THEN 1 ELSE 0 END) = 0
    THEN '✓ 正確'
    ELSE '✗ 有 NULL 值'
  END AS '狀態'
FROM Channels;

SELECT '' AS '';

-- =====================================================
-- 檢查 6: SidebarCategories Collapsed 欄位檢查
-- =====================================================

SELECT '檢查 6: SidebarCategories.Collapsed NULL 檢查' AS '';
SELECT '----------------------------------------' AS '';

SELECT
  'SidebarCategories' AS '表名',
  'Collapsed' AS '欄位',
  COUNT(*) AS 'NULL 數量',
  CASE
    WHEN COUNT(*) = 0 THEN '✓ 正確'
    ELSE '✗ 仍有 NULL'
  END AS '狀態'
FROM SidebarCategories
WHERE Collapsed IS NULL;

SELECT '' AS '';

-- =====================================================
-- 檢查 7: SidebarChannels 完整性檢查
-- =====================================================

SELECT '檢查 7: SidebarChannels 側邊欄頻道配置完整性' AS '';
SELECT '----------------------------------------' AS '';

-- 統計仍然缺少側邊欄配置的用戶和頻道
SELECT
    CASE
        WHEN COUNT(*) = 0 THEN '✓ 所有用戶的頻道都已配置到側邊欄'
        ELSE CONCAT('✗ 仍有 ', COUNT(*), ' 個用戶缺少側邊欄配置')
    END AS '檢查結果',
    COALESCE(SUM(Missing_Count), 0) AS '缺失頻道總數'
FROM (
    SELECT
        u.Id,
        u.Username,
        COUNT(DISTINCT cm.ChannelId) - COUNT(DISTINCT scm.ChannelId) AS Missing_Count
    FROM Users u
    JOIN ChannelMembers cm ON u.Id = cm.UserId
    JOIN Channels c ON cm.ChannelId = c.Id
    LEFT JOIN SidebarChannels scm ON cm.ChannelId = scm.ChannelId
    LEFT JOIN SidebarCategories sc ON scm.CategoryId = sc.Id AND sc.UserId = u.Id
    WHERE u.DeleteAt = 0
      AND c.Type IN ('O', 'P')
    GROUP BY u.Id, u.Username
    HAVING Missing_Count > 0
) AS stats;

SELECT '' AS '';

-- =====================================================
-- 總結
-- =====================================================

SELECT '========================================' AS '';
SELECT '驗證完成' AS '';
SELECT '========================================' AS '';
SELECT '' AS '';
SELECT '如果所有檢查都顯示 ✓ 正確，表示修復成功！' AS '';
SELECT '如果有任何 ✗ 錯誤，請重新執行 fix_database_issues.sql' AS '';
SELECT '' AS '';
