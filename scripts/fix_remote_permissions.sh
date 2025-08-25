#!/bin/bash

echo "🔧 修復遠端 Mattermost 權限標籤"
echo "================================"
echo ""

# 連線資訊
DB_HOST="34.143.235.227"
DB_PORT="3306"
DB_USER="mmuser"
DB_PASS="mmpass"
DB_NAME="mattermost_dev"

echo "步驟 1: 檢查現有的錯誤權限標籤"
echo "------------------------------"

mysql -h $DB_HOST -P $DB_PORT -u $DB_USER -p$DB_PASS $DB_NAME << 'EOF'
SELECT id, name, 
       CASE 
           WHEN permissions LIKE '%sysconsole_read_*_read%' THEN 'HAS_MALFORMED_TAGS'
           ELSE 'OK'
       END as status
FROM Roles 
WHERE name IN ('system_admin', 'system_manager', 'system_read_only_admin', 'system_user_manager');
EOF

echo ""
echo "步驟 2: 執行權限標籤修復"
echo "----------------------"

echo "正在執行 SQL 修復腳本..."
mysql -h $DB_HOST -P $DB_PORT -u $DB_USER -p$DB_PASS $DB_NAME < "$(dirname "$0")/fix_permission_tags.sql"

if [ $? -eq 0 ]; then
    echo "✅ 權限標籤修復完成"
else
    echo "❌ 權限標籤修復失敗"
    exit 1
fi

echo ""
echo "步驟 3: 驗證修復結果"
echo "------------------"

mysql -h $DB_HOST -P $DB_PORT -u $DB_USER -p$DB_PASS $DB_NAME << 'EOF'
-- 檢查是否還有錯誤的權限標籤
SELECT COUNT(*) as malformed_count 
FROM Roles 
WHERE permissions LIKE '%sysconsole_read_*_read%';

-- 顯示系統角色的權限狀態
SELECT id, name, 
       LENGTH(permissions) as permissions_length,
       SUBSTRING(permissions, 1, 100) as permissions_preview
FROM Roles 
WHERE name IN ('system_admin', 'system_manager', 'system_read_only_admin', 'system_user_manager');
EOF

echo ""
echo "🎉 權限標籤修復完成！"
echo "===================="
echo ""
echo "⚠️  重要：修復完成後需要："
echo "   1. 重新啟動遠端 Mattermost 服務"
echo "   2. 清除快取讓變更生效"
echo "   3. 測試管理員 API 是否正常運作"
echo ""
echo "下一步執行："
echo "   cd /srv/gopath/src/github.com/zacmm/zacmm2025/server"
echo "   sudo systemctl restart mattermost.service"