#!/bin/bash
# =====================================================
# MySQL 線上 DDL 工具選擇檢查腳本
# 檢查 binlog 設定以決定使用 pt-osc 或 gh-ost
# =====================================================

DB_HOST="34.87.11.83"
DB_USER="mmuser"
DB_PASS="mmpass"
DB_NAME="mattermost_prod_local"

echo "=========================================="
echo "MySQL 線上 DDL 工具檢查"
echo "=========================================="
echo ""

# 1. 檢查基本資訊
echo "📊 1. MySQL 基本資訊："
mysql -h $DB_HOST -u $DB_USER -p"$DB_PASS" -e "
SELECT
    @@version as MySQL版本,
    @@version_comment as 版本註解
" 2>/dev/null

echo ""

# 2. 檢查 binlog 設定（決定性因素）
echo "🔍 2. Binlog 設定（關鍵）："
mysql -h $DB_HOST -u $DB_USER -p"$DB_PASS" -e "
SELECT
    @@log_bin as binlog已啟用,
    @@binlog_format as binlog格式,
    CASE
        WHEN @@log_bin = 1 AND @@binlog_format = 'ROW' THEN '✅ 可使用 gh-ost（推薦）'
        WHEN @@log_bin = 1 AND @@binlog_format != 'ROW' THEN '⚠️  binlog 格式需改為 ROW'
        WHEN @@log_bin = 0 THEN '❌ 只能使用 pt-online-schema-change'
    END as 建議
" 2>/dev/null

echo ""

# 3. 檢查當前 fulltext 設定
echo "📝 3. 當前 Fulltext 設定："
mysql -h $DB_HOST -u $DB_USER -p"$DB_PASS" -e "
SELECT
    @@innodb_ft_min_token_size as 最小token長度,
    @@innodb_ft_max_token_size as 最大token長度,
    CASE
        WHEN @@innodb_ft_min_token_size = 3 THEN '⚠️  需要修改為 1'
        WHEN @@innodb_ft_min_token_size = 1 THEN '✅ 已經是最佳設定'
        ELSE '❓ 不確定'
    END as 狀態
" 2>/dev/null

echo ""

# 4. 檢查 Posts 表資訊
echo "📦 4. Posts 表資訊："
mysql -h $DB_HOST -u $DB_USER -p"$DB_PASS" $DB_NAME -e "
SELECT
    'Posts' as 表名,
    COUNT(*) as 總筆數,
    ROUND(AVG(LENGTH(Message)), 0) as 平均訊息長度
FROM Posts
WHERE DeleteAt = 0;

SELECT
    table_name as 表名,
    ROUND(data_length / 1024 / 1024, 2) as 資料大小_MB,
    ROUND(index_length / 1024 / 1024, 2) as 索引大小_MB,
    ROUND((data_length + index_length) / 1024 / 1024, 2) as 總大小_MB
FROM information_schema.tables
WHERE table_schema = '$DB_NAME'
  AND table_name = 'Posts';
" 2>/dev/null

echo ""

# 5. 檢查磁碟空間
echo "💾 5. 可用磁碟空間："
mysql -h $DB_HOST -u $DB_USER -p"$DB_PASS" -e "
SELECT
    table_schema as 資料庫,
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) as 目前使用_MB,
    ROUND(SUM(data_length + index_length) / 1024 / 1024 * 2.5, 2) as 需要空間_MB
FROM information_schema.tables
WHERE table_schema = '$DB_NAME'
GROUP BY table_schema;
" 2>/dev/null

echo ""

# 6. 檢查 FULLTEXT 索引
echo "🔎 6. 現有 FULLTEXT 索引："
mysql -h $DB_HOST -u $DB_USER -p"$DB_PASS" $DB_NAME -e "
SELECT
    table_name as 表名,
    index_name as 索引名,
    GROUP_CONCAT(column_name) as 索引欄位
FROM information_schema.statistics
WHERE table_schema = '$DB_NAME'
  AND index_type = 'FULLTEXT'
GROUP BY table_name, index_name;
" 2>/dev/null

echo ""

# 7. 檢查權限
echo "🔐 7. 使用者權限檢查："
mysql -h $DB_HOST -u $DB_USER -p"$DB_PASS" -e "
SHOW GRANTS FOR CURRENT_USER();
" 2>/dev/null | grep -E "REPLICATION|TRIGGER|ALTER" || echo "需要檢查權限"

echo ""
echo "=========================================="
echo "✅ 檢查完成！"
echo "=========================================="
echo ""
echo "根據上述結果："
echo ""
echo "如果 binlog已啟用=1 且 binlog格式=ROW："
echo "  → 建議使用 gh-ost（對業務影響最小）"
echo ""
echo "如果 binlog已啟用=0："
echo "  → 只能使用 pt-online-schema-change"
echo ""
echo "如果 最小token長度=3："
echo "  → 需要修改配置並重建索引"
echo ""
