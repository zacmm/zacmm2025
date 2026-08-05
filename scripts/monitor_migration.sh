#!/bin/bash

# 監控 ALTER TABLE 進度腳本
# 用途：每 30 秒查看一次 migration 進度
# 使用方式：./monitor_migration.sh

MYSQL_HOST="34.87.11.83"
MYSQL_USER="mmuser"
MYSQL_PASS="mmpass"
MYSQL_DB="mattermost_prod_local"

echo "========================================"
echo "開始監控 ALTER TABLE 進度"
echo "監控時間: $(date '+%Y-%m-%d %H:%M:%S')"
echo "按 Ctrl+C 停止監控"
echo "========================================"
echo ""

COUNTER=0

while true; do
    COUNTER=$((COUNTER + 1))
    TIMESTAMP=$(date '+%H:%M:%S')

    # 查詢進度
    RESULT=$(mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASS" -se "
        SELECT
            ID,
            TIME as seconds,
            ROUND(TIME/60, 1) as minutes,
            ROUND(TIME/3600, 2) as hours,
            STATE
        FROM information_schema.PROCESSLIST
        WHERE DB = '$MYSQL_DB'
          AND (INFO LIKE '%ALTER TABLE Posts%' OR STATE LIKE '%copy%')
        LIMIT 1;
    " 2>/dev/null)

    if [ -n "$RESULT" ]; then
        ID=$(echo "$RESULT" | awk '{print $1}')
        SECONDS=$(echo "$RESULT" | awk '{print $2}')
        MINUTES=$(echo "$RESULT" | awk '{print $3}')
        HOURS=$(echo "$RESULT" | awk '{print $4}')
        STATE=$(echo "$RESULT" | cut -f5-)

        echo "[$TIMESTAMP] (#$COUNTER) PID: $ID | 執行: ${HOURS}h (${MINUTES}m / ${SECONDS}s) | 狀態: $STATE"
    else
        echo "[$TIMESTAMP] (#$COUNTER) ⚠️  未發現執行中的 ALTER TABLE（可能已完成或未開始）"

        # 檢查是否有 RemoteId 欄位（表示已完成）
        HAS_COLUMN=$(mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" \
            -se "SHOW COLUMNS FROM Posts LIKE 'RemoteId';" 2>/dev/null)

        if [ -n "$HAS_COLUMN" ]; then
            echo ""
            echo "✅ Migration 已完成！Posts 表已有 RemoteId 欄位"
            echo ""
            break
        fi
    fi

    sleep 30
done

echo "========================================"
echo "監控結束: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"
