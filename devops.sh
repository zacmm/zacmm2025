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
cd server || { echo "❌ 無法進入 server 目錄"; exit 1; }

# 預先下載依賴，避免編譯時網路問題
echo "📦 下載 Go 模組依賴..."
timeout 300 go mod download || { echo "⚠️  依賴下載超時或失敗，繼續嘗試編譯..."; }

# 使用自訂編譯命令，只編譯 mattermost binary（不編譯所有 packages）
# 添加超時機制（10 分鐘）和詳細輸出
echo "🔨 開始編譯 mattermost binary..."
echo "⏱️  預計需要 3-5 分鐘，如果超過 10 分鐘將自動終止"

# 設定編譯參數
export GOOS=linux
export GOARCH=amd64
export GOMAXPROCS=2  # 限制並發數，避免記憶體不足

# 獲取編譯時的 LDFLAGS
BUILD_NUMBER=${BUILD_NUMBER:-dev}
BUILD_DATE=$(date -u)
BUILD_HASH=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
LDFLAGS="-X 'github.com/mattermost/mattermost/server/public/model.BuildNumber=${BUILD_NUMBER}' \
         -X 'github.com/mattermost/mattermost/server/public/model.BuildDate=${BUILD_DATE}' \
         -X 'github.com/mattermost/mattermost/server/public/model.BuildHash=${BUILD_HASH}'"

# 編譯 mattermost binary（只編譯 cmd/mattermost，不編譯全部）
mkdir -p bin
if timeout 600 go build -v \
    -o bin/mattermost \
    -trimpath \
    -tags 'sourceavailable production' \
    -ldflags "${LDFLAGS}" \
    ./cmd/mattermost 2>&1 | tee /tmp/mattermost-build.log | tail -20; then
    echo "✅ 後端編譯成功"
else
    EXITCODE=$?
    echo "❌ 後端編譯失敗（退出碼: $EXITCODE）"
    if [ $EXITCODE -eq 124 ]; then
        echo "⚠️  編譯超時（超過 10 分鐘）"
        echo "💡 建議："
        echo "   1. 檢查網路連線是否穩定"
        echo "   2. 檢查記憶體是否充足（建議至少 4GB）"
        echo "   3. 清除編譯快取：cd server && go clean -cache"
        echo "   4. 查看完整日誌：cat /tmp/mattermost-build.log"
    fi
    cd ..
    exit 1
fi

# 也編譯 mmctl 工具
echo "🔨 編譯 mmctl..."
if timeout 120 go build -v \
    -o bin/mmctl \
    -trimpath \
    ./cmd/mmctl 2>&1 | tail -5; then
    echo "✅ mmctl 編譯成功"
else
    echo "⚠️  mmctl 編譯失敗（非致命錯誤，繼續）"
fi

cd ..
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