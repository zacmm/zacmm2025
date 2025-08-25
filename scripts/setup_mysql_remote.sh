#!/bin/bash

echo "🔧 MySQL 遠端連線設定腳本"
echo "========================="
echo ""

# 檢查是否為 root 用戶
if [ "$EUID" -ne 0 ]; then
    echo "❌ 請使用 root 權限執行此腳本"
    echo "   sudo $0"
    exit 1
fi

echo "步驟 1: 修改 MySQL 設定檔"
echo "------------------------"

# 找到 MySQL 設定檔
MYSQL_CONFIG="/etc/mysql/mysql.conf.d/mysqld.cnf"
if [ ! -f "$MYSQL_CONFIG" ]; then
    MYSQL_CONFIG="/etc/mysql/my.cnf"
fi
if [ ! -f "$MYSQL_CONFIG" ]; then
    MYSQL_CONFIG="/etc/my.cnf"
fi

if [ -f "$MYSQL_CONFIG" ]; then
    echo "✅ 找到 MySQL 設定檔: $MYSQL_CONFIG"
    
    # 備份設定檔
    cp "$MYSQL_CONFIG" "$MYSQL_CONFIG.backup"
    echo "✅ 已備份設定檔到: $MYSQL_CONFIG.backup"
    
    # 修改 bind-address 允許所有 IP 連線
    sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' "$MYSQL_CONFIG"
    echo "✅ 已修改 bind-address = 0.0.0.0"
    
    # 確保沒有 skip-networking
    sed -i 's/^skip-networking/#skip-networking/' "$MYSQL_CONFIG"
    echo "✅ 已註解 skip-networking"
    
else
    echo "❌ 找不到 MySQL 設定檔，請手動修改"
    echo "   通常位於: /etc/mysql/mysql.conf.d/mysqld.cnf"
    echo "   修改: bind-address = 0.0.0.0"
fi

echo ""
echo "步驟 2: 設定防火牆"
echo "----------------"

# 檢查防火牆類型並開放 3306 端口
if command -v ufw &> /dev/null; then
    echo "使用 UFW 防火牆"
    ufw allow 3306
    ufw status | grep 3306
    echo "✅ UFW 已開放 3306 端口"
elif command -v firewall-cmd &> /dev/null; then
    echo "使用 firewalld 防火牆"
    firewall-cmd --permanent --add-port=3306/tcp
    firewall-cmd --reload
    firewall-cmd --list-ports | grep 3306
    echo "✅ firewalld 已開放 3306 端口"
elif command -v iptables &> /dev/null; then
    echo "使用 iptables 防火牆"
    iptables -A INPUT -p tcp --dport 3306 -j ACCEPT
    echo "✅ iptables 已開放 3306 端口"
    echo "⚠️  注意：iptables 規則可能需要持久化保存"
else
    echo "⚠️  無法識別防火牆類型，請手動開放 3306 端口"
fi

echo ""
echo "步驟 3: 執行 MySQL 用戶設定"
echo "------------------------"

# 執行 SQL 腳本
if command -v mysql &> /dev/null; then
    echo "請輸入 MySQL root 密碼來執行用戶設定："
    mysql -u root -p < "$(dirname "$0")/setup_mysql_remote.sql"
    if [ $? -eq 0 ]; then
        echo "✅ MySQL 用戶設定完成"
    else
        echo "❌ MySQL 用戶設定失敗"
    fi
else
    echo "❌ 找不到 mysql 命令，請手動執行："
    echo "   mysql -u root -p < $(dirname "$0")/setup_mysql_remote.sql"
fi

echo ""
echo "步驟 4: 重啟 MySQL 服務"
echo "--------------------"

if systemctl is-active --quiet mysql; then
    systemctl restart mysql
    echo "✅ MySQL 服務已重啟"
elif systemctl is-active --quiet mysqld; then
    systemctl restart mysqld
    echo "✅ MySQL 服務已重啟"
else
    echo "⚠️  請手動重啟 MySQL 服務"
fi

echo ""
echo "步驟 5: 測試連線"
echo "---------------"

echo "測試本地連線："
mysql -u mmuser -pmmpass -e "SELECT 'MySQL 本地連線成功！' as Status;" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ 本地連線測試成功"
else
    echo "❌ 本地連線測試失敗"
fi

echo ""
echo "🎉 MySQL 遠端連線設定完成！"
echo "=========================="
echo ""
echo "連線資訊："
echo "  主機: $(hostname -I | awk '{print $1}') 或 34.143.235.227"
echo "  端口: 3306"
echo "  用戶: mmuser"
echo "  密碼: mmpass"
echo "  資料庫: mattermost_dev"
echo ""
echo "測試連線命令："
echo "  mysql -h 34.143.235.227 -u mmuser -pmmpass -D mattermost_dev"
echo ""
echo "⚠️  安全提醒："
echo "   - 此設定允許任何 IP 連線，生產環境請限制 IP"
echo "   - 建議修改預設密碼"
echo "   - 定期檢查連線日誌"