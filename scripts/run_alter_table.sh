#!/bin/bash

# 簡單的 ALTER TABLE 執行腳本
# 使用方式：在遠端 MySQL 主機上直接執行
# ssh root@34.87.11.83 'bash -s' < run_alter_table.sh

echo "========================================"
echo "開始執行 ALTER TABLE Posts"
echo "開始時間: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"
echo ""

START_TIME=$(date +%s)

# 執行 ALTER TABLE
mysql mattermost_prod_local << 'EOF'
ALTER TABLE Posts ADD RemoteId varchar(26);
EOF

EXIT_CODE=$?
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
DURATION_MIN=$((DURATION / 60))

echo ""
echo "========================================"

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ ALTER TABLE 執行成功！"
    echo "完成時間: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "總耗時: ${DURATION} 秒 (${DURATION_MIN} 分鐘)"

    # 發送 Slack 通知
    curl -X POST "https://hooks.slack.com/services/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" \
        -H 'Content-Type: application/json' \
        -d "{
            \"text\": \":white_check_mark: ALTER TABLE Posts 完成！總耗時: ${DURATION_MIN} 分鐘\"
        }" 2>/dev/null
else
    echo "❌ ALTER TABLE 執行失敗！"
    echo "錯誤代碼: $EXIT_CODE"

    # 發送 Slack 通知
    curl -X POST "https://hooks.slack.com/services/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" \
        -H 'Content-Type: application/json' \
        -d "{
            \"text\": \":x: ALTER TABLE Posts 執行失敗！錯誤代碼: $EXIT_CODE\"
        }" 2>/dev/null
fi

echo "========================================"
exit $EXIT_CODE
