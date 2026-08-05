#!/bin/bash

# MySQL 遠端 ALTER TABLE 執行腳本
# 用途：在遠端 MySQL 主機上執行 ALTER TABLE，完成後通知 Slack
# 使用方式：./migrate_posts_remote.sh

# ============ 設定區 ============
MYSQL_HOST="34.87.11.83"
MYSQL_USER="root"
MYSQL_PASS=""  # ⚠️ 請替換成實際密碼（或使用 -p 互動式輸入）
MYSQL_DB="mattermost_prod_local"

# 檢查密碼是否已設定
if [ -z "$MYSQL_PASS" ]; then
    echo "❌ 錯誤：MYSQL_PASS 未設定！"
    echo "請編輯腳本並設定 MySQL root 密碼，或使用環境變數："
    echo "  MYSQL_PASS='your_password' $0"
    exit 1
fi

# Slack Webhook URL
SLACK_WEBHOOK="https://hooks.slack.com/services/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"
SLACK_CHANNEL="#網站監控"

# 日誌檔案
LOG_FILE="/tmp/alter_posts_$(date +%Y%m%d_%H%M%S).log"
# ================================

echo "========================================" | tee -a "$LOG_FILE"
echo "開始 ALTER TABLE Posts 遷移" | tee -a "$LOG_FILE"
echo "開始時間: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

START_TIME=$(date +%s)

# 發送 Slack 通知：開始
if [ "$SLACK_WEBHOOK" != "YOUR_SLACK_WEBHOOK_URL" ]; then
    curl -X POST "$SLACK_WEBHOOK" \
        -H 'Content-Type: application/json' \
        -d "{
            \"text\": \":rocket: 開始執行 ALTER TABLE Posts migration\",
            \"attachments\": [{
                \"color\": \"#36a64f\",
                \"fields\": [
                    {\"title\": \"資料庫\", \"value\": \"$MYSQL_DB\", \"short\": true},
                    {\"title\": \"主機\", \"value\": \"$MYSQL_HOST\", \"short\": true},
                    {\"title\": \"開始時間\", \"value\": \"$(date '+%Y-%m-%d %H:%M:%S')\", \"short\": false}
                ]
            }]
        }" 2>&1 | tee -a "$LOG_FILE"
fi

# 執行 ALTER TABLE
echo "正在執行 ALTER TABLE..." | tee -a "$LOG_FILE"

# 執行 MySQL 命令並捕捉結果
set +e  # 暫時關閉 errexit 以便正確處理錯誤
MYSQL_OUTPUT=$(mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" \
    -e "ALTER TABLE Posts ADD RemoteId varchar(26);" 2>&1)
MYSQL_EXIT_CODE=$?
set -e  # 重新啟用 errexit

# 記錄輸出
echo "$MYSQL_OUTPUT" | tee -a "$LOG_FILE"

if [ $MYSQL_EXIT_CODE -eq 0 ]; then

    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    DURATION_MIN=$((DURATION / 60))

    echo "" | tee -a "$LOG_FILE"
    echo "========================================" | tee -a "$LOG_FILE"
    echo "✅ ALTER TABLE 執行成功！" | tee -a "$LOG_FILE"
    echo "完成時間: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
    echo "總耗時: ${DURATION} 秒 (${DURATION_MIN} 分鐘)" | tee -a "$LOG_FILE"
    echo "========================================" | tee -a "$LOG_FILE"

    # 發送 Slack 通知：成功
    if [ "$SLACK_WEBHOOK" != "YOUR_SLACK_WEBHOOK_URL" ]; then
        curl -X POST "$SLACK_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d "{
                \"text\": \":white_check_mark: ALTER TABLE Posts migration 執行成功！\",
                \"attachments\": [{
                    \"color\": \"good\",
                    \"fields\": [
                        {\"title\": \"資料庫\", \"value\": \"$MYSQL_DB\", \"short\": true},
                        {\"title\": \"總耗時\", \"value\": \"${DURATION_MIN} 分鐘\", \"short\": true},
                        {\"title\": \"完成時間\", \"value\": \"$(date '+%Y-%m-%d %H:%M:%S')\", \"short\": false}
                    ]
                }]
            }"
    fi

    exit 0
else
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    echo "" | tee -a "$LOG_FILE"
    echo "========================================" | tee -a "$LOG_FILE"
    echo "❌ ALTER TABLE 執行失敗！" | tee -a "$LOG_FILE"
    echo "失敗時間: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
    echo "========================================" | tee -a "$LOG_FILE"

    # 發送 Slack 通知：失敗
    if [ "$SLACK_WEBHOOK" != "YOUR_SLACK_WEBHOOK_URL" ]; then
        curl -X POST "$SLACK_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d "{
                \"text\": \":x: ALTER TABLE Posts migration 執行失敗！\",
                \"attachments\": [{
                    \"color\": \"danger\",
                    \"fields\": [
                        {\"title\": \"資料庫\", \"value\": \"$MYSQL_DB\", \"short\": true},
                        {\"title\": \"失敗時間\", \"value\": \"$(date '+%Y-%m-%d %H:%M:%S')\", \"short\": true},
                        {\"title\": \"日誌\", \"value\": \"請查看 $LOG_FILE\", \"short\": false}
                    ]
                }]
            }"
    fi

    exit 1
fi
