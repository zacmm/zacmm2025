#!/bin/bash

# 遠端伺服器設定
REMOTE_USER="root"  # 修改為你的遠端使用者
REMOTE_HOST="your-server-ip"  # 修改為你的遠端 IP
REMOTE_PATH="/srv/gopath/src/github.com/zacmm/zacmm2025"

echo "🚀 Mattermost 本地編譯 + 遠端部署"
echo "=================================="

# 檢查目錄
if [ ! -d "webapp" ] || [ ! -d "server" ] || [ ! -f "README.md" ]; then
    echo "❌ 請在專案根目錄執行"
    exit 1
fi

echo ""
echo "📋 請確認遠端伺服器設定："
echo "   使用者: $REMOTE_USER"
echo "   主機: $REMOTE_HOST"
echo "   路徑: $REMOTE_PATH"
echo ""
read -p "按 Enter 繼續，或 Ctrl+C 取消..."

echo ""
echo "1️⃣ 在本地編譯前端"
cd webapp && npm run build || { echo "❌ 前端編譯失敗"; exit 1; }
cd ..

echo ""
echo "2️⃣ 在本地編譯後端（Linux 版本）"
cd server && make build-linux || { echo "❌ 後端編譯失敗"; exit 1; }
cd ..

echo ""
echo "3️⃣ 推送代碼到遠端"
git push origin main || echo "⚠️ Git push 失敗，繼續..."

echo ""
echo "4️⃣ 上傳編譯產物到遠端"
echo "上傳前端靜態檔案..."
rsync -avz --delete webapp/dist/ ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/webapp/dist/

echo "上傳後端二進制檔案..."
rsync -avz server/bin/mattermost ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/server/bin/

echo ""
echo "5️⃣ 在遠端重啟服務"
ssh ${REMOTE_USER}@${REMOTE_HOST} << 'ENDSSH'
cd /srv/gopath/src/github.com/zacmm/zacmm2025

echo "停止服務..."
sudo systemctl stop mattermost 2>/dev/null || sudo pkill -f mattermost || echo "無運行中的服務"
sleep 2

echo "更新代碼..."
git pull origin main || echo "Git pull 失敗，使用已上傳的編譯產物"

echo "設定權限..."
sudo chown -R mattermost:mattermost . 2>/dev/null || true
chmod +x server/bin/mattermost

echo "啟動服務..."
if sudo systemctl start mattermost 2>/dev/null; then
    echo "✅ 使用 systemd 啟動"
else
    echo "使用直接啟動"
    cd server
    sudo -u mattermost ./bin/mattermost -c config/config.json > /dev/null 2>&1 &
    cd ..
fi

sleep 5

echo "檢查狀態..."
if ps aux | grep -v grep | grep mattermost > /dev/null; then
    echo "✅ 服務已啟動"
    netstat -tlnp 2>/dev/null | grep :8065 || ss -tlnp 2>/dev/null | grep :8065 || echo "無法檢查端口"
else
    echo "❌ 啟動失敗"
    exit 1
fi
ENDSSH

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 部署完成！訪問: https://mattermost.playplus.com.tw"
    echo ""
    echo "管理指令："
    echo "  查看狀態: ssh ${REMOTE_USER}@${REMOTE_HOST} 'sudo systemctl status mattermost'"
    echo "  查看日誌: ssh ${REMOTE_USER}@${REMOTE_HOST} 'sudo journalctl -u mattermost -f'"
    echo "  重啟服務: ssh ${REMOTE_USER}@${REMOTE_HOST} 'sudo systemctl restart mattermost'"
else
    echo "❌ 部署失敗"
    exit 1
fi
