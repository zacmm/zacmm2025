#!/bin/bash

# Elasticsearch 安裝腳本（systemd service 方式）
# 適用於已使用 systemd 運行 Mattermost 的環境
# 使用方式：複製到遠端伺服器 34.87.11.83 並執行

set -e

echo "════════════════════════════════════════════════════════════════"
echo "  Elasticsearch 安裝腳本（systemd service）"
echo "  目標環境: Ubuntu/Debian with systemd"
echo "════════════════════════════════════════════════════════════════"
echo ""

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 檢查是否有 sudo 權限
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}此腳本需要 root 權限，請使用 sudo 執行${NC}"
    exit 1
fi

# 1. 安裝必要的套件
echo -e "${BLUE}[1/8] 安裝必要套件...${NC}"
apt-get update
apt-get install -y apt-transport-https ca-certificates wget gnupg2

echo -e "${GREEN}✓ 必要套件已安裝${NC}"

# 2. 添加 Elasticsearch GPG key
echo ""
echo -e "${BLUE}[2/8] 添加 Elasticsearch GPG key...${NC}"
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg

echo -e "${GREEN}✓ GPG key 已添加${NC}"

# 3. 添加 Elasticsearch APT repository
echo ""
echo -e "${BLUE}[3/8] 添加 Elasticsearch repository...${NC}"
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-8.x.list

apt-get update

echo -e "${GREEN}✓ Repository 已添加${NC}"

# 4. 安裝 Elasticsearch
echo ""
echo -e "${BLUE}[4/8] 安裝 Elasticsearch...${NC}"
apt-get install -y elasticsearch

echo -e "${GREEN}✓ Elasticsearch 已安裝${NC}"

# 5. 配置 Elasticsearch
echo ""
echo -e "${BLUE}[5/8] 配置 Elasticsearch...${NC}"

# 備份原始配置
cp /etc/elasticsearch/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml.backup

# 創建簡化的配置文件（單節點、無安全性）
cat > /etc/elasticsearch/elasticsearch.yml << 'EOF'
# ======================== Elasticsearch Configuration =========================
#
# 適用於 Mattermost 的簡化配置

# ---------------------------------- Cluster -----------------------------------
cluster.name: mattermost-cluster

# ------------------------------------ Node ------------------------------------
node.name: node-1

# ----------------------------------- Paths ------------------------------------
path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch

# ---------------------------------- Network -----------------------------------
network.host: 127.0.0.1
http.port: 9200

# --------------------------------- Discovery ----------------------------------
discovery.type: single-node

# ---------------------------------- Security ----------------------------------
# 停用安全功能以簡化與 Mattermost 的整合
xpack.security.enabled: false
xpack.security.enrollment.enabled: false
xpack.security.http.ssl.enabled: false
xpack.security.transport.ssl.enabled: false

# ---------------------------------- Memory ------------------------------------
# 建議設定 JVM heap size 為系統記憶體的 50%，但不超過 32GB
# 在 /etc/elasticsearch/jvm.options.d/heap.options 中設定

EOF

# 設定 JVM heap size（1GB，可根據系統記憶體調整）
mkdir -p /etc/elasticsearch/jvm.options.d
cat > /etc/elasticsearch/jvm.options.d/heap.options << 'EOF'
-Xms1g
-Xmx1g
EOF

echo -e "${GREEN}✓ Elasticsearch 配置完成${NC}"

# 6. 啟動並啟用 Elasticsearch service
echo ""
echo -e "${BLUE}[6/8] 啟動 Elasticsearch service...${NC}"
systemctl daemon-reload
systemctl enable elasticsearch
systemctl start elasticsearch

echo ""
echo -e "${YELLOW}等待 Elasticsearch 啟動...${NC}"
sleep 15

# 等待 Elasticsearch 準備就緒
MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s http://localhost:9200 >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Elasticsearch service 已啟動！${NC}"
        break
    fi
    echo -n "."
    sleep 2
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}✗ Elasticsearch 啟動超時${NC}"
    echo "請查看日誌: sudo journalctl -u elasticsearch -n 50"
    exit 1
fi

# 7. 驗證安裝
echo ""
echo -e "${BLUE}[7/8] 驗證 Elasticsearch...${NC}"
ES_INFO=$(curl -s http://localhost:9200)
ES_VERSION=$(echo $ES_INFO | grep -oP '"number"\s*:\s*"\K[^"]+' | head -1)
ES_CLUSTER=$(echo $ES_INFO | grep -oP '"cluster_name"\s*:\s*"\K[^"]+' | head -1)

echo -e "${GREEN}✓ Elasticsearch 版本: $ES_VERSION${NC}"
echo -e "${GREEN}✓ 叢集名稱: $ES_CLUSTER${NC}"

# 檢查健康狀態
HEALTH=$(curl -s http://localhost:9200/_cluster/health | grep -oP '"status"\s*:\s*"\K[^"]+')
echo -e "${GREEN}✓ 健康狀態: $HEALTH${NC}"

# 檢查服務狀態
systemctl is-active --quiet elasticsearch && echo -e "${GREEN}✓ Elasticsearch service 運行中${NC}" || echo -e "${RED}✗ Elasticsearch service 未運行${NC}"
systemctl is-enabled --quiet elasticsearch && echo -e "${GREEN}✓ Elasticsearch 已設定為開機自動啟動${NC}" || echo -e "${YELLOW}⚠ Elasticsearch 未設定開機啟動${NC}"

# 8. 顯示系統資訊
echo ""
echo -e "${BLUE}[8/8] 系統資訊${NC}"
MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
MEM_AVAILABLE=$(free -h | awk '/^Mem:/ {print $7}')
echo -e "總記憶體: $MEM_TOTAL"
echo -e "可用記憶體: $MEM_AVAILABLE"
echo ""

echo "════════════════════════════════════════════════════════════════"
echo -e "${GREEN}  Elasticsearch 安裝完成！${NC}"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "📋 後續步驟:"
echo ""
echo "  1. 修改 Mattermost 配置文件:"
echo "     檔案: /srv/gopath/src/github.com/zacmm/zacmm2025/server/config.json"
echo ""
echo '     修改以下設定:'
echo '     "ElasticsearchSettings": {'
echo '         "ConnectionURL": "http://localhost:9200",'
echo '         "EnableIndexing": true,'
echo '         "EnableSearching": true,'
echo '         "EnableAutocomplete": true'
echo '     }'
echo ""
echo "  2. 重啟 Mattermost 服務:"
echo "     sudo systemctl restart mattermost"
echo ""
echo "  3. 在 Mattermost 系統控制台建立索引:"
echo "     系統控制台 > 環境 > Elasticsearch > 建立索引"
echo "     (需要 1-2 小時完成索引建立)"
echo ""
echo "🔧 Elasticsearch 管理命令:"
echo "  查看狀態: sudo systemctl status elasticsearch"
echo "  查看日誌: sudo journalctl -u elasticsearch -f"
echo "  重啟服務: sudo systemctl restart elasticsearch"
echo "  停止服務: sudo systemctl stop elasticsearch"
echo "  啟動服務: sudo systemctl start elasticsearch"
echo ""
echo "🌐 API 端點:"
echo "  Elasticsearch: http://localhost:9200"
echo "  叢集健康: http://localhost:9200/_cluster/health"
echo "  索引列表: http://localhost:9200/_cat/indices?v"
echo ""
echo "📁 重要檔案位置:"
echo "  配置: /etc/elasticsearch/elasticsearch.yml"
echo "  資料: /var/lib/elasticsearch"
echo "  日誌: /var/log/elasticsearch"
echo "  JVM 設定: /etc/elasticsearch/jvm.options.d/"
echo ""
echo "⚙️  調整記憶體（如果需要）:"
echo "  編輯: /etc/elasticsearch/jvm.options.d/heap.options"
echo "  建議: 系統記憶體的 50%，但不超過 32GB"
echo "  修改後重啟: sudo systemctl restart elasticsearch"
echo ""
echo "════════════════════════════════════════════════════════════════"
