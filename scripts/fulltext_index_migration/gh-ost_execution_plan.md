# gh-ost 零停機索引重建執行計畫

## 📊 環境資訊

```
資料庫主機: 34.87.11.83
使用者: mmuser
密碼: mmpass
資料庫: mattermost_prod_local
表名: Posts
資料筆數: 1,813,704 筆
表大小: 1.66 GB
MySQL 版本: 8.0.43
Binlog: 已啟用 (ROW 格式) ✅
```

## ⏰ 時間規劃

```
預估總執行時間: 4-6 小時
建議執行時間: 週末或低峰時段
可以在白天執行: 是（零停機）
```

---

## 🚀 執行步驟

### Phase 1: 準備階段（30分鐘）

#### 1.1 備份資料庫 ⚠️ 必做！

```bash
# 在有權限連接資料庫的機器上執行
mysqldump -h 34.87.11.83 -u mmuser -p'mmpass' \
  --single-transaction \
  --routines \
  --triggers \
  --events \
  mattermost_prod_local > backup_$(date +%Y%m%d_%H%M%S).sql

# 確認備份檔案
ls -lh backup_*.sql

# 壓縮備份（節省空間）
gzip backup_*.sql
```

**預期結果**: 產生約 500-800MB 的備份檔案

#### 1.2 檢查磁碟空間

```bash
# 檢查資料庫伺服器磁碟空間
ssh user@34.87.11.83  # 需要替換為實際的 SSH 使用者
df -h | grep -E "Size|/$"

# 需要至少 3.5 GB 可用空間
# 如果空間不足，需要先清理
```

#### 1.3 安裝 gh-ost

**在可以連接資料庫的機器上安裝**（通常是應用伺服器）：

```bash
# 下載 gh-ost (檢查最新版本: https://github.com/github/gh-ost/releases)
cd /tmp
wget https://github.com/github/gh-ost/releases/download/v1.1.6/gh-ost-binary-linux-amd64-20231207144046.tar.gz

# 解壓縮
tar -xzf gh-ost-binary-linux-amd64-20231207144046.tar.gz

# 安裝到系統路徑
sudo mv gh-ost /usr/local/bin/
sudo chmod +x /usr/local/bin/gh-ost

# 驗證安裝
gh-ost --version
```

**預期輸出**: `1.1.6` 或更新版本

---

### Phase 2: MySQL 配置修改（需重啟）⚠️

這步驟需要在**低峰時段**執行，因為需要重啟 MySQL。

#### 2.1 修改 MySQL 配置

**找到 MySQL 配置檔案**:
```bash
# SSH 到資料庫伺服器
ssh user@34.87.11.83

# 找到配置檔案位置
mysql --help | grep "Default options" -A 1

# 常見位置:
# /etc/mysql/mysql.conf.d/mysqld.cnf
# /etc/my.cnf
# /etc/mysql/my.cnf
```

**編輯配置檔案**:
```bash
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
```

**在 [mysqld] 區段加入或修改**:
```ini
[mysqld]
# Fulltext 設定
innodb_ft_min_token_size = 1
innodb_ft_max_token_size = 84

# 確保 binlog 正確設定（通常已有）
log_bin = ON
binlog_format = ROW
```

**儲存後重啟 MySQL**:
```bash
# 重啟 MySQL
sudo systemctl restart mysql

# 等待 MySQL 啟動（約 10-30 秒）
sudo systemctl status mysql

# 驗證設定
mysql -h 34.87.11.83 -u mmuser -p'mmpass' -e "
SELECT
    @@innodb_ft_min_token_size as min_token_size,
    @@log_bin as binlog_enabled,
    @@binlog_format as binlog_format;
"
```

**預期輸出**:
```
min_token_size: 1 ✅
binlog_enabled: 1 ✅
binlog_format: ROW ✅
```

---

### Phase 3: 執行 gh-ost（4-6 小時）🚀

#### 3.1 準備監控終端

**開啟 3 個終端視窗**:

**終端 1 - 執行 gh-ost（主終端）**
**終端 2 - 監控進度**
**終端 3 - 監控 MySQL**

#### 3.2 執行 gh-ost（終端 1）

```bash
# 使用 screen 或 tmux 避免斷線
screen -S gh-ost-migration

# 執行 gh-ost
gh-ost \
  --host=34.87.11.83 \
  --port=3306 \
  --user=mmuser \
  --password=mmpass \
  --database=mattermost_prod_local \
  --table=Posts \
  --alter="DROP INDEX idx_posts_message_txt, ADD FULLTEXT INDEX idx_posts_message_txt (Message)" \
  --allow-on-master \
  --initially-drop-ghost-table \
  --initially-drop-old-table \
  --assume-rbr \
  --chunk-size=1000 \
  --max-load=Threads_running=50 \
  --critical-load=Threads_running=100 \
  --default-retries=120 \
  --serve-socket-file=/tmp/gh-ost.sock \
  --postpone-cut-over-flag-file=/tmp/ghost.postpone \
  --panic-flag-file=/tmp/ghost.panic \
  --exact-rowcount \
  --verbose \
  --execute

# 按 Ctrl+A 然後 D 來分離 screen（不中斷執行）
# 重新連接: screen -r gh-ost-migration
```

**參數說明**:
- `--chunk-size=1000`: 每次處理 1000 行（可根據系統負載調整）
- `--max-load`: 當 MySQL 執行緒超過 50 時暫停
- `--critical-load`: 執行緒超過 100 時緊急暫停
- `--serve-socket-file`: 提供互動控制介面
- `--postpone-cut-over-flag-file`: 可手動控制最後切換時機
- `--panic-flag-file`: 緊急停止開關

#### 3.3 監控進度（終端 2）

```bash
# 方式 1: 透過 socket 查看即時狀態
watch -n 5 'echo "status" | nc -U /tmp/gh-ost.sock 2>/dev/null'

# 方式 2: 查看 gh-ost 輸出
tail -f /tmp/gh-ost.log  # 如果有設定日誌檔案

# 方式 3: 檢查 ghost table 大小
watch -n 30 'mysql -h 34.87.11.83 -u mmuser -p"mmpass" mattermost_prod_local -e "
SELECT
    table_name,
    ROUND(data_length/1024/1024, 2) as data_mb,
    table_rows
FROM information_schema.tables
WHERE table_schema=\"mattermost_prod_local\"
  AND table_name LIKE \"%_gho\"
" 2>/dev/null'
```

#### 3.4 監控 MySQL（終端 3）

```bash
# 監控 MySQL 負載
watch -n 5 'mysql -h 34.87.11.83 -u mmuser -p"mmpass" -e "
SHOW PROCESSLIST;
SELECT
    COUNT(*) as active_threads,
    SUM(IF(command=\"Sleep\", 1, 0)) as sleeping
FROM information_schema.processlist;
" 2>/dev/null'
```

#### 3.5 互動控制命令

**暫停執行**:
```bash
echo "throttle" | nc -U /tmp/gh-ost.sock
```

**恢復執行**:
```bash
echo "no-throttle" | nc -U /tmp/gh-ost.sock
```

**查看 ETA（預估剩餘時間）**:
```bash
echo "status" | nc -U /tmp/gh-ost.sock | grep -i eta
```

**調整 chunk size**（執行中調整）:
```bash
echo "chunk-size=500" | nc -U /tmp/gh-ost.sock  # 減少負載
echo "chunk-size=2000" | nc -U /tmp/gh-ost.sock # 加快速度
```

**緊急暫停**（如果出現問題）:
```bash
touch /tmp/ghost.panic
# gh-ost 會立即暫停，不會切換表
```

**取消緊急暫停**:
```bash
rm /tmp/ghost.panic
```

---

### Phase 4: 最後切換（1分鐘）

#### 4.1 準備切換

gh-ost 會在複製完成後等待最後確認（因為有 `--postpone-cut-over-flag-file`）。

**查看狀態**:
```bash
echo "status" | nc -U /tmp/gh-ost.sock
```

當看到類似訊息:
```
Waiting for 'postpone-cut-over-flag-file' to be removed
```

**確認準備完成後，允許切換**:
```bash
rm /tmp/ghost.postpone
```

gh-ost 會在 1 秒內完成原子性切換。

#### 4.2 驗證切換完成

```bash
# 檢查 gh-ost 執行結果
# 應該看到 "Migration completed successfully"

# 驗證索引存在
mysql -h 34.87.11.83 -u mmuser -p'mmpass' mattermost_prod_local -e "
SHOW INDEX FROM Posts WHERE Key_name = 'idx_posts_message_txt';
"
```

---

### Phase 5: 驗證與測試（30分鐘）

#### 5.1 驗證索引正確性

```bash
mysql -h 34.87.11.83 -u mmuser -p'mmpass' mattermost_prod_local -e "
-- 1. 確認索引存在
SHOW INDEX FROM Posts WHERE Key_name = 'idx_posts_message_txt';

-- 2. 確認資料筆數一致
SELECT COUNT(*) as total_posts FROM Posts WHERE DeleteAt = 0;

-- 3. 測試搜尋功能
SELECT COUNT(*) as search_test_1
FROM Posts
WHERE MATCH(Message) AGAINST('hello' IN BOOLEAN MODE);

SELECT COUNT(*) as search_test_2
FROM Posts
WHERE MATCH(Message) AGAINST('1,234' IN BOOLEAN MODE);
"
```

#### 5.2 前端測試

1. 登入 Mattermost
2. 嘗試搜尋包含逗號的內容（如 `1,234`）
3. 確認搜尋結果正確

#### 5.3 效能測試

```bash
# 測試搜尋速度
mysql -h 34.87.11.83 -u mmuser -p'mmpass' mattermost_prod_local -e "
SET profiling = 1;
SELECT COUNT(*) FROM Posts WHERE MATCH(Message) AGAINST('+test +message' IN BOOLEAN MODE);
SHOW PROFILES;
"
```

應該在 50ms 以內完成。

---

### Phase 6: 清理（可選）

```bash
# gh-ost 會自動清理 ghost table
# 但如果有保留舊表（--initially-drop-old-table=false），可以手動刪除

mysql -h 34.87.11.83 -u mmuser -p'mmpass' mattermost_prod_local -e "
-- 查看是否有舊表
SHOW TABLES LIKE '%_del' OR SHOW TABLES LIKE '%_old';

-- 如果有，且確認新表正常，可以刪除
-- DROP TABLE Posts_20241107_old;  -- 視實際表名而定
"
```

---

## 🆘 故障排除

### 問題 1: gh-ost 卡住不動

**檢查**:
```bash
echo "status" | nc -U /tmp/gh-ost.sock
```

**可能原因**:
- 達到 max-load 限制 → 等待負載降低
- MySQL 複製延遲 → 檢查 `SHOW SLAVE STATUS\G`

**解決**:
```bash
# 提高 max-load 限制
echo "max-load=Threads_running=80" | nc -U /tmp/gh-ost.sock
```

### 問題 2: 錯誤訊息 "context deadline exceeded"

**原因**: 資料庫連線逾時

**解決**: 重新執行 gh-ost，它會從上次進度繼續

### 問題 3: 需要緊急回滾

```bash
# 1. 立即暫停 gh-ost
touch /tmp/ghost.panic

# 2. 等待 gh-ost 停止（不會切換表）

# 3. 清理 ghost table
mysql -h 34.87.11.83 -u mmuser -p'mmpass' mattermost_prod_local -e "
DROP TABLE IF EXISTS _Posts_gho;
DROP TABLE IF EXISTS _Posts_ghc;
DROP TABLE IF EXISTS _Posts_del;
"

# 4. 系統恢復正常，使用原索引
```

### 問題 4: 磁碟空間不足

```bash
# 檢查空間
df -h

# 如果空間不足，gh-ost 會自動暫停
# 清理空間後，它會自動恢復
```

---

## 📋 檢查清單

**執行前**:
- [ ] 已完成資料庫備份
- [ ] 確認磁碟空間充足（> 3.5 GB）
- [ ] 已安裝 gh-ost
- [ ] 已修改 MySQL 配置（innodb_ft_min_token_size=1）
- [ ] MySQL 已重啟並驗證設定
- [ ] 通知使用者（可選，因為零停機）

**執行中**:
- [ ] gh-ost 正常運行
- [ ] 監控進度（ETA 合理）
- [ ] MySQL 負載正常（< 50 threads）
- [ ] 無錯誤訊息

**執行後**:
- [ ] 索引重建完成
- [ ] 資料筆數一致
- [ ] 搜尋功能正常
- [ ] 可以搜尋到包含逗號的內容
- [ ] 效能測試通過
- [ ] 清理暫存檔案

---

## 📞 支援資源

- **gh-ost 文件**: https://github.com/github/gh-ost
- **Mattermost 論壇**: https://forum.mattermost.com/
- **MySQL 文件**: https://dev.mysql.com/doc/refman/8.0/en/

---

## ⏱️ 時間線範例

```
00:00 - 開始備份
00:30 - 備份完成，開始修改 MySQL 配置
00:35 - 重啟 MySQL
00:40 - 安裝 gh-ost
00:50 - 啟動 gh-ost
01:00 - 複製進度 5%
02:00 - 複製進度 30%
03:00 - 複製進度 55%
04:00 - 複製進度 80%
05:00 - 複製進度 98%
05:15 - 等待最後確認
05:16 - 執行切換
05:17 - 完成！開始驗證
05:47 - 驗證完成，任務結束 ✅
```

---

**祝執行順利！如有任何問題，隨時暫停並尋求協助。**
