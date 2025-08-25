#!/bin/bash

echo "🔍 查詢 Production Mattermost 資料庫設定"
echo "========================================="
echo ""

# 1. 查看 config.json 中的資料庫設定
echo "📄 Config.json 資料庫設定："
CONFIG_PATH="/srv/gopath/src/github.com/zacmm/zacmm2025/server/config/config.json"

if [ -f "$CONFIG_PATH" ]; then
    echo "檔案位置: $CONFIG_PATH"
    echo ""
    echo "資料庫類型:"
    grep -A1 '"DriverName"' "$CONFIG_PATH" | grep -v DriverName | sed 's/.*"\(.*\)".*/\1/'
    echo ""
    echo "連線字串 (已遮蔽密碼):"
    grep -A1 '"DataSource"' "$CONFIG_PATH" | grep -v DataSource | sed 's/:[^:]*@/:****@/'
    echo ""
else
    echo "找不到 config.json，嘗試其他位置..."
    
    # 嘗試其他可能的位置
    POSSIBLE_PATHS=(
        "/opt/mattermost/config/config.json"
        "/etc/mattermost/config.json"
        "./config.json"
    )
    
    for path in "${POSSIBLE_PATHS[@]}"; do
        if [ -f "$path" ]; then
            echo "找到設定檔: $path"
            grep -A1 '"DriverName"' "$path" | grep -v DriverName
            break
        fi
    done
fi

echo ""
echo "========================================="
echo ""

# 2. 查看運行中的 Mattermost 進程
echo "🏃 運行中的 Mattermost 進程："
ps aux | grep -i mattermost | grep -v grep | head -3

echo ""
echo "========================================="
echo ""

# 3. 查看環境變數
echo "🔧 環境變數 (如果有)："
env | grep -E "MM_SQLSETTINGS|DB_|DATABASE" 2>/dev/null || echo "沒有設定環境變數"

echo ""
echo "========================================="
echo ""

# 4. 查看 PostgreSQL 服務狀態
echo "🐘 PostgreSQL 服務狀態："
if command -v psql &> /dev/null; then
    sudo -u postgres psql -c "SELECT version();" 2>/dev/null | head -1 || echo "無法連接到 PostgreSQL"
    echo ""
    echo "資料庫列表："
    sudo -u postgres psql -c "\l" 2>/dev/null | grep mattermost || echo "找不到 mattermost 資料庫"
else
    echo "psql 未安裝或無法存取"
fi

echo ""
echo "========================================="
echo ""

# 5. 網路連線檢查
echo "🌐 資料庫連線檢查："
# 從 config.json 提取主機和端口
if [ -f "$CONFIG_PATH" ]; then
    DB_HOST=$(grep -A1 '"DataSource"' "$CONFIG_PATH" | grep -v DataSource | sed 's/.*@\([^:]*\):.*/\1/')
    DB_PORT=$(grep -A1 '"DataSource"' "$CONFIG_PATH" | grep -v DataSource | sed 's/.*:\([0-9]*\)\/.*/\1/')
    
    if [ ! -z "$DB_HOST" ] && [ ! -z "$DB_PORT" ]; then
        echo "檢查連線到 $DB_HOST:$DB_PORT ..."
        nc -zv "$DB_HOST" "$DB_PORT" 2>&1 | head -1
    fi
fi

echo ""
echo "========================================="
echo "💡 建議的操作："
echo ""
echo "1. 查看完整設定："
echo "   cat $CONFIG_PATH | jq '.SqlSettings'"
echo ""
echo "2. 測試資料庫連線："
echo "   psql -h localhost -U mmuser -d mattermost -c 'SELECT version();'"
echo ""
echo "3. 查看 Mattermost 日誌："
echo "   tail -f /srv/gopath/src/github.com/zacmm/zacmm2025/server/logs/mattermost.log"
echo ""
echo "4. 更安全的運行方式："
echo "   cd /srv/gopath/src/github.com/zacmm/zacmm2025/server"
echo "   make build"
echo "   ./bin/mattermost -c config/config.json"