-- ========================================
-- 資料清理 SQL 腳本
-- 目的：刪除超過一年的 Posts 和 FileInfo 資料
-- 一年前時間點：2024-10-22 (timestamp: 1729592229000)
-- ========================================

-- 查看刪除前的資料量
SELECT '刪除前統計' as 狀態;
SELECT
    'Posts' as 表格,
    COUNT(*) as 總筆數,
    SUM(CASE WHEN CreateAt < 1729592229000 THEN 1 ELSE 0 END) as 將刪除筆數,
    SUM(CASE WHEN CreateAt >= 1729592229000 THEN 1 ELSE 0 END) as 將保留筆數
FROM Posts;

SELECT
    'FileInfo' as 表格,
    COUNT(*) as 總筆數,
    SUM(CASE WHEN CreateAt < 1729592229000 THEN 1 ELSE 0 END) as 將刪除筆數,
    SUM(CASE WHEN CreateAt >= 1729592229000 THEN 1 ELSE 0 END) as 將保留筆數
FROM FileInfo;

-- ========================================
-- 開始刪除 Posts（分批執行，避免長時間鎖表）
-- ========================================

-- 每次執行刪除 50000 筆，需要多次執行直到 ROW_COUNT() 為 0
-- 方式 1：手動多次執行（推薦）
DELETE FROM Posts WHERE CreateAt < 1729592229000 LIMIT 50000;
-- 重複執行上面這行，直到顯示 "0 rows affected"

-- 方式 2：使用迴圈（需要確認 MySQL 支援）
-- DELIMITER $$
-- CREATE PROCEDURE cleanup_posts()
-- BEGIN
--     DECLARE deleted_rows INT DEFAULT 1;
--     WHILE deleted_rows > 0 DO
--         DELETE FROM Posts WHERE CreateAt < 1729592229000 LIMIT 50000;
--         SET deleted_rows = ROW_COUNT();
--         SELECT CONCAT('已刪除 Posts: ', deleted_rows, ' 筆') as 進度;
--         DO SLEEP(0.5);
--     END WHILE;
-- END$$
-- DELIMITER ;
--
-- CALL cleanup_posts();
-- DROP PROCEDURE cleanup_posts;

-- ========================================
-- 開始刪除 FileInfo（分批執行）
-- ========================================

-- 每次執行刪除 50000 筆，需要多次執行直到 ROW_COUNT() 為 0
DELETE FROM FileInfo WHERE CreateAt < 1729592229000 LIMIT 50000;
-- 重複執行上面這行，直到顯示 "0 rows affected"

-- ========================================
-- 查看刪除後的資料量
-- ========================================

SELECT '刪除後統計' as 狀態;
SELECT 'Posts' as 表格, COUNT(*) as 剩餘筆數 FROM Posts;
SELECT 'FileInfo' as 表格, COUNT(*) as 剩餘筆數 FROM FileInfo;

-- ========================================
-- 優化表格（回收磁碟空間）
-- ========================================

-- 注意：OPTIMIZE TABLE 會鎖表，可能需要 5-10 分鐘
OPTIMIZE TABLE Posts;
OPTIMIZE TABLE FileInfo;

-- 查看表格大小
SELECT
    TABLE_NAME as 表格,
    ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) as 大小_MB
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'mattermost_prod_local'
  AND TABLE_NAME IN ('Posts', 'FileInfo');
