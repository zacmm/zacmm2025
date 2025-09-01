#!/bin/bash

echo "🚀 Mattermost 生產部署"
echo "====================="

# 檢查目錄
if [ ! -d "webapp" ] || [ ! -d "server" ] || [ ! -f "README.md" ]; then
    echo "❌ 請在專案根目錄執行"
    exit 1
fi

echo "1️⃣ 停止服務"
sudo systemctl stop mattermost 2>/dev/null || sudo pkill -f mattermost || echo "無運行中的服務"
sleep 2

echo "2️⃣ 編譯前端"
cd server && make build && cd .. || { echo "❌ 前端編譯失敗"; exit 1; }

echo "3️⃣ 編譯後端"
cd server && make build-linux && cd .. || { echo "❌ 後端編譯失敗"; exit 1; }

echo "4️⃣ 啟動服務"
sudo chown -R mattermost:mattermost . 2>/dev/null || true
if sudo systemctl start mattermost 2>/dev/null; then
    echo "使用 systemd 啟動"
else
    echo "使用直接啟動"
    cd server && sudo -u mattermost ./bin/mattermost -c config/config.json > /dev/null 2>&1 & && cd ..
fi

echo "等待啟動..."
sleep 5

echo "5️⃣ 檢查狀態"
if ps aux | grep -v grep | grep mattermost > /dev/null; then
    echo "✅ 服務已啟動"
    netstat -tlnp | grep :8065 2>/dev/null || ss -tlnp | grep :8065 2>/dev/null
else
    echo "❌ 啟動失敗"
    exit 1
fi

echo ""
echo "🎉 部署完成！訪問: https://mattermost.playplus.com.tw"
echo "管理指令："
echo "  停止: sudo systemctl stop mattermost (或 sudo pkill -f mattermost)"
echo "  狀態: sudo systemctl status mattermost"
echo "  日誌: sudo journalctl -u mattermost -f"