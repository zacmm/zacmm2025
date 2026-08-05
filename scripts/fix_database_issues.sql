-- =====================================================
-- Mattermost 資料庫修復腳本
-- =====================================================
-- 用途：修復從生產環境同步後的資料庫問題
-- 問題：
--   1. 字符集校對規則不一致
--   2. 多個欄位存在 NULL 值
-- 建議：在匯入生產資料後執行此腳本
-- =====================================================

-- 顯示開始時間
SELECT '========================================' AS '';
SELECT 'Mattermost 資料庫修復腳本' AS '';
SELECT CONCAT('開始時間: ', NOW()) AS '';
SELECT '========================================' AS '';

-- =====================================================
-- 第一部分：修改資料庫預設校對規則
-- =====================================================

SELECT '步驟 1: 修改資料庫預設校對規則...' AS '';

-- 將資料庫預設校對規則改為 utf8mb4_0900_ai_ci
ALTER DATABASE mattermost_prod_local CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

SELECT '  ✓ 資料庫預設校對規則已更新為 utf8mb4_0900_ai_ci' AS '';

-- =====================================================
-- 第二部分：修改欄位校對規則
-- =====================================================

SELECT '步驟 2: 統一欄位校對規則...' AS '';

-- AccessControlPolicies 表
ALTER TABLE AccessControlPolicies
  MODIFY COLUMN ID varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- AccessControlPolicyHistory 表
ALTER TABLE AccessControlPolicyHistory
  MODIFY COLUMN ID varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- DesktopTokens 表
ALTER TABLE DesktopTokens
  MODIFY COLUMN UserId varchar(26) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- NotifyAdmin 表
ALTER TABLE NotifyAdmin
  MODIFY COLUMN UserId varchar(26) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- PersistentNotifications 表
ALTER TABLE PersistentNotifications
  MODIFY COLUMN PostId varchar(26) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- PostReminders 表
ALTER TABLE PostReminders
  MODIFY COLUMN PostId varchar(26) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  MODIFY COLUMN UserId varchar(26) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- PropertyFields 表
ALTER TABLE PropertyFields
  MODIFY COLUMN ID varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- PropertyGroups 表
ALTER TABLE PropertyGroups
  MODIFY COLUMN ID varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- PropertyValues 表
ALTER TABLE PropertyValues
  MODIFY COLUMN ID varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- RecentSearches 表
ALTER TABLE RecentSearches
  MODIFY COLUMN UserId varchar(26) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- ScheduledPosts 表
ALTER TABLE ScheduledPosts
  MODIFY COLUMN id varchar(26) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  MODIFY COLUMN userid varchar(26) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  MODIFY COLUMN channelid varchar(26) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

SELECT '  ✓ 已修改 14 個表的 18 個欄位校對規則' AS '';

-- =====================================================
-- 第三部分：修復 NULL 值
-- =====================================================

SELECT '步驟 3: 修復 NULL 值...' AS '';

-- 3.1 修復 Channels 表的 TotalMsgCountRoot
SELECT '  處理 Channels.TotalMsgCountRoot...' AS '';
UPDATE Channels
SET TotalMsgCountRoot = 0
WHERE TotalMsgCountRoot IS NULL;

SELECT CONCAT('  ✓ 已修復 Channels.TotalMsgCountRoot (', ROW_COUNT(), ' 筆)') AS '';

-- 3.2 修復 ChannelMembers 表的 MentionCountRoot
SELECT '  處理 ChannelMembers.MentionCountRoot...' AS '';
UPDATE ChannelMembers
SET MentionCountRoot = 0
WHERE MentionCountRoot IS NULL;

SELECT CONCAT('  ✓ 已修復 ChannelMembers.MentionCountRoot (', ROW_COUNT(), ' 筆)') AS '';

-- 3.3 修復 ChannelMembers 表的 MsgCountRoot
SELECT '  處理 ChannelMembers.MsgCountRoot...' AS '';
UPDATE ChannelMembers
SET MsgCountRoot = 0
WHERE MsgCountRoot IS NULL;

SELECT CONCAT('  ✓ 已修復 ChannelMembers.MsgCountRoot (', ROW_COUNT(), ' 筆)') AS '';

-- 3.4 修復 SidebarCategories 表的 Collapsed
SELECT '  處理 SidebarCategories.Collapsed...' AS '';
UPDATE SidebarCategories
SET Collapsed = 0
WHERE Collapsed IS NULL;

SELECT CONCAT('  ✓ 已修復 SidebarCategories.Collapsed (', ROW_COUNT(), ' 筆)') AS '';

-- =====================================================
-- 第四部分：修復 SidebarChannels 缺失問題
-- =====================================================

SELECT '步驟 4: 修復 SidebarChannels 側邊欄頻道配置缺失...' AS '';

-- 4.1 先顯示受影響的用戶統計
SELECT '  統計受影響的用戶...' AS '';

SELECT
    CONCAT('  發現 ', COUNT(*), ' 個用戶缺少側邊欄頻道配置') AS ''
FROM (
    SELECT
        u.Id,
        COUNT(DISTINCT cm.ChannelId) - COUNT(DISTINCT scm.ChannelId) AS Missing_Count
    FROM Users u
    JOIN ChannelMembers cm ON u.Id = cm.UserId
    JOIN Channels c ON cm.ChannelId = c.Id
    LEFT JOIN SidebarChannels scm ON cm.ChannelId = scm.ChannelId
    LEFT JOIN SidebarCategories sc ON scm.CategoryId = sc.Id AND sc.UserId = u.Id
    WHERE u.DeleteAt = 0
      AND c.Type IN ('O', 'P')
    GROUP BY u.Id
    HAVING Missing_Count > 0
) AS stats;

-- 4.2 為缺失的頻道添加到側邊欄的 Channels 分類中
SELECT '  將缺失的頻道加入側邊欄分類...' AS '';

INSERT INTO SidebarChannels (ChannelId, UserId, CategoryId, SortOrder)
SELECT
    cm.ChannelId,
    cm.UserId,
    CONCAT('channels_', cm.UserId, '_', c.TeamId) AS CategoryId,
    0 AS SortOrder
FROM ChannelMembers cm
JOIN Channels c ON cm.ChannelId = c.Id
JOIN Users u ON cm.UserId = u.Id
WHERE u.DeleteAt = 0
  AND c.Type IN ('O', 'P')  -- 只處理公開和私人頻道
  AND NOT EXISTS (
      SELECT 1
      FROM SidebarChannels sc
      JOIN SidebarCategories cat ON sc.CategoryId = cat.Id
      WHERE sc.ChannelId = cm.ChannelId
        AND cat.UserId = cm.UserId
  )
  -- 確保對應的 SidebarCategories 存在
  AND EXISTS (
      SELECT 1
      FROM SidebarCategories cat
      WHERE cat.Id = CONCAT('channels_', cm.UserId, '_', c.TeamId)
  );

SELECT CONCAT('  ✓ 已添加 ', ROW_COUNT(), ' 個頻道到側邊欄') AS '';

-- =====================================================
-- 完成
-- =====================================================

SELECT '========================================' AS '';
SELECT '所有修復已完成！' AS '';
SELECT CONCAT('結束時間: ', NOW()) AS '';
SELECT '========================================' AS '';
SELECT '' AS '';
SELECT '下一步：執行 verify_database_fixes.sql 驗證修復結果' AS '';
