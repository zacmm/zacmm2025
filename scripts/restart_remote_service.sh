#!/bin/bash

echo "🔄 重新啟動遠端 Mattermost 服務"
echo "==============================="
echo ""

# 遠端伺服器資訊
REMOTE_HOST="34.143.235.227"
REMOTE_USER="chang"
SERVICE_PATH="/srv/gopath/src/github.com/zacmm/zacmm2025/server"

echo "步驟 1: 檢查遠端服務狀態"
echo "--------------------"

ssh $REMOTE_USER@$REMOTE_HOST "
    echo '檢查 Mattermost 進程...'
    ps aux | grep mattermost | grep -v grep || echo '沒有運行中的 Mattermost 進程'
    echo ''
    echo '檢查服務狀態...'
    sudo systemctl status mattermost.service --no-pager -l || echo '沒有 systemd 服務'
"

echo ""
echo "步驟 2: 停止現有服務"
echo "----------------"

ssh $REMOTE_USER@$REMOTE_HOST "
    echo '停止 systemd 服務 (如果存在)...'
    sudo systemctl stop mattermost.service 2>/dev/null || echo '沒有 systemd 服務需要停止'
    
    echo '停止任何運行中的 Mattermost 進程...'
    sudo pkill -f mattermost || echo '沒有進程需要停止'
    
    sleep 3
    
    echo '確認所有進程已停止...'
    ps aux | grep mattermost | grep -v grep || echo '✅ 所有 Mattermost 進程已停止'
"

echo ""
echo "步驟 3: 清理快取和臨時檔案"
echo "------------------------"

ssh $REMOTE_USER@$REMOTE_HOST "
    cd $SERVICE_PATH
    echo '清理日誌...'
    sudo truncate -s 0 logs/mattermost.log 2>/dev/null || echo '日誌檔案不存在'
    
    echo '清理快取...'
    rm -rf data/cache/* 2>/dev/null || echo '快取目錄不存在'
    
    echo '設定正確的檔案權限...'
    sudo chown -R mattermost:mattermost . 2>/dev/null || echo '權限設定略過'
"

echo ""
echo "步驟 4: 重新啟動服務"
echo "----------------"

ssh $REMOTE_USER@$REMOTE_HOST "
    cd $SERVICE_PATH
    
    # 嘗試使用 systemd 啟動
    if sudo systemctl start mattermost.service 2>/dev/null; then
        echo '✅ 使用 systemd 成功啟動服務'
        sleep 5
        sudo systemctl status mattermost.service --no-pager -l
    else
        echo '使用手動方式啟動...'
        sudo -u mattermost ./bin/mattermost -c config/config.json > /dev/null 2>&1 &
        sleep 5
        
        if ps aux | grep -v grep | grep mattermost > /dev/null; then
            echo '✅ 手動啟動成功'
        else
            echo '❌ 啟動失敗，檢查設定檔'
            exit 1
        fi
    fi
"

echo ""
echo "步驟 5: 驗證服務狀態"
echo "----------------"

echo "等待服務完全啟動..."
sleep 10

ssh $REMOTE_USER@$REMOTE_HOST "
    echo '檢查進程狀態...'
    ps aux | grep mattermost | grep -v grep
    
    echo ''
    echo '檢查端口監聽狀態...'
    netstat -tlnp | grep :8065 || ss -tlnp | grep :8065
    
    echo ''
    echo '檢查最新日誌...'
    tail -10 $SERVICE_PATH/logs/mattermost.log 2>/dev/null || echo '日誌檔案還未產生'
"

echo ""
echo "🎉 服務重啟完成！"
echo "==============="
echo ""
echo "💡 測試步驟："
echo "   1. 等待 30 秒讓服務完全啟動"
echo "   2. 瀏覽器開啟: http://34.143.235.227:8065"
echo "   3. 使用 plusplus 帳號登入測試"
echo "   4. 檢查系統控制台是否可以存取"