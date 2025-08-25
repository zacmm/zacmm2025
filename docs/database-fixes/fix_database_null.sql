-- 修復資料庫 NULL 值問題
-- 這個腳本會更新所有 NULL 的計數欄位為 0

-- 更新 Channels 表中的 NULL 值
UPDATE Channels 
SET TotalMsgCountRoot = 0 
WHERE TotalMsgCountRoot IS NULL;

UPDATE Channels 
SET TotalMsgCount = 0 
WHERE TotalMsgCount IS NULL;

-- 更新 ChannelMembers 表中的 NULL 值
UPDATE ChannelMembers 
SET MsgCountRoot = 0 
WHERE MsgCountRoot IS NULL;

UPDATE ChannelMembers 
SET MsgCount = 0 
WHERE MsgCount IS NULL;

UPDATE ChannelMembers 
SET MentionCount = 0 
WHERE MentionCount IS NULL;

UPDATE ChannelMembers 
SET MentionCountRoot = 0 
WHERE MentionCountRoot IS NULL;

UPDATE ChannelMembers 
SET UrgentMentionCount = 0 
WHERE UrgentMentionCount IS NULL;

-- 添加預設值約束以防止未來的 NULL 值
-- PostgreSQL 語法
ALTER TABLE Channels 
ALTER COLUMN TotalMsgCountRoot SET DEFAULT 0;

ALTER TABLE Channels 
ALTER COLUMN TotalMsgCount SET DEFAULT 0;

ALTER TABLE ChannelMembers 
ALTER COLUMN MsgCountRoot SET DEFAULT 0;

ALTER TABLE ChannelMembers 
ALTER COLUMN MsgCount SET DEFAULT 0;

ALTER TABLE ChannelMembers 
ALTER COLUMN MentionCount SET DEFAULT 0;

ALTER TABLE ChannelMembers 
ALTER COLUMN MentionCountRoot SET DEFAULT 0;

ALTER TABLE ChannelMembers 
ALTER COLUMN UrgentMentionCount SET DEFAULT 0;