#!/bin/bash

echo "🔧 診斷正式環境配置問題"
echo "====================="
echo ""

# 連線資訊
DB_HOST="34.143.235.227"
DB_PORT="3306"
DB_USER="mmuser"
DB_PASS="mmpass"
DB_NAME="mattermost_dev"

echo "步驟 1: 檢查 system_admin 角色的完整權限"
echo "======================================"

mysql -h $DB_HOST -P $DB_PORT -u $DB_USER -p$DB_PASS $DB_NAME << 'EOF'
SELECT name, 
       CASE 
           WHEN permissions LIKE '%manage_system%' THEN 'HAS_MANAGE_SYSTEM'
           ELSE 'MISSING_MANAGE_SYSTEM'
       END as manage_system_status,
       CASE 
           WHEN permissions LIKE '%sysconsole_read_about%' THEN 'HAS_SYSCONSOLE_READ'
           ELSE 'MISSING_SYSCONSOLE_READ'
       END as sysconsole_status,
       LENGTH(permissions) as total_perm_length
FROM Roles 
WHERE name = 'system_admin';
EOF

echo ""
echo "步驟 2: 檢查用戶是否正確分配到 system_admin 角色"
echo "=============================================="

mysql -h $DB_HOST -P $DB_PORT -u $DB_USER -p$DB_PASS $DB_NAME << 'EOF'
-- 檢查 plusplus 用戶的詳細信息
SELECT u.id, u.username, u.email, u.roles, u.emailverified, u.deleteat
FROM Users u 
WHERE u.username = 'plusplus';

-- 檢查是否有 system_admin 權限的其他用戶
SELECT u.id, u.username, u.roles
FROM Users u 
WHERE u.roles LIKE '%system_admin%'
LIMIT 5;
EOF

echo ""
echo "步驟 3: 檢查系統配置設定"
echo "===================="

mysql -h $DB_HOST -P $DB_PORT -u $DB_USER -p$DB_PASS $DB_NAME << 'EOF'
-- 檢查系統配置
SELECT Name, Value 
FROM Systems 
WHERE Name IN ('EnableCustomUserStatuses', 'AuthenticationSettings', 'ServiceSettings')
LIMIT 10;
EOF

echo ""
echo "💡 診斷建議："
echo "1. 如果 system_admin 角色缺少權限，需要修復角色權限"
echo "2. 如果用戶角色分配正確但仍無權限，可能是配置或快取問題"
echo "3. 檢查正式環境的 Mattermost 是否正確讀取資料庫配置"