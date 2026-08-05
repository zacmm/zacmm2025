# 資料清理執行指南

## 執行步驟

### 1. 上傳腳本到遠端主機

```bash
scp /Users/chang/current/zacmm2025/scripts/cleanup_old_data.sh root@34.87.11.83:/tmp/
```

### 2. SSH 連接到遠端主機

```bash
ssh root@34.87.11.83
```

### 3. 在遠端主機執行清理腳本

```bash
# 背景執行並記錄日誌
nohup bash /tmp/cleanup_old_data.sh > /tmp/cleanup_$(date +%Y%m%d_%H%M%S).log 2>&1 &

# 記下進程 ID
echo $!

# 監控進度
tail -f /tmp/cleanup_*.log
```

## 腳本功能

1. **分批刪除 Posts** - 刪除超過一年的 589 萬筆資料
2. **分批刪除 FileInfo** - 刪除超過一年的 70 萬筆資料
3. **優化表格** - 使用 OPTIMIZE TABLE 回收磁碟空間
4. **Slack 通知** - 開始和完成時自動通知到 #網站監控

## 預估時間

- Posts 刪除：10-15 分鐘
- FileInfo 刪除：2-3 分鐘
- 表格優化：5-10 分鐘
- **總計：20-30 分鐘**

## 完成後

清理完成後會收到 Slack 通知，然後可以繼續執行 Mattermost migration。
