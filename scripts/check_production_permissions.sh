#!/bin/bash

echo "🔍 檢查正式環境權限問題"
echo "======================="
echo ""

# 假設正式環境也使用相同的資料庫
DB_HOST="34.143.235.227"
DB_PORT="3306"
DB_USER="mmuser"
DB_PASS="mmpass"
DB_NAME="mattermost_dev"

echo "步驟 1: 檢查正式環境使用者權限"
echo "----------------------------"

mysql -h $DB_HOST -P $DB_PORT -u $DB_USER -p$DB_PASS $DB_NAME << 'EOF'
-- 查找 plusplus 用戶
SELECT u.id, u.username, u.email, u.roles
FROM Users u 
WHERE u.username = 'plusplus';

-- 檢查用戶的角色分配
SELECT ur.userid, ur.roleid, r.name as role_name
FROM UserRoles ur
JOIN Roles r ON ur.roleid = r.id
JOIN Users u ON ur.userid = u.id
WHERE u.username = 'plusplus';

-- 檢查系統管理員角色的權限
SELECT r.id, r.name, LENGTH(r.permissions) as perm_length,
       CASE 
           WHEN r.permissions LIKE '%sysconsole_read_*_read%' THEN 'HAS_MALFORMED'
           WHEN r.permissions LIKE '%manage_system%' THEN 'HAS_MANAGE_SYSTEM'
           ELSE 'MISSING_ADMIN_PERMS'
       END as permission_status
FROM Roles r 
WHERE r.name = 'system_admin';
EOF

echo ""
echo "步驟 2: 檢查是否有錯誤的權限標籤"
echo "------------------------------"

mysql -h $DB_HOST -P $DB_PORT -u $DB_USER -p$DB_PASS $DB_NAME << 'EOF'
-- 查找所有包含錯誤權限標籤的角色
SELECT id, name, 
       CASE 
           WHEN permissions LIKE '%sysconsole_read_*_read%' THEN 'MALFORMED_TAGS_FOUND'
           ELSE 'OK'
       END as status
FROM Roles;
EOF

echo ""
echo "💡 如果發現問題，請執行修復腳本"