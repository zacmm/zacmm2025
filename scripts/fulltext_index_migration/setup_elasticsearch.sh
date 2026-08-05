#!/bin/bash

# Elasticsearch 安裝腳本（用於遠端伺服器）
# 使用方式：將此腳本複製到遠端伺服器並執行

set -e

echo "════════════════════════════════════════════════════════════════"
echo "  Elasticsearch 安裝腳本 for Mattermost"
echo "════════════════════════════════════════════════════════════════"
echo ""

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 檢查是否為 root 或有 sudo 權限
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}注意: 部分操作需要 sudo 權限${NC}"
fi

# 1. 檢查 Docker
echo -e "${BLUE}[1/6] 檢查 Docker 安裝...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker 未安裝，開始安裝...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    echo -e "${GREEN}✓ Docker 安裝完成${NC}"
    echo -e "${YELLOW}注意: 你可能需要登出並重新登入以使用 Docker${NC}"
else
    echo -e "${GREEN}✓ Docker 已安裝: $(docker --version)${NC}"
fi

# 2. 檢查 Docker Compose
echo ""
echo -e "${BLUE}[2/6] 檢查 Docker Compose...${NC}"
if ! command -v docker-compose &> /dev/null; then
    echo -e "${YELLOW}Docker Compose 未安裝，開始安裝...${NC}"
    sudo apt-get update
    sudo apt-get install docker-compose -y
    echo -e "${GREEN}✓ Docker Compose 安裝完成${NC}"
else
    echo -e "${GREEN}✓ Docker Compose 已安裝: $(docker-compose --version)${NC}"
fi

# 3. 創建工作目錄
echo ""
echo -e "${BLUE}[3/6] 創建 Elasticsearch 目錄...${NC}"
mkdir -p ~/elasticsearch
cd ~/elasticsearch
echo -e "${GREEN}✓ 工作目錄: $(pwd)${NC}"

# 4. 創建 docker-compose.yml
echo ""
echo -e "${BLUE}[4/6] 創建 docker-compose.yml...${NC}"
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
      - bootstrap.memory_lock=true
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - es_data:/usr/share/elasticsearch/data
    ports:
      - "9200:9200"
      - "9300:9300"
    restart: unless-stopped
    networks:
      - elastic
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9200/_cluster/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5

volumes:
  es_data:
    driver: local

networks:
  elastic:
    driver: bridge
EOF

echo -e "${GREEN}✓ docker-compose.yml 已創建${NC}"

# 5. 啟動 Elasticsearch
echo ""
echo -e "${BLUE}[5/6] 啟動 Elasticsearch...${NC}"
sudo docker-compose down 2>/dev/null || true
sudo docker-compose up -d

echo ""
echo -e "${YELLOW}等待 Elasticsearch 啟動...${NC}"
sleep 10

# 等待 Elasticsearch 準備就緒
MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s http://localhost:9200 >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Elasticsearch 已啟動！${NC}"
        break
    fi
    echo -n "."
    sleep 2
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}✗ Elasticsearch 啟動超時${NC}"
    echo "請查看日誌: sudo docker-compose logs elasticsearch"
    exit 1
fi

# 6. 驗證安裝
echo ""
echo -e "${BLUE}[6/6] 驗證 Elasticsearch...${NC}"
ES_INFO=$(curl -s http://localhost:9200)
ES_VERSION=$(echo $ES_INFO | grep -oP '"number"\s*:\s*"\K[^"]+' | head -1)
ES_CLUSTER=$(echo $ES_INFO | grep -oP '"cluster_name"\s*:\s*"\K[^"]+' | head -1)

echo -e "${GREEN}✓ Elasticsearch 版本: $ES_VERSION${NC}"
echo -e "${GREEN}✓ 叢集名稱: $ES_CLUSTER${NC}"

# 檢查健康狀態
HEALTH=$(curl -s http://localhost:9200/_cluster/health | grep -oP '"status"\s*:\s*"\K[^"]+')
echo -e "${GREEN}✓ 健康狀態: $HEALTH${NC}"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo -e "${GREEN}  Elasticsearch 安裝完成！${NC}"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "📋 後續步驟:"
echo "  1. 在 Mattermost config.json 中啟用 Elasticsearch"
echo "  2. 重啟 Mattermost 服務"
echo "  3. 在系統控制台建立索引"
echo ""
echo "🔧 管理命令:"
echo "  查看狀態: sudo docker-compose ps"
echo "  查看日誌: sudo docker-compose logs -f elasticsearch"
echo "  重啟服務: sudo docker-compose restart"
echo "  停止服務: sudo docker-compose stop"
echo "  移除服務: sudo docker-compose down"
echo ""
echo "🌐 API 端點:"
echo "  Elasticsearch: http://localhost:9200"
echo "  叢集健康: http://localhost:9200/_cluster/health"
echo "  索引列表: http://localhost:9200/_cat/indices?v"
echo ""
echo "════════════════════════════════════════════════════════════════"
