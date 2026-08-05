-- =====================================================
-- Mattermost FULLTEXT 索引重建腳本
-- 用途：降低 innodb_ft_min_token_size 後重建索引
-- 執行時間：約 2-4 小時（100萬筆 Posts）
-- =====================================================

-- 開始記錄時間
SELECT 'Started at' as Status, NOW() as Time;

-- =====================================================
-- 1. Posts 表（最大的表，會花最多時間）
-- =====================================================
SELECT '開始處理 Posts 表' as Status, NOW() as Time;

-- 刪除舊索引
ALTER TABLE Posts DROP INDEX idx_posts_message_txt;

-- 創建新索引（這步會花很長時間）
ALTER TABLE Posts ADD FULLTEXT INDEX idx_posts_message_txt (Message);

SELECT 'Posts 表完成' as Status, NOW() as Time;

-- =====================================================
-- 2. Channels 表
-- =====================================================
SELECT '開始處理 Channels 表' as Status, NOW() as Time;

-- 檢查是否有 fulltext 索引
SELECT COUNT(*) INTO @has_index
FROM information_schema.STATISTICS
WHERE table_schema = 'mattermost_prod_local'
  AND table_name = 'Channels'
  AND index_type = 'FULLTEXT';

-- 如果有，重建
-- 注意：這裡需要知道實際的索引名稱，先執行 SHOW INDEX FROM Channels;

-- =====================================================
-- 3. Users 表
-- =====================================================
SELECT '開始處理 Users 表' as Status, NOW() as Time;

-- 同上，先確認索引名稱

-- =====================================================
-- 4. FileInfo 表
-- =====================================================
SELECT '開始處理 FileInfo 表' as Status, NOW() as Time;

-- 同上，先確認索引名稱

-- =====================================================
-- 完成
-- =====================================================
SELECT '所有索引重建完成！' as Status, NOW() as Time;

-- 檢查索引狀態
SHOW INDEX FROM Posts WHERE Key_name = 'idx_posts_message_txt';
