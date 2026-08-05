#!/bin/bash

# 持續監控腳本 - 每 N 秒記錄一次系統狀態
# 用於長期追蹤問題，找出卡住前的狀態變化

INTERVAL=${1:-60}  # 預設 60 秒記錄一次
LOG_DIR="./system_logs"
MAIN_LOG="$LOG_DIR/continuous_monitor.log"
ALERT_LOG="$LOG_DIR/alerts.log"

# 閾值設定
MEM_ALERT_THRESHOLD=85  # 記憶體使用率警告閾值
DISK_ALERT_THRESHOLD=85 # 磁碟使用率警告閾值
LOAD_ALERT_THRESHOLD=4  # 系統負載警告閾值

mkdir -p "$LOG_DIR"

echo "🔄 啟動持續監控"
echo "監控間隔: $INTERVAL 秒"
echo "日誌檔案: $MAIN_LOG"
echo "警告日誌: $ALERT_LOG"
echo "按 Ctrl+C 停止監控"
echo ""

# 記錄標頭
echo "timestamp,mem_used_mb,mem_percent,disk_percent,load_1min,mattermost_cpu,mattermost_mem_mb,mysql_connections,disk_io_read_mb,disk_io_write_mb" > "$MAIN_LOG"

# 信號處理
trap 'echo ""; echo "監控已停止"; exit 0' INT TERM

ITERATION=0

while true; do
    ITERATION=$((ITERATION + 1))
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    # ============================================
    # 收集數據
    # ============================================

    # 記憶體
    MEM_USED_MB=$(free -m | grep Mem | awk '{print $3}')
    MEM_TOTAL_MB=$(free -m | grep Mem | awk '{print $2}')
    MEM_PERCENT=$(awk "BEGIN {printf \"%.1f\", $MEM_USED_MB/$MEM_TOTAL_MB*100}")

    # 磁碟
    DISK_PERCENT=$(df -h . | tail -1 | awk '{print $5}' | sed 's/%//')

    # 系統負載
    LOAD_1MIN=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | xargs)

    # Mattermost 進程
    MATTERMOST_PID=$(pgrep -f "bin/mattermost" | head -1)
    if [ -n "$MATTERMOST_PID" ]; then
        MATTERMOST_CPU=$(ps -p $MATTERMOST_PID -o %cpu= | xargs)
        MATTERMOST_MEM_MB=$(ps -p $MATTERMOST_PID -o rss= | awk '{print int($1/1024)}')

        # 磁碟 I/O (累積值)
        if [ -f "/proc/$MATTERMOST_PID/io" ]; then
            DISK_IO_READ=$(grep read_bytes /proc/$MATTERMOST_PID/io | awk '{print $2}')
            DISK_IO_WRITE=$(grep write_bytes /proc/$MATTERMOST_PID/io | awk '{print $2}')
            DISK_IO_READ_MB=$(awk "BEGIN {printf \"%.1f\", $DISK_IO_READ/1024/1024}")
            DISK_IO_WRITE_MB=$(awk "BEGIN {printf \"%.1f\", $DISK_IO_WRITE/1024/1024}")
        else
            DISK_IO_READ_MB="N/A"
            DISK_IO_WRITE_MB="N/A"
        fi
    else
        MATTERMOST_CPU="N/A"
        MATTERMOST_MEM_MB="N/A"
        DISK_IO_READ_MB="N/A"
        DISK_IO_WRITE_MB="N/A"
    fi

    # MySQL 連線數
    MYSQL_CONNECTIONS=$(mysql -h 34.87.11.83 -u mmuser -pmmpass -e "SHOW STATUS LIKE 'Threads_connected';" 2>/dev/null | tail -1 | awk '{print $2}')
    [ -z "$MYSQL_CONNECTIONS" ] && MYSQL_CONNECTIONS="N/A"

    # ============================================
    # 記錄數據
    # ============================================

    echo "$TIMESTAMP,$MEM_USED_MB,$MEM_PERCENT,$DISK_PERCENT,$LOAD_1MIN,$MATTERMOST_CPU,$MATTERMOST_MEM_MB,$MYSQL_CONNECTIONS,$DISK_IO_READ_MB,$DISK_IO_WRITE_MB" >> "$MAIN_LOG"

    # ============================================
    # 檢查警告條件
    # ============================================

    ALERT_TRIGGERED=0

    # 記憶體警告
    MEM_INT=$(printf "%.0f" "$MEM_PERCENT")
    if [ "$MEM_INT" -ge "$MEM_ALERT_THRESHOLD" ]; then
        echo "[$TIMESTAMP] ⚠️  記憶體使用過高: ${MEM_PERCENT}% (${MEM_USED_MB}MB)" | tee -a "$ALERT_LOG"
        ALERT_TRIGGERED=1
    fi

    # 磁碟警告
    if [ "$DISK_PERCENT" -ge "$DISK_ALERT_THRESHOLD" ]; then
        echo "[$TIMESTAMP] ⚠️  磁碟使用過高: ${DISK_PERCENT}%" | tee -a "$ALERT_LOG"
        ALERT_TRIGGERED=1
    fi

    # 系統負載警告
    LOAD_INT=$(printf "%.0f" "$LOAD_1MIN")
    if [ "$LOAD_INT" -ge "$LOAD_ALERT_THRESHOLD" ]; then
        echo "[$TIMESTAMP] ⚠️  系統負載過高: $LOAD_1MIN" | tee -a "$ALERT_LOG"
        ALERT_TRIGGERED=1
    fi

    # 如果觸發警告，記錄詳細狀態
    if [ "$ALERT_TRIGGERED" -eq 1 ]; then
        {
            echo "===================="
            echo "詳細診斷資訊:"
            echo "TOP 5 記憶體使用進程:"
            ps aux --sort=-%mem | head -6
            echo ""
            echo "TOP 5 CPU 使用進程:"
            ps aux --sort=-%cpu | head -6
            echo "===================="
        } >> "$ALERT_LOG"
    fi

    # ============================================
    # 顯示即時狀態
    # ============================================

    # 每 10 次迭代顯示一次狀態
    if [ $((ITERATION % 10)) -eq 0 ]; then
        echo "[$TIMESTAMP] 記憶體: ${MEM_PERCENT}% | 磁碟: ${DISK_PERCENT}% | 負載: $LOAD_1MIN | Mattermost: CPU ${MATTERMOST_CPU}% MEM ${MATTERMOST_MEM_MB}MB"
    fi

    sleep $INTERVAL
done
