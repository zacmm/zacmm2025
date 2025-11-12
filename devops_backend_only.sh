#!/bin/bash

echo "🔧 Mattermost 後端快速部署"
echo "====================="
echo "僅編譯和部署後端服務"
echo ""

# 檢查目錄
if [ ! -d "server" ] || [ ! -f "README.md" ]; then
    echo "❌ 請在專案根目錄執行"
    exit 1
fi

echo "1️⃣ 編譯後端（服務繼續運行中...）"
cd server || { echo "❌ 無法進入 server 目錄"; exit 1; }

# 預先下載依賴
echo "📦 下載 Go 模組依賴..."
timeout 300 go mod download || { echo "⚠️  依賴下載超時或失敗，繼續嘗試編譯..."; }

# 編譯後端
echo "🔨 開始編譯 mattermost binary..."
echo "⏱️  預計需要 2-3 分鐘"

# 設定編譯參數
export GOOS=linux
export GOARCH=amd64
export GOMAXPROCS=2

# 獲取編譯資訊
BUILD_NUMBER=${BUILD_NUMBER:-prod}
BUILD_DATE=$(date -u)
BUILD_HASH=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
LDFLAGS="-X 'github.com/mattermost/mattermost/server/public/model.BuildNumber=${BUILD_NUMBER}' \
         -X 'github.com/mattermost/mattermost/server/public/model.BuildDate=${BUILD_DATE}' \
         -X 'github.com/mattermost/mattermost/server/public/model.BuildHash=${BUILD_HASH}'"

# 編譯
mkdir -p bin
if timeout 600 go build -v \
    -o bin/mattermost \
    -trimpath \
    -tags 'sourceavailable production' \
    -ldflags "${LDFLAGS}" \
    ./cmd/mattermost 2>&1 | tail -20; then
    echo "✅ 後端編譯成功"
else
    EXITCODE=$?
    echo "❌ 後端編譯失敗（退出碼: $EXITCODE）"
    if [ $EXITCODE -eq 124 ]; then
        echo "⚠️  編譯超時（超過 10 分鐘）"
    fi
    cd ..
    exit 1
fi

cd ..
echo "✅ 編譯完成！準備重啟服務..."

echo ""
echo "2️⃣ 快速重啟服務（預計停機時間 < 10 秒）"
echo "⏱️  停止舊版本..."
sudo systemctl stop mattermost 2>/dev/null || echo "systemctl 停止失敗或未使用"
sleep 1

# 強制終止所有殘留的 mattermost 進程
sudo pkill -9 -f "bin/mattermost" 2>/dev/null || echo "無殘留進程"
sleep 1

# 確認進程已完全停止
if ps aux | grep -v grep | grep "bin/mattermost" > /dev/null; then
    echo "⚠️  警告：仍有 mattermost 進程運行，強制終止中..."
    sudo killall -9 mattermost 2>/dev/null
    sleep 1
fi
echo "✅ 舊版本已停止"

echo "⏱️  啟動新版本..."
sudo chown -R mattermost:mattermost . 2>/dev/null || true

if sudo systemctl start mattermost 2>/dev/null; then
    echo "✅ 使用 systemd 啟動"
else
    echo "⚠️  systemd 啟動失敗，使用直接啟動"
    cd server
    sudo -u mattermost ./bin/mattermost -c config/config.json > /dev/null 2>&1 &
    cd ..
fi

echo "⏱️  等待服務啟動..."
sleep 5

echo ""
echo "3️⃣ 驗證部署"
if ps aux | grep -v grep | grep "bin/mattermost" > /dev/null; then
    echo "✅ 服務已成功啟動"
    netstat -tlnp | grep :8065 2>/dev/null || ss -tlnp | grep :8065 2>/dev/null || true
else
    echo "❌ 啟動失敗，請檢查日誌"
    echo "日誌查看: sudo journalctl -u mattermost -n 50"
    exit 1
fi

echo ""
echo "🎉 後端部署完成！"
echo "📊 停機時間: < 10 秒"
echo "🌐 訪問: https://newchat.bbnamg.com"
echo ""
echo "管理指令："
echo "  停止: sudo systemctl stop mattermost"
echo "  狀態: sudo systemctl status mattermost"
echo "  日誌: sudo journalctl -u mattermost -f"
