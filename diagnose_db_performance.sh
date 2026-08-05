#!/bin/bash

# 資料庫性能診斷腳本

echo "🔍 資料庫性能診斷"
echo "=================="
echo ""

DB_HOST="34.87.11.83"
DB_USER="mmuser"
DB_PASS="mmpass"
DB_NAME="mattermost_prod_local"

# 1. 連線數檢查
echo "1️⃣  MySQL 連線狀態"
echo "-------------------"
mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -e "SHOW STATUS LIKE 'Threads%';"
echo ""
mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -e "SHOW VARIABLES LIKE 'max_connections';"
echo ""

# 2. 當前連線列表
echo "2️⃣  當前活動連線（排除 Sleep）"
echo "-------------------"
mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -e "SHOW FULL PROCESSLIST;" | grep -v Sleep | head -20
echo ""

# 3. 長時間執行的查詢
echo "3️⃣  長時間執行的查詢（> 5 秒）"
echo "-------------------"
mysql -h $DB_HOST -u $DB_USER -p$DB_PASS << 'EOF'
SELECT
    ID,
    USER,
    HOST,
    DB,
    COMMAND,
    TIME,
    STATE,
    LEFT(INFO, 100) as QUERY
FROM information_schema.PROCESSLIST
WHERE COMMAND != 'Sleep'
  AND TIME > 5
ORDER BY TIME DESC;
EOF
echo ""

# 4. FileInfo 資料表狀態
echo "4️⃣  FileInfo 資料表狀態"
echo "-------------------"
mysql -h $DB_HOST -u $DB_USER -p$DB_PASS << 'EOF'
SELECT
    COUNT(*) as total_files,
    COUNT(CASE WHEN DeleteAt = 0 THEN 1 END) as active_files,
    COUNT(CASE WHEN DeleteAt > 0 THEN 1 END) as deleted_files,
    ROUND(DATA_LENGTH / 1024 / 1024, 2) as data_size_mb,
    ROUND(INDEX_LENGTH / 1024 / 1024, 2) as index_size_mb,
    ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) as total_size_mb
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'mattermost_prod_local'
AND TABLE_NAME = 'FileInfo';
EOF
echo ""

# 5. Threads 資料表狀態
echo "5️⃣  Threads 資料表狀態"
echo "-------------------"
mysql -h $DB_HOST -u $DB_USER -p$DB_PASS << 'EOF'
SELECT
    COUNT(*) as total_threads,
    ROUND(DATA_LENGTH / 1024 / 1024, 2) as data_size_mb,
    ROUND(INDEX_LENGTH / 1024 / 1024, 2) as index_size_mb
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'mattermost_prod_local'
AND TABLE_NAME = 'Threads';
EOF
echo ""

# 6. 死鎖資訊
echo "6️⃣  最近的死鎖資訊"
echo "-------------------"
mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -e "SHOW ENGINE INNODB STATUS\G" | grep -A 50 "LATEST DETECTED DEADLOCK" | head -50
echo ""

# 7. 資料庫鎖等待
echo "7️⃣  當前鎖等待"
echo "-------------------"
mysql -h $DB_HOST -u $DB_USER -p$DB_PASS << 'EOF'
SELECT
    r.trx_id waiting_trx_id,
    r.trx_mysql_thread_id waiting_thread,
    r.trx_query waiting_query,
    b.trx_id blocking_trx_id,
    b.trx_mysql_thread_id blocking_thread,
    b.trx_query blocking_query
FROM information_schema.innodb_lock_waits w
INNER JOIN information_schema.innodb_trx b ON b.trx_id = w.blocking_trx_id
INNER JOIN information_schema.innodb_trx r ON r.trx_id = w.requesting_trx_id;
EOF
echo ""

# 8. 建議
echo "💡 診斷建議"
echo "-------------------"

FILE_COUNT=$(mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -N -e "SELECT COUNT(*) FROM mattermost_prod_local.FileInfo WHERE DeleteAt = 0;")
echo "活躍檔案數: $FILE_COUNT"

if [ "$FILE_COUNT" -gt 100000 ]; then
    echo "⚠️  FileInfo 資料表較大 (> 10萬筆)"
    echo "   建議："
    echo "   1. 啟用 Bleve 搜尋引擎（避免 MySQL 全表掃描）"
    echo "   2. 檢查並優化索引"
    echo "   3. 考慮清理舊的已刪除檔案"
fi

CONNECTIONS=$(mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -N -e "SHOW STATUS LIKE 'Threads_connected';" | awk '{print $2}')
echo ""
echo "當前連線數: $CONNECTIONS"

if [ "$CONNECTIONS" -gt 50 ]; then
    echo "⚠️  連線數偏高"
    echo "   建議："
    echo "   1. 降低 MaxOpenConns 設定"
    echo "   2. 檢查是否有連線洩漏"
fi

echo ""
echo "=================="
echo "✅ 診斷完成"
