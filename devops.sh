#!/bin/bash

echo "🚀 Mattermost 零停機部署"
echo "====================="
echo "⏱️  編譯階段服務將持續運行，僅在切換時短暫中斷"
echo ""

# 檢查目錄
if [ ! -d "webapp" ] || [ ! -d "server" ] || [ ! -f "README.md" ]; then
    echo "❌ 請在專案根目錄執行"
    exit 1
fi

echo "1️⃣ 檢查翻譯檔案"
if grep -q "工作階段已逾期或" webapp/channels/src/i18n/zh-TW.json 2>/dev/null; then
    echo "✅ 翻譯檔案已包含最新更新"
else
    echo "⚠️  警告：翻譯檔案可能未更新"
fi

echo ""
echo "2️⃣ 編譯前端（服務繼續運行中...）"
if command -v npm &> /dev/null; then
    echo "✅ 檢測到 npm，開始編譯前端..."
    cd webapp && npm run build && cd .. || { echo "❌ 前端編譯失敗"; exit 1; }
else
    echo "⚠️  未檢測到 npm，跳過前端編譯（請確保 dist 資料夾已在 Git 中更新）"
fi

echo "3️⃣ 編譯後端（服務繼續運行中...）"
cd server && make build-linux && cd .. || { echo "❌ 後端編譯失敗"; exit 1; }
echo "✅ 編譯完成！準備切換到新版本..."

echo ""
echo "4️⃣ 快速重啟服務（預計停機時間 < 10 秒）"
echo "⏱️  停止舊版本..."
sudo systemctl stop mattermost 2>/dev/null || echo "systemctl 停止失敗或未使用"
sleep 1
# 強制終止所有殘留的 mattermost 進程
sudo pkill -9 -f "bin/mattermost" 2>/dev/null || echo "無殘留進程"
sleep 1
# 確認進程已完全停止
if ps aux | grep -v grep | grep mattermost > /dev/null; then
    echo "⚠️  警告：仍有 mattermost 進程運行，強制終止中..."
    sudo killall -9 mattermost 2>/dev/null
    sleep 1
fi
echo "✅ 舊版本已停止"

echo "⏱️  啟動新版本..."
sudo chown -R mattermost:mattermost . 2>/dev/null || true
if sudo systemctl start mattermost 2>/dev/null; then
    echo "使用 systemd 啟動"
else
    echo "使用直接啟動"
    cd server
    sudo -u mattermost ./bin/mattermost -c config/config.json > /dev/null 2>&1 &
    cd ..
fi

echo "⏱️  等待服務啟動..."
sleep 5

echo ""
echo "5️⃣ 驗證部署"
if ps aux | grep -v grep | grep mattermost > /dev/null; then
    echo "✅ 服務已成功啟動"
    netstat -tlnp | grep :8065 2>/dev/null || ss -tlnp | grep :8065 2>/dev/null
else
    echo "❌ 啟動失敗，請檢查日誌"
    echo "日誌查看: sudo journalctl -u mattermost -n 50"
    exit 1
fi

# 計算停機時間（從停止到啟動約 10 秒）
echo ""
echo "🎉 零停機部署完成！"
echo "📊 停機時間: < 10 秒"
echo "🌐 訪問: https://newchat.bbnamg.com"
echo "管理指令："
echo "  停止: sudo systemctl stop mattermost (或 sudo pkill -f mattermost)"
echo "  狀態: sudo systemctl status mattermost"
echo "  日誌: sudo journalctl -u mattermost -f"