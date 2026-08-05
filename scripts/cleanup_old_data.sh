#!/bin/bash

# 資料清理腳本 - 刪除超過一年的 Posts 和 FileInfo
# 使用分批刪除方式，避免鎖表時間過長

MYSQL_HOST="34.87.11.83"
MYSQL_USER="root"
MYSQL_DB="mattermost_prod_local"
CUTOFF_TIMESTAMP=1729592229000  # 2024-10-22 (一年前)
BATCH_SIZE=10000
SLACK_WEBHOOK="https://hooks.slack.com/services/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"

echo "========================================"
echo "資料清理作業開始"
echo "開始時間: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"
echo ""

# 發送 Slack 通知：開始
curl -X POST "$SLACK_WEBHOOK" \
    -H 'Content-Type: application/json' \
    -d "{
        \"text\": \":broom: 開始清理超過一年的資料\",
        \"attachments\": [{
            \"color\": \"#36a64f\",
            \"fields\": [
                {\"title\": \"資料庫\", \"value\": \"$MYSQL_DB\", \"short\": true},
                {\"title\": \"開始時間\", \"value\": \"$(date '+%Y-%m-%d %H:%M:%S')\", \"short\": true}
            ]
        }]
    }" 2>/dev/null

START_TIME=$(date +%s)

# ============ 清理 Posts 表 ============
echo "1️⃣ 清理 Posts 表（分批刪除）"
echo ""

POSTS_DELETED=0
while true; do
    DELETED=$(mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" "$MYSQL_DB" -sN -e "
        DELETE FROM Posts
        WHERE CreateAt < $CUTOFF_TIMESTAMP
        LIMIT $BATCH_SIZE;
        SELECT ROW_COUNT();
    " 2>&1 | tail -1)

    if [ "$DELETED" -eq 0 ]; then
        break
    fi

    POSTS_DELETED=$((POSTS_DELETED + DELETED))
    echo "已刪除 Posts: $POSTS_DELETED 筆"

    # 短暫休息，避免長時間鎖表
    sleep 0.5
done

echo "✅ Posts 清理完成，共刪除 $POSTS_DELETED 筆"
echo ""

# ============ 清理 FileInfo 表 ============
echo "2️⃣ 清理 FileInfo 表（分批刪除）"
echo ""

FILEINFO_DELETED=0
while true; do
    DELETED=$(mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" "$MYSQL_DB" -sN -e "
        DELETE FROM FileInfo
        WHERE CreateAt < $CUTOFF_TIMESTAMP
        LIMIT $BATCH_SIZE;
        SELECT ROW_COUNT();
    " 2>&1 | tail -1)

    if [ "$DELETED" -eq 0 ]; then
        break
    fi

    FILEINFO_DELETED=$((FILEINFO_DELETED + DELETED))
    echo "已刪除 FileInfo: $FILEINFO_DELETED 筆"

    # 短暫休息，避免長時間鎖表
    sleep 0.5
done

echo "✅ FileInfo 清理完成，共刪除 $FILEINFO_DELETED 筆"
echo ""

# ============ 優化表格 ============
echo "3️⃣ 優化表格（回收空間）"
echo ""

echo "優化 Posts 表..."
mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" "$MYSQL_DB" -e "OPTIMIZE TABLE Posts;" 2>&1

echo "優化 FileInfo 表..."
mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" "$MYSQL_DB" -e "OPTIMIZE TABLE FileInfo;" 2>&1

echo "✅ 表格優化完成"
echo ""

# ============ 完成統計 ============
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
DURATION_MIN=$((DURATION / 60))

echo "========================================"
echo "✅ 資料清理作業完成！"
echo "完成時間: $(date '+%Y-%m-%d %H:%M:%S')"
echo "總耗時: ${DURATION} 秒 (${DURATION_MIN} 分鐘)"
echo "Posts 刪除: $POSTS_DELETED 筆"
echo "FileInfo 刪除: $FILEINFO_DELETED 筆"
echo "========================================"

# 發送 Slack 通知：完成
curl -X POST "$SLACK_WEBHOOK" \
    -H 'Content-Type: application/json' \
    -d "{
        \"text\": \":white_check_mark: 資料清理作業完成！\",
        \"attachments\": [{
            \"color\": \"good\",
            \"fields\": [
                {\"title\": \"Posts 刪除\", \"value\": \"$POSTS_DELETED 筆\", \"short\": true},
                {\"title\": \"FileInfo 刪除\", \"value\": \"$FILEINFO_DELETED 筆\", \"short\": true},
                {\"title\": \"總耗時\", \"value\": \"${DURATION_MIN} 分鐘\", \"short\": true},
                {\"title\": \"完成時間\", \"value\": \"$(date '+%Y-%m-%d %H:%M:%S')\", \"short\": true}
            ]
        }]
    }" 2>/dev/null

exit 0
