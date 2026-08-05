-- 優化 FileInfo 資料表查詢性能

-- 1. 檢查當前索引
SHOW INDEX FROM mattermost_prod_local.FileInfo;

-- 2. 檢查資料表大小
SELECT
    COUNT(*) as total_files,
    ROUND(DATA_LENGTH / 1024 / 1024, 2) as data_size_mb,
    ROUND(INDEX_LENGTH / 1024 / 1024, 2) as index_size_mb
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'mattermost_prod_local'
AND TABLE_NAME = 'FileInfo';

-- 3. 檢查是否有全文搜尋索引
SELECT
    TABLE_NAME,
    INDEX_NAME,
    INDEX_TYPE,
    GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) as columns
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'mattermost_prod_local'
  AND TABLE_NAME = 'FileInfo'
  AND INDEX_TYPE = 'FULLTEXT'
GROUP BY TABLE_NAME, INDEX_NAME, INDEX_TYPE;

-- 4. 如果缺少索引，可以添加（請先備份！）
-- 注意：在大表上建立索引可能需要很長時間，建議在低峰期執行

-- 檔案名稱搜尋索引（如果不存在）
-- CREATE INDEX idx_fileinfo_name ON mattermost_prod_local.FileInfo(Name(255));

-- 建立時間索引（用於排序和篩選）
-- CREATE INDEX idx_fileinfo_createat ON mattermost_prod_local.FileInfo(CreateAt);

-- 刪除標記索引（排除已刪除的檔案）
-- CREATE INDEX idx_fileinfo_deleteat ON mattermost_prod_local.FileInfo(DeleteAt);

-- 5. 分析慢查詢（執行搜尋後查看）
-- EXPLAIN SELECT * FROM FileInfo WHERE Name LIKE '%keyword%' AND DeleteAt = 0 ORDER BY CreateAt DESC LIMIT 100;
