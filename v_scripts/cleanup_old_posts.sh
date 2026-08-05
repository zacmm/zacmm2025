#!/bin/bash

# =====================================================
# Mattermost 舊訊息自動清理腳本（僅 Posts）
# =====================================================
# 用途：定期清理 2024-10-29 之前的舊訊息
# 執行方式：crontab 每 10 分鐘執行一次
# 清理表：Posts
# =====================================================

set -e

# =====================================================
# 配置區
# =====================================================

# 資料庫配置
DB_HOST="localhost"
DB_PORT="3306"
DB_USER="mmuser"
DB_PASS='wR7oV4kW1$tN2'
DB_NAME="zacmm"

# Slack 通知配置
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/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"
SLACK_CHANNEL="#網站監控"

# 清理配置
CUTOFF_DATE="2024-10-29 00:00:00"
CUTOFF_TIMESTAMP=$(date -d "$CUTOFF_DATE" +%s)000  # 轉換為毫秒時間戳（Linux 版本）
BATCH_SIZE=10000  # 減少批次大小以降低連接壓力
MAX_EXECUTION_TIME=480  # 8 分鐘（秒），留 2 分鐘緩衝給 10 分鐘 cron 間隔

# 日誌配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/cleanup_posts_$(date +%Y%m%d).log"

# 鎖文件（防止重複執行）
LOCK_FILE="$SCRIPT_DIR/.cleanup_posts.lock"

# =====================================================
# 初始化
# =====================================================

# 創建日誌目錄
mkdir -p "$LOG_DIR"

# 記錄日誌的函數
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE" >&2
}

# Slack 通知函數
send_slack_notification() {
    local message="$1"
    local color="${2:-#36a64f}"  # 預設綠色，錯誤時傳紅色

    curl -X POST "$SLACK_WEBHOOK_URL" \
        -H 'Content-Type: application/json' \
        -d "{
            \"channel\": \"$SLACK_CHANNEL\",
            \"attachments\": [{
                \"color\": \"$color\",
                \"title\": \"Mattermost Posts 清理通知\",
                \"text\": \"$message\",
                \"footer\": \"清理腳本（僅 Posts）\",
                \"ts\": $(date +%s)
            }]
        }" 2>/dev/null || log "Slack 通知發送失敗"
}

# 錯誤處理函數
handle_error() {
    local error_msg="$1"
    log "❌ 錯誤：$error_msg"

    # 計算平均批次時間
    if [ ${#BATCH_TIMES[@]} -gt 0 ]; then
        local sum=0
        for time in "${BATCH_TIMES[@]}"; do
            sum=$((sum + time))
        done
        AVG_BATCH_TIME=$((sum / ${#BATCH_TIMES[@]}))
    fi

    # 發送失敗通知，包含已完成的資料
    send_slack_notification "❌ Posts 清理失敗

錯誤：$error_msg

📊 執行前統計：
  • 已刪除: $TOTAL_DELETED_POSTS 筆
  • 需刪除: $ESTIMATED_POSTS 筆
  • 剩餘: $((ESTIMATED_POSTS - TOTAL_DELETED_POSTS)) 筆

⏱️ 批次執行時間：
  • 執行批次數: ${#BATCH_TIMES[@]} 次
  • 平均時間: ${AVG_BATCH_TIME}秒
  • 最久時間: ${MAX_BATCH_TIME}秒" "#ff0000"

    cleanup
    exit 1
}

# 清理函數（釋放鎖）
cleanup() {
    rm -f "$LOCK_FILE"
}

# 註冊退出時的清理
trap cleanup EXIT

# =====================================================
# 鎖檢查（防止重複執行）
# =====================================================

if [ -f "$LOCK_FILE" ]; then
    log "⚠️  腳本已在執行中，跳過此次執行"
    exit 0
fi

# 創建鎖文件
touch "$LOCK_FILE"

# =====================================================
# 主要執行
# =====================================================

log "=========================================="
log "開始執行 Posts 清理"
log "=========================================="
log "截止日期: $CUTOFF_DATE"
log "時間戳: $CUTOFF_TIMESTAMP"
log "批次大小: $BATCH_SIZE"
log "最大執行時間: ${MAX_EXECUTION_TIME}秒"
log ""

# 記錄開始時間
START_TIME=$(date +%s)

# 統計變數
TOTAL_DELETED_POSTS=0
TIME_POSTS=0

# 批次時間統計（用於計算平均和最大值）
BATCH_TIMES=()
MAX_BATCH_TIME=0
AVG_BATCH_TIME=0

# MySQL 連接指令
mysql_exec() {
    mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" "$@"
}

# =====================================================
# 查詢需要刪除的資料量
# =====================================================

log "查詢需要刪除的 Posts 數量（精確統計）..."

ESTIMATED_POSTS=$(mysql_exec -N -e "
    SELECT COUNT(*)
    FROM Posts
    WHERE CreateAt < $CUTOFF_TIMESTAMP;
" 2>/dev/null || echo "0")

log "需要刪除的 Posts 數量: $ESTIMATED_POSTS 筆"
log ""

# =====================================================
# 函數：檢查執行時間
# =====================================================
check_time_limit() {
    local current_time=$(date +%s)
    local elapsed=$((current_time - START_TIME))

    if [ $elapsed -ge $MAX_EXECUTION_TIME ]; then
        log "⏰ 達到執行時間限制（${elapsed}秒），停止執行"
        return 1
    fi
    return 0
}

# =====================================================
# 函數：刪除資料（批次處理）
# =====================================================
delete_batch() {
    local table="$1"
    local condition="$2"
    local batch_size="$3"

    local deleted_count=0

    while check_time_limit; do
        # 記錄本批次開始時間
        local batch_time_start=$(date +%s)

        # 執行刪除
        local result=$(mysql_exec -N -e "
            DELETE FROM $table
            WHERE $condition
            LIMIT $batch_size;
            SELECT ROW_COUNT();
        " 2>&1)

        # 檢查錯誤
        if [ $? -ne 0 ]; then
            handle_error "刪除 $table 失敗：$result"
        fi

        # 取得刪除的筆數
        local rows_deleted=$(echo "$result" | tail -1)

        # 檢查是否為數字（防止錯誤訊息導致運算錯誤）
        if ! [[ "$rows_deleted" =~ ^[0-9]+$ ]]; then
            handle_error "刪除 $table 時取得非數字結果：$rows_deleted"
        fi

        if [ "$rows_deleted" -eq 0 ]; then
            log "  ✓ $table 沒有更多資料需要刪除"
            break
        fi

        deleted_count=$((deleted_count + rows_deleted))

        # 計算本批次耗時
        local batch_time_end=$(date +%s)
        local batch_elapsed=$((batch_time_end - batch_time_start))

        # 記錄批次時間（用於統計）
        BATCH_TIMES+=($batch_elapsed)
        if [ $batch_elapsed -gt $MAX_BATCH_TIME ]; then
            MAX_BATCH_TIME=$batch_elapsed
        fi

        log "  ✓ $table 已刪除 $rows_deleted 筆（累計：$deleted_count，本次耗時：${batch_elapsed}秒）"

        # 休息 15 秒，讓資料庫充分處理後台清理並釋放連接
        sleep 15
    done

    echo $deleted_count
}

# =====================================================
# 清理 Posts（訊息）
# =====================================================

log "開始清理 Posts..."
POSTS_START=$(date +%s)
DELETED_POSTS=$(delete_batch "Posts" "CreateAt < $CUTOFF_TIMESTAMP" "$BATCH_SIZE")
POSTS_END=$(date +%s)
TIME_POSTS=$((POSTS_END - POSTS_START))
TOTAL_DELETED_POSTS=$DELETED_POSTS
log "Posts 清理完成，共刪除 $TOTAL_DELETED_POSTS 筆（耗時 ${TIME_POSTS}秒）"
log ""

# =====================================================
# 完成統計
# =====================================================

END_TIME=$(date +%s)
ELAPSED_TIME=$((END_TIME - START_TIME))

log "=========================================="
log "清理完成"
log "=========================================="
log "執行時間: ${ELAPSED_TIME}秒"
log "Posts 刪除: $TOTAL_DELETED_POSTS 筆"
log ""

# =====================================================
# Slack 通知（僅在有刪除資料時發送）
# =====================================================

if [ $TOTAL_DELETED_POSTS -gt 0 ]; then
    # 計算剩餘筆數
    REMAINING_POSTS=$((ESTIMATED_POSTS - TOTAL_DELETED_POSTS))

    # 計算平均批次時間
    if [ ${#BATCH_TIMES[@]} -gt 0 ]; then
        local sum=0
        for time in "${BATCH_TIMES[@]}"; do
            sum=$((sum + time))
        done
        AVG_BATCH_TIME=$((sum / ${#BATCH_TIMES[@]}))
    fi

    # 發送 Slack 通知
    send_slack_notification "✅ Posts 清理完成
總執行時間: ${ELAPSED_TIME}秒

📊 清理詳情：

🔹 Posts (訊息)
  • 已刪除: $TOTAL_DELETED_POSTS 筆 / 需刪除: $ESTIMATED_POSTS 筆
  • 剩餘: $REMAINING_POSTS 筆
  • 總耗時: ${TIME_POSTS}秒

⏱️ 批次執行時間：
  • 執行批次數: ${#BATCH_TIMES[@]} 次
  • 平均時間: ${AVG_BATCH_TIME}秒
  • 最久時間: ${MAX_BATCH_TIME}秒" "#36a64f"
else
    log "ℹ️  沒有資料需要清理，不發送 Slack 通知"
fi

# 清理 30 天前的日誌檔案
find "$LOG_DIR" -name "cleanup_posts_*.log" -type f -mtime +30 -delete

log "腳本執行結束"


# pv zacmm_backup_20251031.sql | sudo mysql -u root -p mattermost_prod_local
