# Mattermost 舊資料自動清理腳本使用說明

## 📋 功能概述

此腳本用於定期清理 Mattermost 資料庫中 2024-10-29 之前的舊資料，包括：
- Posts（訊息）
- FileInfo（附件資訊）
- Reactions（emoji 反應）

## 🔧 配置說明

### 資料庫配置
```bash
DB_HOST="localhost"
DB_PORT="3306"
DB_USER="mmuser"
DB_PASS="wR7oV4kW1$tN2"
DB_NAME="zacmm"
```

### 清理配置
- **截止日期**: 2024-10-29 00:00:00
- **批次大小**: 50,000 筆/次
- **執行時間限制**: 8 分鐘（避免與下次執行重疊）
- **執行頻率**: 每 10 分鐘（透過 crontab）

### Slack 通知
- **Webhook URL**: https://hooks.slack.com/services/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
- **頻道**: #mattermost
- **通知時機**:
  - 有資料刪除時發送完成通知
  - 發生錯誤時發送錯誤通知

## 📊 Slack 通知內容

通知包含以下資訊：
- 總執行時間
- 每個表的刪除筆數
- 每個表的刪除進度百分比（基於估計總量）
- 每個表的刪除耗時

範例：
```
✅ 資料清理完成
總執行時間: 120秒

📊 清理詳情：

🔹 Reactions (emoji 反應)
  • 刪除: 50000 筆
  • 進度: 25.5% (估計總量: 196000)
  • 耗時: 35秒

🔹 FileInfo (附件資訊)
  • 刪除: 30000 筆
  • 進度: 15.2% (估計總量: 197000)
  • 耗時: 42秒

🔹 Posts (訊息)
  • 刪除: 50000 筆
  • 進度: 10.8% (估計總量: 463000)
  • 耗時: 43秒

✅ 總計刪除: 130000 筆
```

## 🚀 安裝步驟

### 1. 將腳本複製到遠端伺服器

```bash
# 在本地執行
scp v_scripts/cleanup_old_data.sh user@server:/path/to/scripts/

# 或手動複製貼上腳本內容
```

### 2. 設定執行權限

```bash
chmod +x /path/to/scripts/cleanup_old_data.sh
```

### 3. 設定 Crontab（每 10 分鐘執行）

```bash
# 編輯 crontab
crontab -e

# 加入以下行（每 10 分鐘執行一次）
*/10 * * * * /path/to/scripts/cleanup_old_data.sh >> /path/to/scripts/logs/cron.log 2>&1
```

## 🧪 測試執行

### 手動執行測試

```bash
# 執行腳本
/path/to/scripts/cleanup_old_data.sh

# 查看執行日誌
tail -f /path/to/scripts/logs/cleanup_$(date +%Y%m%d).log
```

### 檢查日誌

```bash
# 查看今天的日誌
cat /path/to/scripts/logs/cleanup_$(date +%Y%m%d).log

# 即時監控日誌
tail -f /path/to/scripts/logs/cleanup_$(date +%Y%m%d).log

# 查看所有日誌
ls -lh /path/to/scripts/logs/
```

## 🔒 安全機制

### 1. 鎖文件（防止重複執行）
腳本會在執行時創建鎖文件 `.cleanup.lock`，如果腳本已在執行中，新的執行會自動跳過。

### 2. 執行時間限制
每次執行最多 8 分鐘，避免長時間鎖表影響正常使用。

### 3. 批次處理
每次刪除 50,000 筆資料，並在批次間休息 0.5 秒，降低資料庫負載。

### 4. 錯誤處理
遇到錯誤時會：
- 記錄錯誤到日誌
- 發送 Slack 錯誤通知
- 釋放鎖文件
- 安全退出

## 📁 目錄結構

```
v_scripts/
├── cleanup_old_data.sh      # 主腳本
├── README.md                 # 本說明文件
└── logs/                     # 日誌目錄（自動創建）
    ├── cleanup_20251030.log  # 每日日誌
    ├── cleanup_20251031.log
    └── cron.log              # Crontab 執行日誌
```

## 📝 日誌管理

- 每日一個日誌檔案，格式：`cleanup_YYYYMMDD.log`
- 自動清理 30 天前的日誌
- Cron 執行日誌另外記錄在 `cron.log`

## ⚠️ 注意事項

1. **永久刪除**: 此腳本執行的是 **DELETE 永久刪除**，不是軟刪除（DeleteAt）

2. **時間條件**: 只刪除 2024-10-29 00:00:00 之前的資料

3. **資料庫負載**:
   - 建議在非高峰時段執行
   - 可調整 `BATCH_SIZE` 降低單次刪除量
   - 可調整 `MAX_EXECUTION_TIME` 控制執行時間

4. **進度估算**:
   - 進度百分比基於 `information_schema.TABLES` 的 TABLE_ROWS
   - 此值為估計值，可能不精確
   - 用於快速了解清理進度，不需要耗時的 COUNT 查詢

5. **關聯資料**:
   - 刪除順序：Reactions → FileInfo → Posts
   - 確保先刪除關聯資料，避免外鍵約束問題

6. **首次執行**:
   - 首次執行時資料量可能很大
   - 需要多次執行才能完成
   - 可監控 Slack 通知中的進度百分比

## 🔍 故障排除

### 問題 1: 腳本無法執行
```bash
# 檢查權限
ls -l cleanup_old_data.sh

# 設定執行權限
chmod +x cleanup_old_data.sh
```

### 問題 2: 資料庫連接失敗
```bash
# 測試資料庫連接
mysql -h localhost -P 3306 -u mmuser -p'wR7oV4kW1$tN2' zacmm -e "SELECT 1;"
```

### 問題 3: Slack 通知未收到
- 檢查 Webhook URL 是否正確
- 檢查網路連線
- 查看日誌中的錯誤訊息

### 問題 4: 鎖文件未釋放
```bash
# 手動刪除鎖文件
rm -f /path/to/scripts/.cleanup.lock
```

### 問題 5: 執行速度太慢
- 減少 `BATCH_SIZE`（例如改為 10000）
- 增加 `MAX_EXECUTION_TIME`
- 檢查資料庫索引是否正確

## 📈 監控建議

1. **Slack 通知**: 每次執行後會收到進度通知
2. **日誌檢查**: 定期查看日誌確認執行狀態
3. **資料庫監控**: 監控資料庫負載和表大小變化
4. **Cron 日誌**: 確認 crontab 正常觸發

## 🔄 更新配置

如需修改配置（例如截止日期、批次大小等），編輯腳本開頭的配置區：

```bash
# 清理配置
CUTOFF_DATE="2024-10-29 00:00:00"  # 修改截止日期
BATCH_SIZE=50000                    # 修改批次大小
MAX_EXECUTION_TIME=480              # 修改執行時間限制（秒）
```

修改後無需重啟，下次執行時會自動使用新配置。

## 📞 支援

如有問題，請：
1. 查看日誌檔案：`logs/cleanup_YYYYMMDD.log`
2. 檢查 Slack 錯誤通知
3. 聯繫系統管理員

---

**版本**: 1.0
**最後更新**: 2025-10-30
