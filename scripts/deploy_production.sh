#!/bin/bash

echo "🚀 Mattermost 生產環境部署腳本"
echo "================================="
echo ""

# 設定變數
PROJECT_ROOT="/srv/gopath/src/github.com/zacmm/zacmm2025"
WEBAPP_DIR="$PROJECT_ROOT/webapp"
SERVER_DIR="$PROJECT_ROOT/server"
CONFIG_FILE="$SERVER_DIR/config/config.json"

# 檢查是否在正確的目錄
if [ ! -d "$PROJECT_ROOT" ]; then
    echo "❌ 錯誤: 找不到專案目錄 $PROJECT_ROOT"
    exit 1
fi

echo "步驟 1: 停止現有服務"
echo "-------------------"
echo "正在停止所有 mattermost 進程..."

# 停止 systemd 服務（如果存在）
sudo systemctl stop mattermost.service 2>/dev/null || echo "沒有 systemd 服務需要停止"

# 殺掉所有 mattermost 進程
sudo pkill -f mattermost || echo "沒有運行中的 mattermost 進程"

# 等待進程完全停止
sleep 3

# 確認進程已停止
if ps aux | grep -v grep | grep mattermost > /dev/null; then
    echo "⚠️  警告: 仍有 mattermost 進程在運行，強制終止..."
    sudo pkill -9 -f mattermost
    sleep 2
fi

echo "✅ 所有舊服務已停止"
echo ""

echo "步驟 2: 更新代碼"
echo "---------------"
cd "$PROJECT_ROOT"

echo "當前分支和提交："
git branch --show-current
git log --oneline -1

echo "正在拉取最新代碼..."
git pull origin main

if [ $? -ne 0 ]; then
    echo "❌ Git pull 失敗，請檢查"
    exit 1
fi

echo "✅ 代碼更新完成"
echo ""

echo "步驟 3: 編譯前端"
echo "---------------"
cd "$WEBAPP_DIR"

echo "清理前端快取..."
make clean 2>/dev/null || npm run clean 2>/dev/null || echo "跳過清理"

echo "開始編譯前端..."
make build

if [ $? -ne 0 ]; then
    echo "❌ 前端編譯失敗"
    exit 1
fi

echo "✅ 前端編譯完成"
echo ""

echo "步驟 4: 編譯後端"
echo "---------------"
cd "$SERVER_DIR"

echo "清理後端編譯快取..."
rm -rf bin/* 2>/dev/null

echo "開始編譯後端 (Linux 版本)..."
make build-linux

if [ $? -ne 0 ]; then
    echo "❌ 後端編譯失敗"
    exit 1
fi

echo "✅ 後端編譯完成"
echo ""

echo "步驟 5: 檢查編譯結果"
echo "-------------------"
if [ -f "$SERVER_DIR/bin/mattermost" ]; then
    echo "✅ 找到 mattermost 二進制檔案"
    ls -la "$SERVER_DIR/bin/mattermost"
else
    echo "❌ 找不到 mattermost 二進制檔案"
    exit 1
fi

if [ -d "$WEBAPP_DIR/dist" ] && [ "$(ls -A $WEBAPP_DIR/dist 2>/dev/null)" ]; then
    echo "✅ 找到前端編譯產物"
    echo "前端檔案大小: $(du -sh $WEBAPP_DIR/dist | cut -f1)"
else
    echo "❌ 前端編譯產物不存在或為空"
    exit 1
fi

echo ""

echo "步驟 6: 啟動服務"
echo "---------------"

# 檢查配置檔案
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ 找不到配置檔案: $CONFIG_FILE"
    exit 1
fi

echo "使用配置檔案: $CONFIG_FILE"
echo "正在啟動 Mattermost 服務..."

# 設定正確的檔案權限
sudo chown -R mattermost:mattermost "$PROJECT_ROOT" 2>/dev/null || echo "跳過權限設定"

# 啟動服務（以 mattermost 使用者身分）
if id "mattermost" &>/dev/null; then
    echo "以 mattermost 使用者身分啟動服務..."
    sudo -u mattermost nohup "$SERVER_DIR/bin/mattermost" -c "$CONFIG_FILE" > /dev/null 2>&1 &
else
    echo "直接啟動服務..."
    nohup "$SERVER_DIR/bin/mattermost" -c "$CONFIG_FILE" > /dev/null 2>&1 &
fi

# 等待服務啟動
echo "等待服務啟動..."
sleep 10

echo ""

echo "步驟 7: 驗證部署"
echo "---------------"

# 檢查進程
echo "檢查 Mattermost 進程..."
if ps aux | grep -v grep | grep mattermost; then
    echo "✅ Mattermost 進程正在運行"
else
    echo "❌ Mattermost 進程未啟動"
    exit 1
fi

echo ""

# 檢查端口
echo "檢查端口 8065..."
if netstat -tlnp | grep :8065 2>/dev/null || ss -tlnp | grep :8065 2>/dev/null; then
    echo "✅ 端口 8065 正在監聽"
else
    echo "❌ 端口 8065 未監聽"
    exit 1
fi

echo ""

# 檢查日誌（最後 10 行）
echo "最新日誌："
echo "----------"
if [ -f "$SERVER_DIR/logs/mattermost.log" ]; then
    tail -10 "$SERVER_DIR/logs/mattermost.log"
else
    echo "日誌檔案尚未產生"
fi

echo ""
echo "🎉 部署完成！"
echo "============="
echo ""
echo "💡 測試步驟："
echo "   1. 等待 30 秒讓服務完全啟動"
echo "   2. 瀏覽器開啟: https://mattermost.playplus.com.tw"
echo "   3. 檢查系統控制台是否可以存取"
echo ""
echo "📋 服務資訊："
echo "   - 進程: $(ps aux | grep -v grep | grep mattermost | wc -l) 個"
echo "   - 配置: $CONFIG_FILE"
echo "   - 日誌: $SERVER_DIR/logs/mattermost.log"
echo ""
echo "🔧 管理指令："
echo "   停止服務: sudo pkill -f mattermost"
echo "   檢查狀態: ps aux | grep mattermost"
echo "   檢查日誌: tail -f $SERVER_DIR/logs/mattermost.log"