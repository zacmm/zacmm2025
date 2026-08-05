-- 檢查資料庫鎖狀態

-- 1. 檢查 db_lock 表
SELECT * FROM db_lock;

-- 2. 如果有過期的鎖，刪除它
-- DELETE FROM db_lock WHERE ExpiresAt < UNIX_TIMESTAMP() * 1000;

-- 3. 如果需要強制釋放鎖（謹慎使用）
-- DELETE FROM db_lock;

-- 4. 檢查當前活躍的 MySQL 連接
SHOW PROCESSLIST;
