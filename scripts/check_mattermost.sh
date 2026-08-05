#!/bin/bash

echo "=========================================="
echo "Mattermost 狀態檢查"
echo "時間: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# 1. 檢查進程
echo "1️⃣ 檢查 Mattermost 進程："
PROCESS=$(pgrep -af mattermost | grep -v grep | grep -v check_mattermost)
if [ -n "$PROCESS" ]; then
    echo "✅ Mattermost 進程正在運行"
    echo "$PROCESS"
else
    echo "❌ Mattermost 進程未運行"
fi
echo ""

# 2. 檢查端口
echo "2️⃣ 檢查端口 8065："
PORT_CHECK=$(lsof -i:8065 2>/dev/null)
if [ -n "$PORT_CHECK" ]; then
    echo "✅ 端口 8065 正在被使用"
    echo "$PORT_CHECK"
else
    echo "❌ 端口 8065 未被使用"
fi
echo ""

# 3. 測試 API
echo "3️⃣ 測試 API 回應："
API_RESPONSE=$(curl -s http://localhost:8065/api/v4/system/ping 2>/dev/null)
if [ "$API_RESPONSE" = '{"status":"OK"}' ]; then
    echo "✅ API 回應正常: $API_RESPONSE"
elif [ -n "$API_RESPONSE" ]; then
    echo "⚠️ API 有回應但不正常: $API_RESPONSE"
else
    echo "❌ API 無回應（可能還在啟動中或執行 migration）"
fi
echo ""

# 4. 檢查 MySQL migration
echo "4️⃣ 檢查 MySQL migration 狀態："
MIGRATION=$(mysql -u mmuser -pmmpass -h 34.87.11.83 -se "SELECT ID, TIME, STATE, LEFT(INFO, 60) FROM information_schema.PROCESSLIST WHERE INFO LIKE '%ALTER%' OR INFO LIKE '%migration%';" 2>/dev/null)
if [ -n "$MIGRATION" ]; then
    echo "⚠️ Migration 正在執行："
    echo "$MIGRATION"
else
    echo "✅ 沒有正在執行的 migration"
fi
echo ""

# 5. 檢查最近的日誌
echo "5️⃣ 最近的日誌（最後 10 行）："
if [ -f "/srv/gopath/src/github.com/zacmm/zacmm2025/server/logs/mattermost.log" ]; then
    tail -10 /srv/gopath/src/github.com/zacmm/zacmm2025/server/logs/mattermost.log
else
    echo "⚠️ 找不到日誌檔案"
fi
echo ""

echo "=========================================="
echo "檢查完成"
echo "=========================================="
