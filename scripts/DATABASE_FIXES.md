# 資料庫修復記錄

## 修復日期
2025-10-26

## 問題描述
從生產環境同步資料到本地後，發現以下問題：
1. 字符集校對規則不一致導致 JOIN 查詢失敗
2. 多個表的欄位存在 NULL 值，導致資料掃描錯誤
3. SidebarChannels 側邊欄頻道配置資料缺失，導致用戶無法看到頻道列表

## 修復內容

### 1. 資料庫預設校對規則修改

**問題**：資料庫預設校對規則為 `utf8mb4_unicode_ci`，但大部分表使用 `utf8mb4_0900_ai_ci`，導致 JOIN 和比較操作失敗。

**修復**：
```sql
ALTER DATABASE mattermost_prod_local CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
```

**影響**：解決了以下錯誤：
```
Error 1267 (HY000): Illegal mix of collations (utf8mb4_unicode_ci,IMPLICIT) and (utf8mb4_0900_ai_ci,IMPLICIT) for operation '='
```

---

### 2. 欄位校對規則統一修改

**問題**：部分表的 ID 相關欄位使用 `utf8mb4_unicode_ci`，與主表不一致。

**修復的表和欄位**：

| 表名 | 欄位 | 原校對規則 | 新校對規則 | 資料類型 |
|------|------|-----------|-----------|---------|
| AccessControlPolicies | ID | utf8mb4_unicode_ci | utf8mb4_0900_ai_ci | varchar(255) |
| AccessControlPolicyHistory | ID | utf8mb4_unicode_ci | utf8mb4_0900_ai_ci | varchar(255) |
| DesktopTokens | UserId | utf8mb4_unicode_ci | utf8mb4_0900_ai_ci | varchar(26) |
| NotifyAdmin | UserId | utf8mb4_unicode_ci | utf8mb4_0900_ai_ci | varchar(26) |
| PersistentNotifications | PostId | utf8mb4_unicode_ci | utf8mb4_0900_ai_ci | varchar(26) |
| PostReminders | PostId | utf8mb4_unicode_ci | utf8mb4_0900_ai_ci | varchar(26) |
| PostReminders | UserId | utf8mb4_unicode_ci | utf8mb4_0900_ai_ci | varchar(26) |
| PropertyFields | ID | utf8mb4_unicode_ci | utf8mb4_0900_ai_ci | varchar(255) |
| PropertyGroups | ID | utf8mb4_unicode_ci | utf8mb4_0900_ai_ci | varchar(255) |
| PropertyValues | ID | utf8mb4_unicode_ci | utf8mb4_0900_ai_ci | varchar(255) |
| RecentSearches | UserId | utf8mb4_unicode_ci | utf8mb4_0900_ai_ci | varchar(26) |
| ScheduledPosts | id | utf8mb4_unicode_ci | utf8mb4_0900_ai_ci | varchar(26) |
| ScheduledPosts | userid | utf8mb4_unicode_ci | utf8mb4_0900_ai_ci | varchar(26) |
| ScheduledPosts | channelid | utf8mb4_unicode_ci | utf8mb4_0900_ai_ci | varchar(26) |

---

### 3. NULL 值修復

**問題**：部分欄位存在 NULL 值，導致資料掃描時轉換失敗。

#### 3.1 Channels 表

| 欄位 | 修復的 NULL 值數量 | 預設值 |
|------|------------------|--------|
| TotalMsgCountRoot | 4,163 | 0 |

**錯誤訊息**：
```
sql: Scan error on column index 17, name "TotalMsgCountRoot": converting NULL to int64 is unsupported
```

#### 3.2 ChannelMembers 表

| 欄位 | 修復的 NULL 值數量 | 預設值 |
|------|------------------|--------|
| MentionCountRoot | 2,875 | 0 |
| MsgCountRoot | 10,620 | 0 |

**錯誤訊息**：
```
sql: Scan error on column index 6, name "MentionCountRoot": converting NULL to int64 is unsupported
sql: Scan error on column index 8, name "MsgCountRoot": converting NULL to int64 is unsupported
```

#### 3.3 SidebarCategories 表

| 欄位 | 修復的 NULL 值數量 | 預設值 |
|------|------------------|--------|
| Collapsed | 903 | 0 |

**錯誤訊息**：
```
sql: Scan error on column index 8, name "Collapsed": sql/driver: couldn't convert <nil> (<nil>) into type bool
```

**影響**：用戶側邊欄分類資料無法載入，導致頻道列表無法顯示。

---

### 4. SidebarChannels 側邊欄頻道配置修復

**問題**：部分用戶的頻道成員資格（ChannelMembers）存在，但缺少側邊欄配置（SidebarChannels），導致頻道不顯示在側邊欄。

**受影響範圍**：
- 受影響用戶：99 人
- 缺失頻道總數：298 個
- 平均每人缺失：3 個頻道
- 最多缺失：25 個頻道（用戶 tomwu788）

**根本原因**：
- SidebarChannels 的資料是由應用程式在運行時動態建立，不是透過 migration 填充
- 從生產環境同步資料時，如果 SidebarChannels 表的資料不完整或未同步，就會造成此問題
- 這是**資料完整性問題**，不是程式邏輯問題

**症狀**：
- 用戶登入後側邊欄不顯示頻道列表
- 即使用戶是頻道成員，頻道也不會出現在側邊欄
- 資料庫中 `ChannelMembers` 有記錄，但 `SidebarChannels` 缺少對應記錄

**修復內容**：
```sql
-- 將所有缺少側邊欄配置的頻道加入到對應團隊的 Channels 分類中
INSERT INTO SidebarChannels (ChannelId, UserId, CategoryId, SortOrder)
SELECT
    cm.ChannelId,
    cm.UserId,
    CONCAT('channels_', cm.UserId, '_', c.TeamId) AS CategoryId,
    0 AS SortOrder
FROM ChannelMembers cm
JOIN Channels c ON cm.ChannelId = c.Id
JOIN Users u ON cm.UserId = u.Id
WHERE u.DeleteAt = 0
  AND c.Type IN ('O', 'P')
  AND NOT EXISTS (
      SELECT 1 FROM SidebarChannels sc
      JOIN SidebarCategories cat ON sc.CategoryId = cat.Id
      WHERE sc.ChannelId = cm.ChannelId AND cat.UserId = cm.UserId
  )
  AND EXISTS (
      SELECT 1 FROM SidebarCategories cat
      WHERE cat.Id = CONCAT('channels_', cm.UserId, '_', c.TeamId)
  );
```

**修復的表**：
- `SidebarChannels` - 補充缺失的頻道配置記錄

---

## 修復結果

### 已解決的問題
1. ✅ 字符集校對規則衝突錯誤完全解決
2. ✅ 所有團隊和頻道可以正常訪問
3. ✅ 頻道成員資料可以正常讀取
4. ✅ API 請求全部返回 200 狀態碼
5. ✅ 側邊欄頻道配置缺失問題已修復（99 個用戶，298 個頻道）
6. ✅ 用戶可以正常看到所有頻道列表

### 受影響的功能
- 團隊列表顯示
- 頻道列表顯示
- 頻道成員資訊
- 訊息計數統計
- 側邊欄頻道分類和排序

---

## 建議

### 1. 預防措施
- 在匯入生產資料前，先執行修復 SQL 腳本
- 定期檢查資料庫校對規則一致性
- 在資料遷移後執行完整性檢查
- 同步生產資料時，確保包含以下表的完整資料：
  - `SidebarChannels` - 側邊欄頻道配置
  - `SidebarCategories` - 側邊欄分類配置
  - `Preferences` - 用戶偏好設定

### 2. 長期解決方案
- 修復生產環境的 migration 腳本，確保新建表使用正確的校對規則
- 為 NOT NULL 欄位添加預設值約束
- 建立資料完整性檢查腳本

### 3. 相關 Migration 文件
以下 migration 文件可能需要檢查或修復：
- `000052_create_public_channels.up.sql`
- `000042_create_threads.up.sql`
- `000051_create_msg_root_count.up.sql`
- `000054_create_crt_channelmembership_count.up.sql`
- `000055_create_crt_thread_count_and_unreads.up.sql`

---

## 執行方式

```bash
# 1. 匯入資料後執行修復腳本
mysql -h <host> -u <user> -p <database> < scripts/fix_database_issues.sql

# 2. 驗證修復結果
mysql -h <host> -u <user> -p <database> < scripts/verify_database_fixes.sql
```

---

## 附註

此修復記錄對應的 SQL 腳本：
- `scripts/fix_database_issues.sql` - 主要修復腳本
- `scripts/verify_database_fixes.sql` - 驗證腳本
