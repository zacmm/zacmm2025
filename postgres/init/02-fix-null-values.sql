-- 修復 NULL 值問題的初始化腳本
-- 這個腳本會在 PostgreSQL 容器啟動時自動執行

-- 確保所有計數欄位都有預設值 0
DO $$
BEGIN
    -- 檢查並更新 Channels 表
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'channels' 
               AND column_name = 'totalmsgcountroot') THEN
        
        UPDATE channels SET totalmsgcountroot = 0 WHERE totalmsgcountroot IS NULL;
        UPDATE channels SET totalmsgcount = 0 WHERE totalmsgcount IS NULL;
        
        ALTER TABLE channels ALTER COLUMN totalmsgcountroot SET DEFAULT 0;
        ALTER TABLE channels ALTER COLUMN totalmsgcount SET DEFAULT 0;
    END IF;
    
    -- 檢查並更新 ChannelMembers 表
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'channelmembers' 
               AND column_name = 'msgcountroot') THEN
        
        UPDATE channelmembers SET msgcountroot = 0 WHERE msgcountroot IS NULL;
        UPDATE channelmembers SET msgcount = 0 WHERE msgcount IS NULL;
        UPDATE channelmembers SET mentioncount = 0 WHERE mentioncount IS NULL;
        UPDATE channelmembers SET mentioncountroot = 0 WHERE mentioncountroot IS NULL;
        UPDATE channelmembers SET urgentmentioncount = 0 WHERE urgentmentioncount IS NULL;
        
        ALTER TABLE channelmembers ALTER COLUMN msgcountroot SET DEFAULT 0;
        ALTER TABLE channelmembers ALTER COLUMN msgcount SET DEFAULT 0;
        ALTER TABLE channelmembers ALTER COLUMN mentioncount SET DEFAULT 0;
        ALTER TABLE channelmembers ALTER COLUMN mentioncountroot SET DEFAULT 0;
        ALTER TABLE channelmembers ALTER COLUMN urgentmentioncount SET DEFAULT 0;
    END IF;
END $$;