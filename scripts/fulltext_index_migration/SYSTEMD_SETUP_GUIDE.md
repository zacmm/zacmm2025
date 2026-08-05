# Elasticsearch 安裝指南（systemd service 方式）

## 📋 環境資訊

- **遠端伺服器**: 34.87.11.83
- **Mattermost 配置**: /srv/gopath/src/github.com/zacmm/zacmm2025/server/config.json
- **部署方式**: systemd service (非 Docker)
- **預估時間**: 30 分鐘（安裝） + 1-2 小時（索引建立）

---

## 🚀 執行步驟

### 步驟 1：上傳安裝腳本到遠端伺服器

在你的 Mac 上執行：

```bash
# 複製安裝腳本到遠端伺服器
scp scripts/fulltext_index_migration/setup_elasticsearch_systemd.sh root@34.87.11.83:~/

# 或使用你的 SSH 使用者
scp scripts/fulltext_index_migration/setup_elasticsearch_systemd.sh your-user@34.87.11.83:~/
```

---

### 步驟 2：SSH 到遠端伺服器並執行安裝

```bash
# SSH 連線到遠端伺服器
ssh root@34.87.11.83

# 設定執行權限
chmod +x ~/setup_elasticsearch_systemd.sh

# 執行安裝腳本（需要 root 權限）
sudo ~/setup_elasticsearch_systemd.sh
```

**預期輸出**：
- ✓ 必要套件已安裝
- ✓ GPG key 已添加
- ✓ Repository 已添加
- ✓ Elasticsearch 已安裝
- ✓ Elasticsearch 配置完成
- ✓ Elasticsearch service 已啟動！
- ✓ Elasticsearch 版本: 8.x.x
- ✓ 健康狀態: green

安裝完成後，Elasticsearch 會：
- ✅ 在 http://localhost:9200 運行
- ✅ 設定為開機自動啟動
- ✅ 使用 systemd 管理（與 Mattermost 一致）

---

### 步驟 3：修改 Mattermost 配置

**方式 A：使用 sed 命令直接修改（推薦）**

```bash
# 在遠端伺服器上執行

# 備份原始配置
sudo cp /srv/gopath/src/github.com/zacmm/zacmm2025/server/config.json \
        /srv/gopath/src/github.com/zacmm/zacmm2025/server/config.json.backup

# 啟用 Elasticsearch
sudo sed -i 's/"EnableIndexing": false/"EnableIndexing": true/' \
    /srv/gopath/src/github.com/zacmm/zacmm2025/server/config.json

sudo sed -i 's/"EnableSearching": false/"EnableSearching": true/' \
    /srv/gopath/src/github.com/zacmm/zacmm2025/server/config.json

sudo sed -i 's/"EnableAutocomplete": false/"EnableAutocomplete": true/' \
    /srv/gopath/src/github.com/zacmm/zacmm2025/server/config.json

# 驗證修改
grep -A 5 "ElasticsearchSettings" /srv/gopath/src/github.com/zacmm/zacmm2025/server/config.json
```

**方式 B：手動編輯配置文件**

```bash
# 在遠端伺服器上執行
sudo nano /srv/gopath/src/github.com/zacmm/zacmm2025/server/config.json
```

找到 `ElasticsearchSettings` 區段，修改以下三個設定為 `true`：

```json
"ElasticsearchSettings": {
    "ConnectionURL": "http://localhost:9200",
    "Backend": "elasticsearch",
    "Username": "elastic",
    "Password": "changeme",
    "EnableIndexing": true,          ← 改為 true
    "EnableSearching": true,         ← 改為 true
    "EnableAutocomplete": true,      ← 改為 true
    "Sniff": true,
    ...
}
```

按 `Ctrl+O` 儲存，`Ctrl+X` 退出。

---

### 步驟 4：重啟 Mattermost 服務

```bash
# 在遠端伺服器上執行

# 重啟 Mattermost
sudo systemctl restart mattermost

# 查看狀態確認正常啟動
sudo systemctl status mattermost

# 查看日誌（檢查是否有錯誤）
sudo journalctl -u mattermost -n 50 -f
```

按 `Ctrl+C` 退出日誌查看。

---

### 步驟 5：建立 Elasticsearch 索引

**方式 A：透過系統控制台（推薦）**

1. 開啟瀏覽器訪問 Mattermost：https://newchat.bbnamg.com
2. 使用管理員帳號登入
3. 前往：**系統控制台** > **環境** > **Elasticsearch**
4. 確認設定：
   - 啟用索引：✅
   - 啟用搜尋：✅
   - 啟用自動完成：✅
   - 伺服器連線位址：http://localhost:9200
5. 點擊 **建立索引** 按鈕（或 "Index Now"）
6. 等待索引建立完成（約 1-2 小時，1,813,704 筆資料）

**方式 B：透過 mmctl 命令行工具**

```bash
# 在遠端伺服器上執行（如果有安裝 mmctl）
mmctl elasticsearch purge-indexes
mmctl elasticsearch create-indexes

# 查看索引進度
mmctl elasticsearch job list
```

**方式 C：透過 API**

```bash
# 在遠端伺服器上執行
# 建立索引
curl -X POST http://localhost:8065/api/v4/elasticsearch/purge_indexes \
  -H 'Authorization: Bearer YOUR_ACCESS_TOKEN'

# 查看索引狀態
curl http://localhost:9200/_cat/indices?v
```

---

### 步驟 6：監控索引建立進度

**方式 1：查看 Elasticsearch 索引**

```bash
# 在遠端伺服器上執行
watch -n 10 'curl -s http://localhost:9200/_cat/indices?v'
```

你會看到類似的輸出：
```
health status index                     docs.count
green  open   mattermost_posts_v1         123456
green  open   mattermost_users_v1           1234
green  open   mattermost_channels_v1         567
```

當 `mattermost_posts_v1` 的 `docs.count` 接近 1,813,704 時，表示索引建立接近完成。

**方式 2：查看 Mattermost 日誌**

```bash
# 在遠端伺服器上執行
sudo journalctl -u mattermost -f | grep -i elasticsearch
```

**方式 3：查看系統控制台**

在系統控制台 > 環境 > Elasticsearch 頁面，會顯示：
- 索引建立進度
- 已索引的文件數量
- 是否有錯誤

---

### 步驟 7：測試搜尋功能

**等待索引建立完成後：**

1. 在 Mattermost 中發送測試訊息：
   ```
   測試訊息包含 $1,234 美元
   ```

2. 使用全局搜尋（Ctrl+K）搜尋：
   ```
   1,234
   ```

3. 應該能找到剛才的測試訊息 ✅

4. 也可以搜尋其他包含逗號的內容進行測試

---

## 🔧 管理命令

### Elasticsearch 管理

```bash
# 查看服務狀態
sudo systemctl status elasticsearch

# 重啟服務
sudo systemctl restart elasticsearch

# 停止服務
sudo systemctl stop elasticsearch

# 啟動服務
sudo systemctl start elasticsearch

# 查看日誌
sudo journalctl -u elasticsearch -f

# 查看索引列表
curl http://localhost:9200/_cat/indices?v

# 查看叢集健康
curl http://localhost:9200/_cluster/health?pretty

# 查看索引統計
curl http://localhost:9200/mattermost_posts_v1/_stats?pretty
```

### Mattermost 管理

```bash
# 查看服務狀態
sudo systemctl status mattermost

# 重啟服務
sudo systemctl restart mattermost

# 查看日誌
sudo journalctl -u mattermost -f

# 查看 Elasticsearch 相關日誌
sudo journalctl -u mattermost -f | grep -i elasticsearch
```

---

## 🆘 故障排除

### 問題 1：Elasticsearch 啟動失敗

**檢查**：
```bash
sudo journalctl -u elasticsearch -n 100
```

**常見原因**：
- 記憶體不足 → 調整 `/etc/elasticsearch/jvm.options.d/heap.options`
- 端口 9200 被占用 → `sudo netstat -tlnp | grep 9200`
- 權限問題 → `sudo chown -R elasticsearch:elasticsearch /var/lib/elasticsearch`

### 問題 2：Mattermost 無法連接 Elasticsearch

**檢查連線**：
```bash
# 在遠端伺服器上測試
curl http://localhost:9200

# 從 Mattermost 的角度測試
sudo -u mattermost curl http://localhost:9200
```

**檢查配置**：
```bash
grep -A 10 "ElasticsearchSettings" /srv/gopath/src/github.com/zacmm/zacmm2025/server/config.json
```

### 問題 3：索引建立很慢或卡住

**檢查索引進度**：
```bash
# 查看索引狀態
curl http://localhost:9200/_cat/indices?v

# 查看索引任務
curl http://localhost:9200/_tasks?detailed=true&actions=*index*
```

**檢查 Mattermost 日誌**：
```bash
sudo journalctl -u mattermost -n 200 | grep -i elasticsearch
```

### 問題 4：搜尋結果不包含逗號內容

**驗證索引已建立**：
```bash
# 檢查 posts 索引數量
curl http://localhost:9200/mattermost_posts_v1/_count

# 應該顯示接近 1,813,704 筆
```

**測試直接搜尋**：
```bash
# 直接在 Elasticsearch 中搜尋
curl -X GET "http://localhost:9200/mattermost_posts_v1/_search?pretty" \
  -H 'Content-Type: application/json' \
  -d '{
    "query": {
      "match": {
        "message": "1,234"
      }
    }
  }'
```

---

## 📊 效能調整

### 調整 JVM Heap Size

如果伺服器記憶體充足，可以增加 Elasticsearch 的記憶體配置：

```bash
# 編輯 heap 設定
sudo nano /etc/elasticsearch/jvm.options.d/heap.options

# 建議：系統記憶體的 50%，但不超過 32GB
# 例如，如果有 8GB 記憶體：
-Xms2g
-Xmx2g

# 重啟服務使設定生效
sudo systemctl restart elasticsearch
```

### 監控記憶體使用

```bash
# 查看 Elasticsearch 記憶體使用
curl http://localhost:9200/_nodes/stats/jvm?pretty

# 查看系統記憶體
free -h
```

---

## ✅ 完成檢查清單

安裝完成後，確認以下項目：

- [ ] Elasticsearch service 運行正常（`systemctl status elasticsearch`）
- [ ] Elasticsearch 健康狀態為 green（`curl http://localhost:9200/_cluster/health`）
- [ ] Mattermost config.json 已修改（EnableIndexing/Searching/Autocomplete = true）
- [ ] Mattermost service 已重啟並正常運行
- [ ] 索引已建立完成（docs.count ≈ 1,813,704）
- [ ] 可以搜尋到包含逗號的內容（如 "1,234"）
- [ ] 搜尋效能正常（< 100ms）

---

## 📞 需要協助？

如果遇到任何問題，隨時詢問 Claude Code！

提供以下資訊會更有幫助：
- Elasticsearch 日誌：`sudo journalctl -u elasticsearch -n 100`
- Mattermost 日誌：`sudo journalctl -u mattermost -n 100`
- 索引狀態：`curl http://localhost:9200/_cat/indices?v`
- 叢集健康：`curl http://localhost:9200/_cluster/health?pretty`
