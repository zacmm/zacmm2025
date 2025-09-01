#!/bin/bash

echo "🔧 設定 Mattermost 系統服務"
echo "========================="

# 檢查目錄
if [ ! -d "webapp" ] || [ ! -d "server" ] || [ ! -f "README.md" ]; then
    echo "❌ 請在專案根目錄執行"
    exit 1
fi

PROJECT_ROOT=$(pwd)

echo "1️⃣ 創建 systemd 服務檔案"

sudo tee /etc/systemd/system/mattermost.service > /dev/null <<EOF
[Unit]
Description=Mattermost
After=network.target
After=mysql.service
Requires=mysql.service

[Service]
Type=notify
ExecStart=$PROJECT_ROOT/server/bin/mattermost -c $PROJECT_ROOT/server/config/config.json
TimeoutStartSec=3600
KillMode=mixed
Restart=always
RestartSec=10
WorkingDirectory=$PROJECT_ROOT/server
User=mattermost
Group=mattermost
LimitNOFILE=49152

[Install]
WantedBy=multi-user.target
EOF

echo "✅ 服務檔案已創建"

echo "2️⃣ 重新載入 systemd"
sudo systemctl daemon-reload

echo "3️⃣ 啟用自動啟動"
sudo systemctl enable mattermost.service

echo "✅ Mattermost 服務設定完成！"
echo ""
echo "🎛️  服務管理指令："
echo "  啟動服務: sudo systemctl start mattermost"
echo "  停止服務: sudo systemctl stop mattermost"
echo "  重啟服務: sudo systemctl restart mattermost"
echo "  查看狀態: sudo systemctl status mattermost"
echo "  查看日誌: sudo journalctl -u mattermost -f"
echo ""
echo "💡 現在重開機後服務會自動啟動"