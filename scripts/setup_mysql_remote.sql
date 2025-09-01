-- MySQL 遠端連線設定腳本
-- 執行方式: mysql -u root -p < setup_mysql_remote.sql

-- 1. 創建或更新 mmuser 允許遠端連線
DROP USER IF EXISTS 'mmuser'@'%';
CREATE USER 'mmuser'@'%' IDENTIFIED BY 'mmpass';

-- 2. 授予 mmuser 對 mattermost_dev 資料庫的完整權限
GRANT ALL PRIVILEGES ON mattermost_dev.* TO 'mmuser'@'%';

-- 3. 如果還沒有資料庫，創建它
CREATE DATABASE IF NOT EXISTS mattermost_dev 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

-- 4. 確保權限生效
FLUSH PRIVILEGES;

-- 5. 顯示創建的用戶
SELECT User, Host FROM mysql.user WHERE User = 'mmuser';

-- 6. 顯示授予的權限
SHOW GRANTS FOR 'mmuser'@'%';

-- 7. 顯示資料庫
SHOW DATABASES LIKE 'mattermost%';

-- 完成提示
SELECT 'MySQL 遠端連線設定完成！' as Status;