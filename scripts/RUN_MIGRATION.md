# ALTER TABLE 執行指南

## 方法 1：在遠端主機上直接執行（推薦，最快）

### 步驟 1：上傳腳本到遠端

```bash
# 從本地上傳腳本到遠端
scp /Users/chang/current/zacmm2025/scripts/run_alter_table.sh root@34.87.11.83:/tmp/
```

### 步驟 2：SSH 到遠端並執行

```bash
# 連接到遠端主機
ssh root@34.87.11.83

# 執行腳本（背景執行）
nohup bash /tmp/run_alter_table.sh > /tmp/alter_posts.log 2>&1 &

# 記下進程 ID
echo $!

# 監控進度
tail -f /tmp/alter_posts.log

# 或使用 watch 監控資料庫進程
watch -n 30 'mysql -e "SHOW PROCESSLIST" | grep -i alter'
```

### 步驟 3：完成後回到本地

完成後會自動發送 Slack 通知到 #網站監控

---

## 方法 2：從本地透過 SSH 執行

```bash
# 一行命令執行（會等待完成）
ssh root@34.87.11.83 'bash -s' < /Users/chang/current/zacmm2025/scripts/run_alter_table.sh
```

---

## 方法 3：讓 Mattermost 自動執行 migration

如果上面的方法都有問題，最簡單的方式是：

```bash
# 回到本地，直接啟動 Mattermost
cd /Users/chang/current/zacmm2025/server
make run-server

# Mattermost 會自動檢測並執行所有缺少的 migrations
# 缺點：會比較慢（因為是透過網路執行）
```

---

## 監控進度（在遠端主機上）

### 查看 MySQL 進程
```bash
watch -n 30 "mysql -e \"SELECT ID, TIME, ROUND(TIME/60,1) as min, STATE FROM information_schema.PROCESSLIST WHERE INFO LIKE '%ALTER%';\""
```

### 查看臨時表檔案大小
```bash
watch -n 10 "ls -lh /var/lib/mysql/mattermost_prod_local/#sql* 2>/dev/null || echo 'No temp files'"
```

### 查看日誌
```bash
tail -f /tmp/alter_posts.log
```

---

## 預期執行時間

- **在遠端主機執行**：30-60 分鐘（本地速度快）
- **從本地 Mac 執行**：5-6 小時（網路延遲）

---

## 完成後的驗證

```bash
# 檢查欄位是否已新增
mysql mattermost_prod_local -e "SHOW COLUMNS FROM Posts LIKE 'RemoteId';"

# 應該會看到：
# Field     | Type        | Null | Key | Default | Extra
# RemoteId  | varchar(26) | YES  |     | NULL    |
```

---

## 如果遇到問題

### 問題 1：權限不足
確保使用 root 帳號連接到遠端主機

### 問題 2：已存在 RemoteId 欄位
```bash
# 先刪除（如果需要重新執行）
mysql mattermost_prod_local -e "ALTER TABLE Posts DROP COLUMN RemoteId;"
```

### 問題 3：中斷後重新執行
直接重新執行腳本即可，MySQL 會從頭開始
