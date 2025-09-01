#!/bin/bash

echo "🔧 修復 playplus 帳號密碼"
echo "========================"
echo ""

# 資料庫連線資訊
DB_HOST="34.143.235.227"
DB_PORT="3306"
DB_USER="mmuser"
DB_PASS="mmpass"
DB_NAME="mattermost_dev"

echo "步驟 1: 複製 plusplus 的密碼雜湊給 playplus"
echo "----------------------------------------"

mysql -h $DB_HOST -P $DB_PORT -u $DB_USER -p$DB_PASS $DB_NAME << 'EOF'
-- 先檢查兩個用戶的狀態
SELECT username, id, email, roles, deleteat FROM Users 
WHERE username IN ('plusplus', 'playplus');

-- 複製 plusplus 的密碼給 playplus (兩個都是 00000000)
UPDATE Users 
SET Password = (SELECT Password FROM Users WHERE username = 'plusplus')
WHERE username = 'playplus';

-- 確保帳號沒有被刪除且已驗證
UPDATE Users 
SET 
    DeleteAt = 0,
    EmailVerified = 1,
    Roles = 'system_admin system_user'
WHERE username = 'playplus';

-- 驗證更新結果
SELECT username, id, email, roles, emailverified, deleteat 
FROM Users 
WHERE username = 'playplus';
EOF

echo ""
echo "步驟 2: 確保用戶 ID 正確"
echo "----------------------"

mysql -h $DB_HOST -P $DB_PORT -u $DB_USER -p$DB_PASS $DB_NAME << 'EOF'
-- 如果 ID 是空的，生成一個新的
UPDATE Users 
SET Id = LOWER(CONCAT(
    SUBSTRING(MD5(RAND()), 1, 8),
    SUBSTRING(MD5(RAND()), 1, 4),
    SUBSTRING(MD5(RAND()), 1, 4),
    SUBSTRING(MD5(RAND()), 1, 4),
    SUBSTRING(MD5(RAND()), 1, 12)
))
WHERE username = 'playplus' AND (Id IS NULL OR Id = '');

-- 顯示最終結果
SELECT username, id, email, roles FROM Users WHERE username = 'playplus';
EOF

echo ""
echo "✅ 密碼修復完成！"
echo "==============="
echo ""
echo "帳號資訊："
echo "  用戶名稱: playplus"
echo "  密碼: 00000000 (與 plusplus 相同)"
echo ""
echo "請重新嘗試登入"