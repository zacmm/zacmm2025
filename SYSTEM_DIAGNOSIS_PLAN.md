# 系統診斷計劃 - 記憶體與磁碟寫入過高問題

## 📊 問題描述

**症狀**：
- 記憶體使用率過高
- 磁碟寫入率過高
- 應用程式卡住、無回應
- 需要重啟伺服器才能恢復

**影響**：
- 使用者無法使用服務
- 可能導致資料遺失
- 影響業務連續性

---

## 🔍 診斷流程

### 階段 1：立即診斷（當問題發生時）

#### 1.1 快速檢查腳本

在生產伺服器執行：

```bash
# 上傳並執行監控腳本
chmod +x monitor_system.sh
./monitor_system.sh
```

這會生成完整的系統報告，包含：
- 記憶體使用狀況
- 磁碟 I/O 狀況
- 進程資源使用
- 資料庫連線數
- 系統負載

#### 1.2 手動快速檢查

如果腳本無法執行，使用以下指令：

```bash
# 1. 記憶體檢查
free -h
ps aux --sort=-%mem | head -10

# 2. 磁碟檢查
df -h
iostat -x 1 5  # 如果已安裝

# 3. 找出寫入最多的進程
sudo iotop -b -n 1 -o  # 如果已安裝

# 4. 檢查 Mattermost 日誌
tail -100 server/logs/mattermost.log | grep -i "error\|out of memory"

# 5. 檢查系統日誌
sudo journalctl -u mattermost -n 100 --no-pager
sudo dmesg | tail -50  # 檢查 OOM killer
```

### 階段 2：持續監控（長期追蹤）

#### 2.1 啟動持續監控

```bash
# 在背景執行持續監控（每 60 秒記錄一次）
chmod +x continuous_monitor.sh
nohup ./continuous_monitor.sh 60 > /dev/null 2>&1 &

# 查看監控狀態
tail -f system_logs/continuous_monitor.log

# 查看警告
tail -f system_logs/alerts.log
```

#### 2.2 監控數據分析

監控日誌會記錄：
- 時間戳
- 記憶體使用量和百分比
- 磁碟使用百分比
- 系統負載
- Mattermost CPU 和記憶體使用
- MySQL 連線數
- 磁碟 I/O 累積量

**分析重點**：
- 記憶體是否持續增長（記憶體洩漏）
- 磁碟寫入是否突然增加
- 哪個時間點開始出現異常

### 階段 3：根本原因分析

根據監控數據，常見原因包括：

---

## 🐛 常見問題與原因

### 問題 1：記憶體持續增長（記憶體洩漏）

**可能原因**：
1. **Mattermost 記憶體洩漏**
   - WebSocket 連線未正確關閉
   - 快取未清理
   - Go runtime 垃圾回收不及時

2. **資料庫連線池未釋放**
   - MySQL 連線數持續增加
   - 長時間執行的查詢

3. **檔案上傳暫存未清理**
   - 上傳檔案暫存在記憶體中
   - 大檔案上傳導致記憶體暴增

**診斷方法**：
```bash
# 檢查 Mattermost 記憶體使用趨勢
ps -p $(pgrep -f "bin/mattermost") -o pid,rss,vsz,cmd --sort=-rss
watch -n 5 'ps -p $(pgrep -f "bin/mattermost") -o rss | tail -1'

# 檢查 MySQL 連線數
mysql -h 34.87.11.83 -u mmuser -pmmpass -e "SHOW PROCESSLIST;"
mysql -h 34.87.11.83 -u mmuser -pmmpass -e "SHOW STATUS LIKE 'Threads%';"
```

**解決方案**：
- 設定記憶體限制（systemd service）
- 調整垃圾回收參數
- 限制最大連線數
- 定期重啟（臨時方案）

### 問題 2：磁碟寫入過高

**可能原因**：
1. **日誌檔案寫入過多**
   - Debug level 日誌
   - 錯誤日誌不斷重複
   - 未輪替的日誌

2. **Bleve 索引建立**
   - 正在建立全文搜尋索引
   - 批次大小太大

3. **資料庫寫入**
   - 大量訊息寫入
   - 資料庫遷移或索引重建

4. **檔案上傳**
   - 大量檔案同時上傳

**診斷方法**：
```bash
# 檢查日誌檔案大小
du -sh server/logs/*
ls -lht server/logs/ | head -10

# 檢查 Bleve 索引狀態
du -sh server/data/bleve-indexes/

# 檢查最近寫入的檔案
find server/logs -type f -mmin -10  # 最近 10 分鐘修改的檔案
find server/data -type f -mmin -10

# 監控即時寫入
sudo iotop -o  # 只顯示正在寫入的進程
```

**解決方案**：
- 降低日誌級別（從 DEBUG 改為 INFO）
- 設定日誌輪替
- 調整 Bleve BatchSize
- 限制檔案上傳大小和速率

### 問題 3：系統 swap 過度使用

**可能原因**：
- 實體記憶體不足
- swap 設定不當

**診斷方法**：
```bash
# 檢查 swap 使用
free -h
swapon --show

# 檢查 swappiness
cat /proc/sys/vm/swappiness
```

**解決方案**：
```bash
# 調整 swappiness（降低 swap 使用傾向）
sudo sysctl vm.swappiness=10
echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
```

### 問題 4：資料庫查詢緩慢

**可能原因**：
- 慢查詢佔用連線
- 索引缺失
- 資料量過大

**診斷方法**：
```bash
# 檢查慢查詢
mysql -h 34.87.11.83 -u mmuser -pmmpass -e "SHOW FULL PROCESSLIST;" | grep -v Sleep

# 檢查慢查詢日誌（如果有啟用）
# sudo cat /var/log/mysql/mysql-slow.log | tail -100
```

---

## 🛠️ 解決方案

### 臨時解決方案（緊急時使用）

#### 1. 釋放記憶體快取

```bash
# 清理 page cache（安全，不會遺失資料）
sudo sync
echo 1 | sudo tee /proc/sys/vm/drop_caches
```

#### 2. 重啟 Mattermost 服務

```bash
# 優雅重啟
sudo systemctl restart mattermost

# 或使用部署腳本
./devops_backend_only.sh
```

#### 3. 終止佔用資源的進程

```bash
# 找出佔用最多記憶體的進程
ps aux --sort=-%mem | head -5

# 如果發現異常進程，終止它（小心操作）
# sudo kill -9 <PID>
```

### 長期解決方案

#### 1. 限制 Mattermost 記憶體使用

修改 systemd service 配置：

```bash
sudo nano /etc/systemd/system/mattermost.service
```

添加記憶體限制：

```ini
[Service]
...
# 限制記憶體使用（例如 2GB）
MemoryLimit=2G
MemoryMax=2G

# 限制 CPU 使用
CPUQuota=200%

# Go runtime 環境變數
Environment="GOMEMLIMIT=1800MiB"
Environment="GOGC=50"
```

重新載入並重啟：

```bash
sudo systemctl daemon-reload
sudo systemctl restart mattermost
```

#### 2. 優化日誌配置

修改 `server/config/config.json`：

```json
"LogSettings": {
    "ConsoleLevel": "INFO",        // 降低日誌級別
    "FileLevel": "INFO",
    "EnableFile": true,
    "FileJson": true,
    "FileLocation": "",
    "EnableWebhookDebugging": false,
    "EnableDiagnostics": false,
    "MaxFieldSize": 2048
}
```

設定日誌輪替（`/etc/logrotate.d/mattermost`）：

```
/srv/gopath/src/github.com/zacmm/zacmm2025/server/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    postrotate
        systemctl reload mattermost > /dev/null 2>&1 || true
    endscript
}
```

#### 3. 優化資料庫連線

修改 `server/config/config.json`：

```json
"SqlSettings": {
    "MaxIdleConns": 10,           // 降低空閒連線
    "MaxOpenConns": 100,          // 限制最大連線
    "ConnMaxLifetimeMilliseconds": 3600000,
    "ConnMaxIdleTimeMilliseconds": 300000
}
```

#### 4. 優化檔案上傳

```json
"FileSettings": {
    "MaxFileSize": 52428800,      // 50MB 限制
    "EnableFileAttachments": true,
    "EnableMobileUpload": true,
    "EnableMobileDownload": true
}
```

#### 5. 設定系統監控告警

使用 cron 定期執行監控：

```bash
# 編輯 crontab
crontab -e

# 添加：每小時執行一次監控
0 * * * * /srv/gopath/src/github.com/zacmm/zacmm2025/monitor_system.sh

# 或持續監控（開機啟動）
@reboot nohup /srv/gopath/src/github.com/zacmm/zacmm2025/continuous_monitor.sh 60 > /dev/null 2>&1 &
```

#### 6. 增加 swap 空間（如果記憶體不足）

```bash
# 創建 4GB swap 檔案
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 永久啟用
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# 調整 swappiness
sudo sysctl vm.swappiness=10
echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
```

---

## 📈 預防措施

### 1. 定期維護

```bash
# 每週執行清理腳本
# cleanup_weekly.sh

# 清理舊日誌（保留 7 天）
find server/logs -name "*.log" -mtime +7 -delete

# 清理舊的上傳檔案（根據需求）
# find server/data -type f -mtime +90 -delete

# 重建資料庫索引（可選）
# mysql -h 34.87.11.83 -u mmuser -pmmpass mattermost_prod_local -e "OPTIMIZE TABLE Posts;"
```

### 2. 監控儀表板

建議使用專業監控工具：
- **Prometheus + Grafana**：視覺化監控
- **Netdata**：即時系統監控
- **Zabbix**：企業級監控

簡易版可以使用我們提供的腳本：
- `monitor_system.sh`：手動診斷
- `continuous_monitor.sh`：持續監控

### 3. 定期重啟（臨時方案）

如果問題無法根治，可以設定定期重啟：

```bash
# 每天凌晨 3 點重啟（低峰期）
0 3 * * * /srv/gopath/src/github.com/zacmm/zacmm2025/devops_backend_only.sh
```

**注意**：這只是臨時方案，應該找出根本原因。

---

## 🎯 執行計劃

### 第一步：立即執行（今天）

1. 上傳監控腳本到生產環境
2. 執行 `./monitor_system.sh` 獲取當前狀態
3. 檢查報告，找出異常

### 第二步：啟動持續監控（今天）

1. 在背景執行 `continuous_monitor.sh`
2. 觀察 24-48 小時
3. 分析數據找出規律

### 第三步：應用臨時修復（1-2 天內）

1. 降低日誌級別到 INFO
2. 設定日誌輪替
3. 限制 Mattermost 記憶體使用
4. 優化資料庫連線設定

### 第四步：長期優化（1 週內）

1. 分析監控數據確定根本原因
2. 應用對應的長期解決方案
3. 設定自動化監控和告警
4. 建立定期維護計劃

---

## 📞 緊急處理流程

當系統卡住時：

```bash
# 1. SSH 登入伺服器
ssh user@your-server

# 2. 快速檢查
free -h
df -h
ps aux --sort=-%mem | head -5

# 3. 如果記憶體滿了
sudo sync
echo 1 | sudo tee /proc/sys/vm/drop_caches

# 4. 如果還是卡住，重啟 Mattermost
sudo systemctl restart mattermost

# 5. 檢查日誌
sudo journalctl -u mattermost -n 100 --no-pager

# 6. 執行診斷腳本（恢復後）
./monitor_system.sh
```

---

## ✅ 檢查清單

- [ ] 上傳監控腳本到生產環境
- [ ] 執行初次診斷 (`monitor_system.sh`)
- [ ] 啟動持續監控 (`continuous_monitor.sh`)
- [ ] 降低日誌級別為 INFO
- [ ] 設定日誌輪替
- [ ] 添加 Mattermost 記憶體限制（systemd）
- [ ] 優化資料庫連線設定
- [ ] 設定監控告警（cron 或監控系統）
- [ ] 檢查是否有 swap 空間
- [ ] 記錄問題發生的時間和頻率
- [ ] 分析監控數據找出根本原因

---

**建立日期**：2025-11-26
**預計解決時間**：1-2 週（找出根本原因並徹底解決）
