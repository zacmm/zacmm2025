-- =====================================================
-- Mattermost 批次刪除訊息 SQL 腳本
-- =====================================================
-- 用途：批次刪除指定時間點之前的訊息
-- 警告：執行前請先備份資料庫！
-- =====================================================

-- 顯示開始時間
SELECT '========================================' AS '';
SELECT 'Mattermost 批次刪除訊息' AS '';
SELECT CONCAT('開始時間: ', NOW()) AS '';
SELECT '========================================' AS '';
SELECT '' AS '';

-- =====================================================
-- 設定要刪除的時間點
-- =====================================================
-- 請修改下面的日期為你想要的截止時間
-- 格式：'YYYY-MM-DD HH:MM:SS'
SET @DELETE_BEFORE_DATE = '2024-01-01 00:00:00';
SET @DELETE_TIMESTAMP = UNIX_TIMESTAMP(@DELETE_BEFORE_DATE) * 1000;

SELECT CONCAT('將刪除 ', @DELETE_BEFORE_DATE, ' 之前的訊息') AS '';
SELECT CONCAT('時間戳記: ', @DELETE_TIMESTAMP) AS '';
SELECT '' AS '';

-- =====================================================
-- 選項 1: 查看將要刪除的訊息統計
-- =====================================================
SELECT '--- 刪除前統計 ---' AS '';

-- 按頻道統計
SELECT
    c.DisplayName AS '頻道名稱',
    t.DisplayName AS '團隊名稱',
    COUNT(p.Id) AS '將刪除的訊息數',
    MIN(FROM_UNIXTIME(p.CreateAt/1000)) AS '最早訊息時間',
    MAX(FROM_UNIXTIME(p.CreateAt/1000)) AS '最晚訊息時間'
FROM Posts p
JOIN Channels c ON p.ChannelId = c.Id
JOIN Teams t ON c.TeamId = t.Id
WHERE p.CreateAt < @DELETE_TIMESTAMP
  AND p.DeleteAt = 0
GROUP BY c.Id, c.DisplayName, t.DisplayName
ORDER BY COUNT(p.Id) DESC;

SELECT '' AS '';

-- 總計
SELECT
    COUNT(*) AS '總共將刪除的訊息數',
    SUM(LENGTH(p.Message)) / 1024 / 1024 AS '訊息內容大小 (MB)'
FROM Posts p
WHERE p.CreateAt < @DELETE_TIMESTAMP
  AND p.DeleteAt = 0;

SELECT '' AS '';
SELECT '!!! 以下是實際刪除操作，請確認無誤後再執行 !!!' AS '';
SELECT '' AS '';

-- =====================================================
-- 選項 2A: 軟刪除（標記為已刪除，保留在資料庫）
-- =====================================================
-- 取消註解以執行軟刪除
/*
SELECT '執行軟刪除...' AS '';

UPDATE Posts
SET DeleteAt = UNIX_TIMESTAMP() * 1000
WHERE CreateAt < @DELETE_TIMESTAMP
  AND DeleteAt = 0;

SELECT CONCAT('已軟刪除 ', ROW_COUNT(), ' 條訊息') AS '';
*/

-- =====================================================
-- 選項 2B: 僅刪除特定頻道的訊息
-- =====================================================
-- 取消註解並設定頻道 ID 以執行
/*
SET @CHANNEL_ID = 'your_channel_id_here';

SELECT CONCAT('刪除頻道 ', @CHANNEL_ID, ' 在 ', @DELETE_BEFORE_DATE, ' 之前的訊息') AS '';

UPDATE Posts
SET DeleteAt = UNIX_TIMESTAMP() * 1000
WHERE ChannelId = @CHANNEL_ID
  AND CreateAt < @DELETE_TIMESTAMP
  AND DeleteAt = 0;

SELECT CONCAT('已刪除 ', ROW_COUNT(), ' 條訊息') AS '';
*/

-- =====================================================
-- 選項 2C: 僅刪除特定團隊的訊息
-- =====================================================
-- 取消註解並設定團隊 ID 以執行
/*
SET @TEAM_ID = 'your_team_id_here';

SELECT CONCAT('刪除團隊 ', @TEAM_ID, ' 在 ', @DELETE_BEFORE_DATE, ' 之前的訊息') AS '';

UPDATE Posts
SET DeleteAt = UNIX_TIMESTAMP() * 1000
WHERE ChannelId IN (SELECT Id FROM Channels WHERE TeamId = @TEAM_ID)
  AND CreateAt < @DELETE_TIMESTAMP
  AND DeleteAt = 0;

SELECT CONCAT('已刪除 ', ROW_COUNT(), ' 條訊息') AS '';
*/

-- =====================================================
-- 選項 3: 永久刪除（危險！會完全移除資料）
-- =====================================================
-- 警告：這會永久刪除資料，無法復原！
-- 取消註解以執行永久刪除
/*
SELECT '!!! 警告：執行永久刪除 !!!' AS '';

-- 先刪除相關的檔案資訊
DELETE FROM FileInfo
WHERE PostId IN (
    SELECT Id FROM Posts
    WHERE CreateAt < @DELETE_TIMESTAMP
);

-- 刪除訊息的 reactions
DELETE FROM Reactions
WHERE PostId IN (
    SELECT Id FROM Posts
    WHERE CreateAt < @DELETE_TIMESTAMP
);

-- 刪除訊息本身
DELETE FROM Posts
WHERE CreateAt < @DELETE_TIMESTAMP;

SELECT CONCAT('已永久刪除 ', ROW_COUNT(), ' 條訊息及其附件') AS '';
*/

-- =====================================================
-- 選項 4: 刪除已軟刪除的訊息（清理）
-- =====================================================
-- 這會永久刪除所有已標記為刪除的訊息
-- 取消註解以執行
/*
SELECT '永久清理已軟刪除的訊息...' AS '';

-- 刪除已軟刪除訊息的附件
DELETE FROM FileInfo
WHERE PostId IN (
    SELECT Id FROM Posts
    WHERE DeleteAt > 0 AND DeleteAt < @DELETE_TIMESTAMP
);

-- 刪除已軟刪除訊息的 reactions
DELETE FROM Reactions
WHERE PostId IN (
    SELECT Id FROM Posts
    WHERE DeleteAt > 0 AND DeleteAt < @DELETE_TIMESTAMP
);

-- 永久刪除已軟刪除的訊息
DELETE FROM Posts
WHERE DeleteAt > 0 AND DeleteAt < @DELETE_TIMESTAMP;

SELECT CONCAT('已永久清理 ', ROW_COUNT(), ' 條已刪除的訊息') AS '';
*/

-- =====================================================
-- 完成
-- =====================================================
SELECT '' AS '';
SELECT '========================================' AS '';
SELECT '腳本執行完成' AS '';
SELECT CONCAT('結束時間: ', NOW()) AS '';
SELECT '========================================' AS '';
SELECT '' AS '';
SELECT '注意事項：' AS '';
SELECT '1. 軟刪除：訊息仍在資料庫，只是標記為已刪除' AS '';
SELECT '2. 永久刪除：完全從資料庫移除，無法復原' AS '';
SELECT '3. 建議先執行統計查詢，確認要刪除的範圍' AS '';
SELECT '4. 執行前請務必備份資料庫！' AS '';
