# Migration 重複執行問題處理指南

## 問題描述

在某些情況下，Mattermost 的 migration 可能需要重複執行，但官方的 migration 檔案在重複執行時會因為 Stored Procedure 已存在而失敗。

### 典型錯誤訊息

```
Error 1304: PROCEDURE MigrateRootId_Posts already exists
```

## 何時會遇到此問題

1. **Migration 執行失敗後重試**
   - Migration 在中途失敗，但 Stored Procedure 已經建立
   - 需要重新執行 migration 來修復問題

2. **測試和開發環境**
   - 反覆測試 migration 腳本
   - 回滾並重新執行 migration

3. **資料庫同步問題**
   - 從生產環境匯入資料後，migration 狀態不一致
   - 需要手動重新執行特定 migration

## 官方 Migration 檔案模式

官方的 migration 檔案遵循以下模式：

```sql
CREATE PROCEDURE MigrateRootId_Posts ()
BEGIN
    -- Migration 邏輯
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- 錯誤處理
    END;

    -- 實際的資料處理邏輯
END;

CALL MigrateRootId_Posts();

DROP PROCEDURE IF EXISTS MigrateRootId_Posts;
```

### 此模式的問題

- `CREATE PROCEDURE` 會在 procedure 已存在時失敗
- 即使最後有 `DROP PROCEDURE IF EXISTS`，但在 CREATE 時就已經報錯
- Migration 框架會認為此 migration 失敗

## 解決方案：防禦性模式

### 修改方式

在 `CREATE PROCEDURE` 之前加上 `DROP PROCEDURE IF EXISTS`：

```sql
-- 加入這一行
DROP PROCEDURE IF EXISTS MigrateRootId_Posts;

CREATE PROCEDURE MigrateRootId_Posts ()
BEGIN
    -- Migration 邏輯
END;

CALL MigrateRootId_Posts();

DROP PROCEDURE IF EXISTS MigrateRootId_Posts;
```

### 適用的 Migration 檔案

以下 migration 檔案包含 Stored Procedure，可能需要此修改：

1. `000012_create_commands.up.sql`
2. `000013_create_incoming_webhooks.up.sql`
3. `000016_create_reactions.up.sql`
4. `000017_create_roles.up.sql`
5. `000022_create_sessions.up.sql`
6. `000026_create_preferences.up.sql`
7. `000041_create_upload_sessions.up.sql`
8. `000042_create_threads.up.sql`
9. `000044_create_user_terms_of_service.up.sql`
10. `000046_create_users.up.sql`
11. `000051_create_msg_root_count.up.sql`
12. `000052_create_public_channels.up.sql`
13. `000054_create_crt_channelmembership_count.up.sql`
14. `000055_create_crt_thread_count_and_unreads.up.sql`
15. `000057_upgrade_command_webhooks_v6.0.up.sql`
16. `000066_upgrade_posts_v6.0.up.sql`
17. `000070_upgrade_cte_v6.1.up.sql`
18. `000075_alter_upload_sessions_index.up.sql`
19. `000076_upgrade_lastrootpostat.up.sql`
20. `000123_remove_upload_file_permission.up.sql`
21. `000124_remove_manage_team_permission.up.sql`

## 使用時機指南

### ✅ 建議使用防禦性模式的情況

- 開發和測試環境
- 需要手動重新執行 migration
- Migration 執行失敗後需要修復
- 從生產環境匯入資料後發現 migration 狀態不一致

### ❌ 不建議使用的情況

- 生產環境的正常 migration
- 全新安裝的 Mattermost
- 需要保持與官方版本一致的代碼庫

## 實作步驟

### 1. 備份 Migration 檔案

```bash
# 建立備份
cp -r channels/db/migrations/mysql channels/db/migrations/mysql.backup
```

### 2. 批次修改（使用腳本）

建立一個臨時腳本 `fix_migrations.sh`：

```bash
#!/bin/bash

# 在 server 目錄下執行此腳本

cd channels/db/migrations/mysql

# 處理每個包含 CREATE PROCEDURE 的 migration 檔案
for file in *.up.sql; do
    # 檢查檔案是否包含 CREATE PROCEDURE
    if grep -q "CREATE PROCEDURE" "$file"; then
        echo "處理: $file"

        # 提取所有 procedure 名稱
        grep "CREATE PROCEDURE" "$file" | sed 's/CREATE PROCEDURE \([^ ]*\) .*/\1/' | while read proc_name; do
            # 在 CREATE PROCEDURE 前加上 DROP PROCEDURE IF EXISTS
            sed -i.bak "/CREATE PROCEDURE $proc_name/i\\
DROP PROCEDURE IF EXISTS $proc_name;\\
" "$file"
        done

        # 刪除備份檔案
        rm -f "$file.bak"
    fi
done

echo "完成！"
```

### 3. 手動修改單一檔案

如果只需要修改特定檔案：

```bash
# 編輯檔案
vim channels/db/migrations/mysql/000051_create_msg_root_count.up.sql

# 在每個 CREATE PROCEDURE 前加上對應的 DROP PROCEDURE IF EXISTS
```

### 4. 驗證修改

```bash
# 檢查修改的檔案
git diff channels/db/migrations/mysql/

# 測試執行 migration
mysql -h <host> -u <user> -p <database> < channels/db/migrations/mysql/000051_create_msg_root_count.up.sql
```

## 還原到官方版本

當不再需要防禦性模式時，還原到官方版本：

```bash
# 還原所有 migration 檔案
git checkout -- channels/db/migrations/mysql/*.up.sql

# 驗證還原
git status
```

## 最佳實踐

1. **保持版本控制分離**
   - 不要將修改後的 migration 檔案提交到主分支
   - 使用獨立的分支或標籤管理修改後的版本

2. **文檔記錄**
   - 記錄為什麼需要修改 migration
   - 記錄修改的日期和原因

3. **定期同步官方版本**
   - 定期檢查官方 Mattermost 的 migration 更新
   - 在生產環境保持與官方一致

4. **測試優先**
   - 在測試環境先驗證修改後的 migration
   - 確保修改不影響資料完整性

## 注意事項

⚠️ **重要警告**

- 此修改僅適用於需要重複執行 migration 的特殊情況
- 生產環境建議保持與官方版本一致
- 修改 migration 檔案可能影響未來的升級
- 執行前務必備份資料庫

## 相關資源

- [Mattermost Migration 官方文檔](https://docs.mattermost.com)
- [資料庫修復指南](./DATABASE_FIXES.md)
- [批次刪除訊息指南](./batch_delete_posts.sql)

## 版本記錄

- 2025-10-29: 初始版本，記錄 DROP PROCEDURE IF EXISTS 模式
