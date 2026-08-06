#!/bin/bash

echo "🔑 使用 Mattermost CLI 重設 playplus 密碼"
echo "========================================"
echo ""

# 切換到 Mattermost 服務目錄
MATTERMOST_PATH="/srv/gopath/src/github.com/zacmm/zacmm2025/server"

echo "方法 1: 使用 mattermost 命令重設密碼"
echo "=================================="

echo "請在遠端伺服器執行以下命令："
echo ""
echo "cd $MATTERMOST_PATH"
echo ""
echo "# 停止服務"
echo "sudo pkill -f mattermost"
echo ""
echo "# 使用 CLI 重設密碼"
echo "sudo -u mattermost ./bin/mattermost user password playplus 00000000 --config config/config.json"
echo ""
echo "# 重新啟動服務"
echo "sudo -u mattermost nohup ./bin/mattermost -c config/config.json > logs/mattermost.log 2>&1 &"
echo ""

echo "方法 2: 使用 mmctl 工具 (如果已安裝)"
echo "================================="

echo "# 建置 mmctl"
echo "make mmctl-build"
echo ""
echo "# 設定 mmctl"
echo "./bin/mmctl auth login http://localhost:8065"
echo ""
echo "# 重設密碼"
echo "./bin/mmctl user reset-password playplus --password 00000000"
echo ""

echo "方法 3: 建立全新的 playplus 帳號"
echo "=============================="

echo "# 刪除現有帳號"
echo "sudo -u mattermost ./bin/mattermost user delete playplus --confirm --config config/config.json"
echo ""
echo "# 建立新帳號"
echo "sudo -u mattermost ./bin/mattermost user create --email playplus@playplus.com.tw --username playplus --password 00000000 --config config/config.json"
echo ""
echo "# 設為管理員"
echo "sudo -u mattermost ./bin/mattermost roles system_admin playplus --config config/config.json"
echo ""

echo "💡 建議："
echo "1. 先嘗試方法 1 (最簡單)"
echo "2. 如果不行再試方法 3 (重新建立)"
echo "3. 執行完成後測試登入"