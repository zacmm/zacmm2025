-- 修復 create_preferences migration 問題
-- 在遠端資料庫執行：mysql mattermost_prod_local < fix_preferences_migration.sql

-- 1. 刪除可能殘留的 stored procedure
DROP PROCEDURE IF EXISTS RenameSolarizedThemeWithUnderscore;

-- 2. 檢查 Preferences 表是否已存在
-- 如果存在，說明之前的 migration 部分成功了

-- 3. 手動執行 Preferences 表的建立和索引（如果還沒有的話）
CREATE TABLE IF NOT EXISTS Preferences (
    UserId varchar(26) NOT NULL,
    Category varchar(32) NOT NULL,
    Name varchar(32) NOT NULL,
    Value text,
    PRIMARY KEY (UserId, Category, Name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 4. 確保 Value 欄位是 text 類型
ALTER TABLE Preferences MODIFY COLUMN Value text;

-- 5. 建立索引（如果還沒有的話）
CREATE INDEX IF NOT EXISTS idx_preferences_category ON Preferences(Category);
CREATE INDEX IF NOT EXISTS idx_preferences_name ON Preferences(Name);

-- 6. 刪除舊的索引（如果存在）
-- DROP INDEX IF EXISTS idx_preferences_user_id ON Preferences;

-- 7. 手動標記這個 migration 為已完成
INSERT IGNORE INTO db_migrations (Version, Name) VALUES (92, 'create_preferences');

-- 8. 驗證結果
SELECT '=== 驗證 Preferences 表 ===' as Status;
SHOW TABLES LIKE 'Preferences';

SELECT '=== 驗證索引 ===' as Status;
SHOW INDEX FROM Preferences;

SELECT '=== 驗證 db_migrations ===' as Status;
SELECT * FROM db_migrations WHERE Name = 'create_preferences';

SELECT '=== 檢查是否還有殘留的 procedures ===' as Status;
SHOW PROCEDURE STATUS WHERE Db = 'mattermost_prod_local';
