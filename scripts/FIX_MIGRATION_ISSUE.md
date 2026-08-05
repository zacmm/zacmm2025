# Migration 問題修復指南

## 問題描述

Mattermost 啟動時遇到錯誤：
```
Error 1304 (42000): PROCEDURE RenameSolarizedThemeWithUnderscore already exists
```

這是因為 migration 腳本會創建這個 stored procedure，但執行失敗後沒有自動清理。

## 解決方案

### 方案 1：手動標記 migration 為已完成（推薦）

在遠端資料庫執行：

```sql
-- 1. 查看目前的 migration 版本
SELECT * FROM db_migrations ORDER BY Version DESC LIMIT 5;

-- 2. 查找 create_preferences 這個 migration 的版本號
SELECT * FROM db_migrations WHERE Name LIKE '%preferences%';

-- 3. 如果沒有 create_preferences 的記錄，手動插入
-- 注意：這個版本號可能不同，需要確認實際的版本號
INSERT INTO db_migrations (Version, Name)
VALUES (92, 'create_preferences');

-- 4. 刪除殘留的 procedure
DROP PROCEDURE IF EXISTS RenameSolarizedThemeWithUnderscore;
```

### 方案 2：重新建立乾淨的資料庫

如果上面方法不行，考慮：
1. 建立新的資料庫 `mattermost_prod_local_clean`
2. 重新匯入備份
3. 使用新的資料庫

### 方案 3：跳過有問題的 migration

修改 migration 腳本（不推薦，僅供參考）

## 當前狀態

- 資料庫已清理完成（Posts 和 FileInfo 超過一年的資料）
- Migration 卡在 create_preferences 這一步
- 需要手動介入修復

## 下一步

1. 在遠端資料庫執行方案 1 的 SQL
2. 重新啟動本地 Mattermost 服務
3. 驗證服務是否正常啟動
