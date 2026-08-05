#!/bin/bash

# 系統監控腳本 - 診斷記憶體和磁碟寫入問題
# 用於找出導致應用程式卡住的根本原因

LOG_DIR="./system_logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/system_monitor_$TIMESTAMP.log"

mkdir -p "$LOG_DIR"

echo "🔍 系統監控診斷工具"
echo "===================="
echo "日誌檔案: $LOG_FILE"
echo ""

# 函數：記錄並顯示
log_and_show() {
    echo "$1" | tee -a "$LOG_FILE"
}

log_and_show "📅 監控時間: $(date)"
log_and_show ""

# ============================================
# 1. 記憶體使用分析
# ============================================
log_and_show "🧠 記憶體使用分析"
log_and_show "===================="

# 總體記憶體狀況
log_and_show ""
log_and_show "總體記憶體使用:"
free -h | tee -a "$LOG_FILE"

log_and_show ""
log_and_show "記憶體使用百分比:"
free | grep Mem | awk '{printf "使用率: %.2f%%\n", $3/$2 * 100}' | tee -a "$LOG_FILE"

# 找出記憶體使用最高的前 10 個進程
log_and_show ""
log_and_show "記憶體使用 TOP 10 進程:"
ps aux --sort=-%mem | head -11 | tee -a "$LOG_FILE"

# Mattermost 相關進程
log_and_show ""
log_and_show "Mattermost 進程記憶體使用:"
ps aux | grep -E "mattermost|mysql|redis|nginx" | grep -v grep | tee -a "$LOG_FILE"

# ============================================
# 2. 磁碟寫入分析
# ============================================
log_and_show ""
log_and_show "💾 磁碟寫入分析"
log_and_show "===================="

# 磁碟使用狀況
log_and_show ""
log_and_show "磁碟空間使用:"
df -h | tee -a "$LOG_FILE"

# 磁碟 I/O 統計（需要 iostat）
if command -v iostat &> /dev/null; then
    log_and_show ""
    log_and_show "磁碟 I/O 統計 (5 秒平均):"
    iostat -x 1 5 | tee -a "$LOG_FILE"
else
    log_and_show ""
    log_and_show "⚠️  iostat 未安裝，建議安裝: sudo apt-get install sysstat"
fi

# 找出磁碟寫入最多的進程（需要 iotop 或使用 /proc）
log_and_show ""
log_and_show "磁碟 I/O 使用 TOP 10 進程:"
if command -v iotop &> /dev/null; then
    sudo iotop -b -n 1 -o | head -20 | tee -a "$LOG_FILE"
else
    log_and_show "⚠️  iotop 未安裝，使用替代方案"
    # 使用 /proc/[pid]/io 來查看
    for pid in $(ps aux | grep -E "mattermost|mysql" | grep -v grep | awk '{print $2}'); do
        if [ -f "/proc/$pid/io" ]; then
            cmd=$(ps -p $pid -o comm=)
            write_bytes=$(grep write_bytes /proc/$pid/io | awk '{print $2}')
            echo "PID: $pid ($cmd) - Write Bytes: $write_bytes" | tee -a "$LOG_FILE"
        fi
    done
fi

# ============================================
# 3. 檔案系統分析
# ============================================
log_and_show ""
log_and_show "📁 檔案系統分析"
log_and_show "===================="

# 查找大檔案
log_and_show ""
log_and_show "最大的 10 個檔案 (在 Mattermost 目錄):"
find . -type f -size +10M 2>/dev/null -exec ls -lh {} \; | sort -k5 -hr | head -10 | tee -a "$LOG_FILE"

# 日誌檔案大小
log_and_show ""
log_and_show "日誌檔案大小:"
if [ -d "server/logs" ]; then
    du -sh server/logs/* 2>/dev/null | sort -hr | head -10 | tee -a "$LOG_FILE"
fi

# Bleve 索引大小（如果有）
if [ -d "server/data/bleve-indexes" ]; then
    log_and_show ""
    log_and_show "Bleve 索引大小:"
    du -sh server/data/bleve-indexes 2>/dev/null | tee -a "$LOG_FILE"
fi

# ============================================
# 4. 資料庫分析
# ============================================
log_and_show ""
log_and_show "🗄️  資料庫狀態"
log_and_show "===================="

# MySQL 進程狀態
log_and_show ""
log_and_show "MySQL 進程:"
ps aux | grep mysql | grep -v grep | tee -a "$LOG_FILE"

# MySQL 連線數（如果可以連線）
if command -v mysql &> /dev/null; then
    log_and_show ""
    log_and_show "MySQL 連線數和狀態:"
    mysql -h 34.87.11.83 -u mmuser -pmmpass -e "SHOW PROCESSLIST;" 2>/dev/null | tee -a "$LOG_FILE" || log_and_show "⚠️  無法連線到 MySQL"

    mysql -h 34.87.11.83 -u mmuser -pmmpass -e "SHOW STATUS LIKE 'Threads%';" 2>/dev/null | tee -a "$LOG_FILE"
fi

# ============================================
# 5. 系統負載和 CPU
# ============================================
log_and_show ""
log_and_show "⚡ CPU 和系統負載"
log_and_show "===================="

log_and_show ""
log_and_show "系統負載:"
uptime | tee -a "$LOG_FILE"

log_and_show ""
log_and_show "CPU 使用 TOP 10 進程:"
ps aux --sort=-%cpu | head -11 | tee -a "$LOG_FILE"

# ============================================
# 6. 網路連線
# ============================================
log_and_show ""
log_and_show "🌐 網路連線狀態"
log_and_show "===================="

log_and_show ""
log_and_show "ESTABLISHED 連線數:"
netstat -an 2>/dev/null | grep ESTABLISHED | wc -l | tee -a "$LOG_FILE"

log_and_show ""
log_and_show "各狀態連線數統計:"
netstat -an 2>/dev/null | awk '{print $6}' | sort | uniq -c | sort -rn | tee -a "$LOG_FILE"

# ============================================
# 7. Mattermost 特定檢查
# ============================================
log_and_show ""
log_and_show "📱 Mattermost 特定檢查"
log_and_show "===================="

# 檢查 Mattermost 日誌中的錯誤
if [ -f "server/logs/mattermost.log" ]; then
    log_and_show ""
    log_and_show "最近的錯誤日誌 (最後 20 條):"
    tail -100 server/logs/mattermost.log | grep -i "error\|fatal\|panic\|out of memory\|OOM" | tail -20 | tee -a "$LOG_FILE"
fi

# 檢查上傳檔案大小
if [ -d "server/data" ]; then
    log_and_show ""
    log_and_show "上傳檔案總大小:"
    du -sh server/data 2>/dev/null | tee -a "$LOG_FILE"
fi

# ============================================
# 8. 建議診斷
# ============================================
log_and_show ""
log_and_show "💡 初步診斷建議"
log_and_show "===================="

# 記憶體使用率檢查
MEM_PERCENT=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100}')
if [ "$MEM_PERCENT" -gt 90 ]; then
    log_and_show "⚠️  記憶體使用率過高 ($MEM_PERCENT%)，建議："
    log_and_show "   1. 檢查是否有記憶體洩漏"
    log_and_show "   2. 考慮增加 swap 空間"
    log_and_show "   3. 限制 Mattermost 記憶體使用"
elif [ "$MEM_PERCENT" -gt 80 ]; then
    log_and_show "⚠️  記憶體使用率偏高 ($MEM_PERCENT%)，需要關注"
else
    log_and_show "✅ 記憶體使用率正常 ($MEM_PERCENT%)"
fi

# 磁碟空間檢查
DISK_PERCENT=$(df -h . | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_PERCENT" -gt 90 ]; then
    log_and_show "⚠️  磁碟空間不足 ($DISK_PERCENT%)，建議："
    log_and_show "   1. 清理舊日誌檔案"
    log_and_show "   2. 清理舊的上傳檔案"
    log_and_show "   3. 考慮擴充磁碟空間"
elif [ "$DISK_PERCENT" -gt 80 ]; then
    log_and_show "⚠️  磁碟空間偏高 ($DISK_PERCENT%)，需要關注"
else
    log_and_show "✅ 磁碟空間正常 ($DISK_PERCENT%)"
fi

log_and_show ""
log_and_show "===================="
log_and_show "完整報告已儲存至: $LOG_FILE"
log_and_show "===================="
