# 資料庫錯誤修復指南

## 🔴 錯誤描述

您遇到了兩個問題：

1. **前端警告**: `lastViewedAt` prop 缺失
2. **後端錯誤**: SQL NULL 值轉換錯誤

```
"converting NULL to int64 is unsupported"
```

## ✅ 已完成的修復

### 1. 修改 SQL 查詢處理 NULL 值

修改了 `/server/channels/store/sqlstore/team_store.go` 中的查詢，使用 `COALESCE` 函數處理 NULL 值：

```go
// 原本的查詢
"(Channels.TotalMsgCountRoot - ChannelMembers.MsgCountRoot) MsgCountRoot"

// 修改後的查詢
"(COALESCE(Channels.TotalMsgCountRoot, 0) - COALESCE(ChannelMembers.MsgCountRoot, 0)) MsgCountRoot"
```

### 2. 創建資料庫修復腳本

創建了兩個 SQL 腳本來修復現有資料：

- `fix_database_null.sql` - 手動執行的修復腳本
- `postgres/init/02-fix-null-values.sql` - Docker 自動初始化腳本

## 🚀 應用修復方案

### 方案 A: 重新編譯並重啟服務

```bash
# 1. 停止現有服務
docker-compose down

# 2. 重新建置包含修復的映像
docker-compose build --no-cache mattermost

# 3. 啟動服務
docker-compose up -d

# 4. 檢查日誌確認沒有錯誤
docker-compose logs -f mattermost
```

### 方案 B: 手動修復現有資料庫

如果您有現有的資料需要保留：

```bash
# 1. 進入 PostgreSQL 容器
docker-compose exec postgres psql -U mmuser -d mattermost

# 2. 執行修復 SQL
\i /docker-entrypoint-initdb.d/02-fix-null-values.sql

# 3. 驗證修復
SELECT COUNT(*) FROM channelmembers WHERE msgcountroot IS NULL;
-- 應該返回 0

# 4. 退出
\q

# 5. 重啟 Mattermost 服務
docker-compose restart mattermost
```

### 方案 C: 本地開發環境

如果您在本地開發環境：

```bash
# 1. 重新編譯後端
cd server
make build

# 2. 如果使用 LocalMode，刪除舊資料重新開始
rm -rf data/

# 3. 重新啟動服務
make run-server
```

## 🔍 驗證修復

修復後，您應該：

1. ✅ 不再看到 SQL NULL 轉換錯誤
2. ✅ 團隊未讀訊息計數正常顯示
3. ✅ 頻道切換正常運作

## 📝 預防措施

為了防止未來出現類似問題：

1. **資料庫約束**: 已添加 DEFAULT 0 約束到所有計數欄位
2. **查詢保護**: 使用 COALESCE 函數處理可能的 NULL 值
3. **初始化腳本**: 新部署會自動執行修復腳本

## ⚠️ 注意事項

- 前端的 `lastViewedAt` 警告是非致命的，不影響基本功能
- 如果問題持續，可能需要清除瀏覽器快取
- 確保所有容器都使用最新的程式碼版本