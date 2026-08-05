#!/bin/bash

echo "🔧 建立新的系統管理員帳號"
echo "========================"
echo ""

# 資料庫連線資訊
DB_HOST="34.143.235.227"
DB_PORT="3306"
DB_USER="mmuser"
DB_PASS="mmpass"
DB_NAME="mattermost_dev"

# 新用戶資訊
NEW_USERNAME="playplus"
NEW_PASSWORD="00000000"
NEW_EMAIL="playplus@playplus.com.tw"

echo "步驟 1: 生成必要的 ID 和密碼雜湊"
echo "-------------------------------"

# 生成唯一的用戶 ID (26個字符的隨機字串)
USER_ID=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 26 | head -n 1)
echo "用戶 ID: $USER_ID"

# 使用 bcrypt 生成密碼雜湊 (Mattermost 使用 bcrypt)
# 注意：這需要在 Mattermost 伺服器上執行或使用正確的工具
echo ""
echo "步驟 2: 在資料庫中建立用戶"
echo "------------------------"

mysql -h $DB_HOST -P $DB_PORT -u $DB_USER -p$DB_PASS $DB_NAME << EOF
-- 先檢查用戶是否已存在
SELECT id, username, email FROM Users WHERE username = '$NEW_USERNAME';

-- 複製 plusplus 的設定來建立新用戶
INSERT INTO Users (
    Id, CreateAt, UpdateAt, DeleteAt, Username, Password, 
    Email, EmailVerified, Nickname, FirstName, LastName, 
    Position, Roles, NotifyProps, Props, Locale, 
    Timezone, MfaActive, MfaSecret
)
SELECT 
    '$USER_ID',
    UNIX_TIMESTAMP() * 1000,
    UNIX_TIMESTAMP() * 1000,
    0,
    '$NEW_USERNAME',
    '\$2a\$10\$5sETOY0JKCDT8sd3UhYPVe\/GXS3tuGxfznYbEAKDSZZ\/.zM3Mqmda',  -- 這是 "00000000" 的 bcrypt 雜湊
    '$NEW_EMAIL',
    1,
    '$NEW_USERNAME',
    'Play',
    'Plus',
    '',
    'system_admin system_user',
    NotifyProps,
    Props,
    'zh-TW',
    Timezone,
    0,
    ''
FROM Users 
WHERE username = 'plusplus'
LIMIT 1;

-- 驗證用戶是否建立成功
SELECT id, username, email, roles FROM Users WHERE username = '$NEW_USERNAME';
EOF

echo ""
echo "步驟 3: 設定用戶偏好設定"
echo "---------------------"

mysql -h $DB_HOST -P $DB_PORT -u $DB_USER -p$DB_PASS $DB_NAME << EOF
-- 複製 plusplus 的偏好設定
INSERT INTO Preferences (UserId, Category, Name, Value)
SELECT 
    '$USER_ID',
    Category,
    Name,
    Value
FROM Preferences
WHERE UserId = (SELECT Id FROM Users WHERE Username = 'plusplus')
ON DUPLICATE KEY UPDATE Value = VALUES(Value);

-- 確認偏好設定
SELECT COUNT(*) as preference_count FROM Preferences WHERE UserId = '$USER_ID';
EOF

echo ""
echo "✅ 帳號建立完成！"
echo "==============="
echo ""
echo "新帳號資訊："
echo "  用戶名稱: $NEW_USERNAME"
echo "  密碼: $NEW_PASSWORD"
echo "  電子郵件: $NEW_EMAIL"
echo "  權限: system_admin (系統管理員)"
echo ""
echo "請登入測試: https://mattermost.playplus.com.tw"