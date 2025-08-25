#!/bin/bash

echo "🔍 尋找 Mattermost 資料庫設定..."
echo "================================"

# 1. 檢查 Docker 環境
if [ -f "docker-compose.yml" ]; then
    echo "📦 Docker 環境檢測到"
    echo ""
    
    if [ -f ".env" ]; then
        echo "📄 .env 檔案中的資料庫設定："
        grep -E "POSTGRES|DATABASE|DB_|MM_SQLSETTINGS" .env 2>/dev/null || echo "  沒有找到資料庫設定"
        echo ""
    fi
    
    # 檢查運行中的容器
    if docker-compose ps | grep -q "mattermost"; then
        echo "🐳 運行中的 Mattermost 容器環境變數："
        docker-compose exec mattermost env | grep -E "MM_SQLSETTINGS|DATABASE" 2>/dev/null || echo "  沒有找到環境變數"
        echo ""
    fi
fi

# 2. 檢查常見的 config.json 位置
echo "📁 尋找 config.json 檔案..."
CONFIG_PATHS=(
    "/opt/mattermost/config/config.json"
    "/etc/mattermost/config.json"
    "./config/config.json"
    "./mattermost/config/config.json"
    "$HOME/mattermost/config/config.json"
)

for path in "${CONFIG_PATHS[@]}"; do
    if [ -f "$path" ]; then
        echo "✅ 找到設定檔: $path"
        echo "   資料庫設定："
        cat "$path" | jq '.SqlSettings | {DriverName, DataSource}' 2>/dev/null || \
            grep -A5 '"SqlSettings"' "$path" | head -10
        echo ""
        break
    fi
done

# 3. 檢查 systemd 服務
if systemctl list-units --full -all | grep -q "mattermost"; then
    echo "🔧 Systemd 服務設定："
    systemctl show mattermost | grep -E "Environment|ExecStart" | head -5
    echo ""
fi

# 4. 檢查進程
if pgrep -f mattermost > /dev/null; then
    echo "🏃 運行中的 Mattermost 進程："
    ps aux | grep -i mattermost | grep -v grep | head -1
    echo ""
fi

echo "================================"
echo "💡 提示："
echo "1. Docker 環境：編輯 .env 檔案"
echo "2. 原生安裝：編輯 config.json 的 SqlSettings 區塊"
echo "3. 可用環境變數覆蓋：MM_SQLSETTINGS_DATASOURCE"