# Slack Webhook 設定指南

## 如何取得 Slack Webhook URL

### 方法 1：使用 Incoming Webhooks（推薦，最簡單）

1. **前往 Slack App 目錄**
   - 訪問：https://api.slack.com/apps
   - 點擊 "Create New App"

2. **建立 App**
   - 選擇 "From scratch"
   - App Name: `Migration Notifier`
   - 選擇你的 Workspace

3. **啟用 Incoming Webhooks**
   - 在左側選單點擊 "Incoming Webhooks"
   - 開啟 "Activate Incoming Webhooks" 開關

4. **新增 Webhook**
   - 點擊 "Add New Webhook to Workspace"
   - 選擇要發送通知的頻道（例如 #general 或 #devops）
   - 點擊 "Allow"

5. **複製 Webhook URL**
   - 會看到類似這樣的 URL：
     ```
     https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX
     ```
   - 複製這個 URL

6. **測試 Webhook**
   ```bash
   curl -X POST YOUR_WEBHOOK_URL \
     -H 'Content-Type: application/json' \
     -d '{"text":"測試通知"}'
   ```

### 方法 2：使用現有的 Mattermost Webhook（如果你的 Slack 是 Mattermost）

如果你的「Slack」其實是 Mattermost：

1. 登入 Mattermost
2. 點擊左上角頻道選單 → 整合 (Integrations)
3. 選擇「傳入 Webhook」(Incoming Webhooks)
4. 點擊「新增傳入 Webhook」
5. 選擇頻道並儲存
6. 複製產生的 Webhook URL

## 設定腳本

編輯 `migrate_posts_remote.sh`，將以下兩行替換成實際值：

```bash
MYSQL_PASS="YOUR_MYSQL_ROOT_PASSWORD"  # 替換成 MySQL root 密碼
SLACK_WEBHOOK="YOUR_SLACK_WEBHOOK_URL" # 替換成上面取得的 Webhook URL
```

## 使用說明

### 執行 Migration（背景執行）

```bash
# 1. 給予執行權限
chmod +x /Users/chang/current/zacmm2025/scripts/migrate_posts_remote.sh

# 2. 背景執行（會自動通知 Slack）
nohup /Users/chang/current/zacmm2025/scripts/migrate_posts_remote.sh > /tmp/migration.log 2>&1 &

# 3. 記下進程 ID
echo $!
```

### 監控進度

```bash
# 方法 1：使用監控腳本
chmod +x /Users/chang/current/zacmm2025/scripts/monitor_migration.sh
./monitor_migration.sh

# 方法 2：查看日誌
tail -f /tmp/alter_posts_*.log

# 方法 3：查看執行輸出
tail -f /tmp/migration.log
```

## Slack 通知範例

腳本會發送三種通知：

1. **開始通知**
   ```
   🚀 開始執行 ALTER TABLE Posts migration
   資料庫: mattermost_prod_local
   主機: 34.87.11.83
   開始時間: 2025-10-21 14:30:00
   ```

2. **成功通知**
   ```
   ✅ ALTER TABLE Posts migration 執行成功！
   資料庫: mattermost_prod_local
   總耗時: 45 分鐘
   完成時間: 2025-10-21 15:15:00
   ```

3. **失敗通知**
   ```
   ❌ ALTER TABLE Posts migration 執行失敗！
   資料庫: mattermost_prod_local
   失敗時間: 2025-10-21 14:35:00
   日誌: 請查看 /tmp/alter_posts_20251021_143000.log
   ```

## 不使用 Slack 通知

如果不想使用 Slack 通知，只需保持 `SLACK_WEBHOOK="YOUR_SLACK_WEBHOOK_URL"` 不變即可。
腳本會跳過 Slack 通知，但仍會記錄到日誌檔。
