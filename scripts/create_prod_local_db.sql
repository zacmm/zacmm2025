-- 建立生產環境備份資料庫
-- 使用方式：在遠端 MySQL 伺服器上以 root 身份執行
-- mysql -u root -p < create_prod_local_db.sql

-- 建立資料庫
CREATE DATABASE IF NOT EXISTS mattermost_prod_local
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

-- 授權 mmuser 完整存取權限
GRANT ALL PRIVILEGES ON mattermost_prod_local.* TO 'mmuser'@'%';

-- 重新載入權限
FLUSH PRIVILEGES;

-- 顯示授權結果
SHOW GRANTS FOR 'mmuser'@'%';

-- 顯示資料庫列表
SHOW DATABASES LIKE 'mattermost%';
