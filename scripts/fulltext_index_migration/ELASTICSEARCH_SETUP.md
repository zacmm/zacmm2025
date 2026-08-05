# Elasticsearch 架設指南（替代方案）

## 📊 方案對比

| 項目 | MySQL Fulltext 修改 | Elasticsearch |
|-----|-------------------|---------------|
| **執行時間** | 4-6 小時 | 1-2 小時 |
| **停機時間** | 0（gh-ost）或 2-4h | 0（可同時運行）|
| **額外資源** | 無 | 記憶體 +1-2GB |
| **搜尋效能** | 50ms | 10-30ms（更快）|
| **支援逗號** | ✅ | ✅ |
| **模糊搜尋** | ❌ | ✅ |
| **維護複雜度** | 低 | 中 |
| **可回滾性** | 中 | 高（直接關閉）|

**建議**：如果有額外資源，Elasticsearch 是更好的選擇！

---

## 🎯 架設規劃

### 環境資訊
```
遠端伺服器: 34.87.11.83
Mattermost 資料: 181萬筆訊息
預估索引大小: 約 500-800 MB
記憶體需求: 1-2 GB
```

### 執行時間
```
安裝 Elasticsearch:  15 分鐘
配置 Mattermost:     5 分鐘
建立初始索引:        1-2 小時（背景執行，不影響使用）
測試驗證:           15 分鐘
━━━━━━━━━━━━━━━━━━━━━━━━
總計:               2-2.5 小時
```

---

## 🚀 安裝步驟

### Phase 1: 安裝 Elasticsearch（15分鐘）

#### 1.1 SSH 連線到遠端伺服器

```bash
ssh user@34.87.11.83
```

#### 1.2 安裝 Elasticsearch

**方式 A：使用 Docker（推薦）⭐**

```bash
# 1. 安裝 Docker（如果還沒有）
sudo apt-get update
sudo apt-get install -y docker.io docker-compose

# 2. 啟動 Docker 服務
sudo systemctl start docker
sudo systemctl enable docker

# 3. 創建 Elasticsearch 目錄
mkdir -p ~/elasticsearch/data
chmod 777 ~/elasticsearch/data

# 4. 創建 docker-compose.yml
cat > ~/elasticsearch/docker-compose.yml <<'EOF'
version: '3.8'

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    container_name: mattermost-elasticsearch
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms512m -Xmx1024m"
      - xpack.security.enabled=false
      - xpack.security.http.ssl.enabled=false
    ports:
      - "9200:9200"
      - "9300:9300"
    volumes:
      - ./data:/usr/share/elasticsearch/data
    restart: unless-stopped
    ulimits:
      memlock:
        soft: -1
        hard: -1
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9200/_cluster/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
EOF

# 5. 啟動 Elasticsearch
cd ~/elasticsearch
sudo docker-compose up -d

# 6. 等待啟動（約 30 秒）
echo "等待 Elasticsearch 啟動..."
sleep 30

# 7. 驗證安裝
curl http://localhost:9200
```

**預期輸出**：
```json
{
  "name" : "...",
  "cluster_name" : "docker-cluster",
  "version" : {
    "number" : "8.11.0"
  },
  "tagline" : "You Know, for Search"
}
```

---

**方式 B：直接安裝（不推薦，但如果不能用 Docker）**

```bash
# 1. 安裝 Java
sudo apt-get update
sudo apt-get install -y openjdk-11-jdk

# 2. 添加 Elasticsearch 倉庫
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list

# 3. 安裝 Elasticsearch
sudo apt-get update
sudo apt-get install -y elasticsearch

# 4. 配置 Elasticsearch
sudo tee /etc/elasticsearch/elasticsearch.yml > /dev/null <<'EOF'
cluster.name: mattermost-cluster
node.name: node-1
network.host: 0.0.0.0
http.port: 9200
discovery.type: single-node
xpack.security.enabled: false
xpack.security.http.ssl.enabled: false
EOF

# 5. 設定 JVM 記憶體
sudo tee /etc/elasticsearch/jvm.options.d/heap.options > /dev/null <<'EOF'
-Xms512m
-Xmx1024m
EOF

# 6. 啟動服務
sudo systemctl daemon-reload
sudo systemctl enable elasticsearch
sudo systemctl start elasticsearch

# 7. 等待啟動
sleep 30

# 8. 驗證
curl http://localhost:9200
```

---

#### 1.3 驗證 Elasticsearch 健康狀態

```bash
# 檢查叢集健康
curl http://localhost:9200/_cluster/health?pretty

# 檢查節點資訊
curl http://localhost:9200/_cat/nodes?v

# 檢查記憶體使用
curl http://localhost:9200/_cat/allocation?v
```

**預期輸出**：
```
health status
green  open
```

---

### Phase 2: 配置 Mattermost（5分鐘）

#### 2.1 修改 Mattermost 配置

```bash
# 1. 備份原配置
sudo cp /path/to/mattermost/config/config.json /path/to/mattermost/config/config.json.backup

# 2. 編輯配置（根據實際路徑）
sudo nano /path/to/mattermost/config/config.json
```

**找到 `ElasticsearchSettings` 區段，修改為**：

```json
"ElasticsearchSettings": {
    "ConnectionURL": "http://localhost:9200",
    "Backend": "elasticsearch",
    "Username": "",
    "Password": "",
    "EnableIndexing": true,
    "EnableSearching": true,
    "EnableAutocomplete": true,
    "Sniff": false,
    "PostIndexReplicas": 1,
    "PostIndexShards": 1,
    "ChannelIndexReplicas": 1,
    "ChannelIndexShards": 1,
    "UserIndexReplicas": 1,
    "UserIndexShards": 1,
    "AggregatePostsAfterDays": 365,
    "PostsAggregatorJobStartTime": "03:00",
    "IndexPrefix": "",
    "LiveIndexingBatchSize": 1,
    "BatchSize": 10000,
    "RequestTimeoutSeconds": 30,
    "SkipTLSVerification": false,
    "Trace": ""
}
```

**關鍵修改**：
- `EnableIndexing: true` - 啟用索引
- `EnableSearching: true` - 啟用搜尋
- `EnableAutocomplete: true` - 啟用自動完成

#### 2.2 重啟 Mattermost

```bash
# 重啟 Mattermost 服務
sudo systemctl restart mattermost

# 或如果是手動運行
# 停止舊進程，重新啟動

# 等待啟動
sleep 10

# 驗證服務正常
curl http://localhost:8065/api/v4/system/ping
```

---

### Phase 3: 建立索引（1-2小時，背景執行）

#### 3.1 透過系統控制台建立索引

**方式 A：使用 Web UI（推薦）**

1. 登入 Mattermost: `http://your-domain.com`
2. 點擊左上角選單 → **系統控制台**
3. 進入 **Environment** → **Elasticsearch**
4. 確認設定正確：
   ```
   Server Connection Address: http://localhost:9200
   Enable Indexing: true
   Enable Searching: true
   ```
5. 點擊 **Test Connection** 按鈕
   - 應該顯示：✅ "Connection successful"
6. 點擊 **Build Index** 按鈕
   - 會開始建立索引（背景執行）
7. 點擊 **Purge Indexes** 旁的 **Job Status**
   - 可以看到索引進度

**方式 B：使用 mmctl 命令行（如果 Web UI 無法使用）**

```bash
# 1. 下載 mmctl（如果還沒有）
cd /tmp
wget https://releases.mattermost.com/mmctl/v8.0.0/mmctl-linux-amd64.tar.gz
tar -xzf mmctl-linux-amd64.tar.gz
sudo mv mmctl /usr/local/bin/
chmod +x /usr/local/bin/mmctl

# 2. 認證
mmctl auth login http://localhost:8065

# 3. 測試 Elasticsearch 連線
mmctl elasticsearch test

# 4. 建立索引
mmctl elasticsearch indexes create

# 5. 查看索引狀態
mmctl elasticsearch indexes status
```

#### 3.2 監控索引進度

**方式 1：透過 Elasticsearch API**

```bash
# 查看索引列表
curl http://localhost:9200/_cat/indices?v

# 查看索引大小和文件數
curl http://localhost:9200/_cat/indices/mattermost*?v&h=index,docs.count,store.size

# 持續監控
watch -n 10 'curl -s http://localhost:9200/_cat/indices/mattermost*?v'
```

**預期輸出**（完成後）：
```
index                    docs.count store.size
mattermost_posts_v1      1813704    ~500mb
mattermost_channels_v1   150        ~1mb
mattermost_users_v1      50         ~0.5mb
```

**方式 2：透過 Mattermost 日誌**

```bash
# 查看 Mattermost 日誌
sudo tail -f /path/to/mattermost/logs/mattermost.log | grep -i elastic

# 或查看 Docker 日誌（如果使用 Docker）
docker logs -f mattermost
```

---

### Phase 4: 測試與驗證（15分鐘）

#### 4.1 測試搜尋功能

**測試 1：基本搜尋**
```bash
# 使用 Elasticsearch API 直接測試
curl -X GET "http://localhost:9200/mattermost_posts_v1/_search?pretty" -H 'Content-Type: application/json' -d'
{
  "query": {
    "match": {
      "message": "hello"
    }
  },
  "size": 5
}
'
```

**測試 2：搜尋包含逗號的內容**
```bash
curl -X GET "http://localhost:9200/mattermost_posts_v1/_search?pretty" -H 'Content-Type: application/json' -d'
{
  "query": {
    "match": {
      "message": "1,234"
    }
  }
}
'
```

**測試 3：透過 Mattermost UI 測試**

1. 登入 Mattermost
2. 在搜尋框輸入：`1,234`
3. 應該能找到包含 "1,234" 的訊息 ✅
4. 試試其他關鍵字：`$1,234`、`hello`、`test`

#### 4.2 效能測試

```bash
# 測試搜尋速度
time curl -X GET "http://localhost:9200/mattermost_posts_v1/_search" -H 'Content-Type: application/json' -d'
{
  "query": {
    "match": {
      "message": "test"
    }
  }
}
'
```

**預期結果**：< 50ms（通常 10-30ms）

#### 4.3 驗證檢查清單

- [ ] Elasticsearch 正常運行（`curl http://localhost:9200`）
- [ ] Mattermost 配置正確（`EnableSearching: true`）
- [ ] 索引建立完成（`docs.count` 符合訊息數量）
- [ ] 可以搜尋到一般關鍵字
- [ ] 可以搜尋到包含逗號的內容（`1,234`）
- [ ] 搜尋速度正常（< 50ms）
- [ ] 自動完成功能正常

---

## 🔧 常見問題

### Q1: Elasticsearch 啟動失敗

**錯誤**: `max virtual memory areas vm.max_map_count [65530] is too low`

**解決**:
```bash
# 臨時修改
sudo sysctl -w vm.max_map_count=262144

# 永久修改
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Q2: 記憶體不足

**錯誤**: `OutOfMemoryError`

**解決**:
```bash
# 減少 JVM 記憶體（Docker）
# 修改 docker-compose.yml:
ES_JAVA_OPTS=-Xms256m -Xmx512m

# 或修改 jvm.options（直接安裝）
sudo nano /etc/elasticsearch/jvm.options.d/heap.options
-Xms256m
-Xmx512m
```

### Q3: 索引建立很慢

**原因**: 資料量大

**解決**:
- 正常情況（181萬筆需要 1-2 小時）
- 可以繼續使用 Mattermost（背景執行）
- 索引期間會使用 MySQL 搜尋

### Q4: 搜尋仍然用 MySQL

**檢查**:
```bash
# 確認設定
curl http://localhost:8065/api/v4/elasticsearch/test

# 查看 Mattermost 日誌
tail -f /var/log/mattermost/mattermost.log | grep -i search
```

### Q5: 如何回滾到 MySQL 搜尋？

```bash
# 1. 修改 config.json
"EnableSearching": false

# 2. 重啟 Mattermost
sudo systemctl restart mattermost

# 完成！立即切換回 MySQL
```

---

## 📊 資源監控

### 監控 Elasticsearch 資源使用

```bash
# 查看記憶體使用
curl http://localhost:9200/_cat/nodes?v&h=heap.percent,ram.percent

# 查看磁碟使用
curl http://localhost:9200/_cat/allocation?v

# 查看索引大小
du -sh ~/elasticsearch/data/
```

### 監控系統資源

```bash
# 記憶體
free -h

# 磁碟
df -h

# CPU
top -bn1 | grep "Cpu(s)"
```

---

## 🎯 效能優化建議

### 1. 調整 JVM 記憶體

**小型部署（< 100萬筆）**:
```
-Xms512m -Xmx1024m
```

**中型部署（100-500萬筆）**:
```
-Xms1g -Xmx2g
```

### 2. 調整索引設定

```bash
# 減少副本數（單節點不需要副本）
curl -X PUT "http://localhost:9200/mattermost_posts_v1/_settings" -H 'Content-Type: application/json' -d'
{
  "index": {
    "number_of_replicas": 0
  }
}
'
```

### 3. 定期維護

```bash
# 每月執行一次索引優化
curl -X POST "http://localhost:9200/mattermost_posts_v1/_forcemerge?max_num_segments=1"
```

---

## 🆘 緊急操作

### 停止 Elasticsearch

```bash
# Docker 方式
cd ~/elasticsearch
sudo docker-compose down

# 直接安裝方式
sudo systemctl stop elasticsearch
```

### 清空索引重建

```bash
# 1. 刪除所有索引
curl -X DELETE "http://localhost:9200/mattermost*"

# 2. 透過 Mattermost 重建
# 進入系統控制台 → Elasticsearch → Build Index
```

### 完全移除 Elasticsearch

```bash
# Docker 方式
cd ~/elasticsearch
sudo docker-compose down -v
sudo rm -rf ~/elasticsearch

# 直接安裝方式
sudo systemctl stop elasticsearch
sudo systemctl disable elasticsearch
sudo apt-get purge -y elasticsearch
sudo rm -rf /var/lib/elasticsearch
```

---

## 📝 檢查清單

### 安裝前
- [ ] 確認伺服器記憶體 > 2GB
- [ ] 確認磁碟空間 > 2GB
- [ ] 備份 Mattermost 配置

### 安裝後
- [ ] Elasticsearch 正常運行
- [ ] Mattermost 配置已更新
- [ ] 服務已重啟
- [ ] 索引建立中或已完成
- [ ] 搜尋功能正常
- [ ] 可搜尋 `1,234` 等逗號內容

---

**預計效果**：
- ✅ 可以搜尋 `1,234`、`$1,234` 等包含逗號的內容
- ✅ 搜尋速度更快（10-30ms）
- ✅ 支援模糊搜尋
- ✅ 可隨時切換回 MySQL
