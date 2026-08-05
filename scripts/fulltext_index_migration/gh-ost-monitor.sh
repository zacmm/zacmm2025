#!/bin/bash
# =====================================================
# gh-ost 互動式監控與控制腳本
# =====================================================

SOCKET="/tmp/gh-ost.sock"
DB_HOST="34.87.11.83"
DB_USER="mmuser"
DB_PASS="mmpass"
DB_NAME="mattermost_prod_local"

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

clear

while true; do
    echo -e "${BLUE}=========================================="
    echo "gh-ost 監控與控制面板"
    echo -e "==========================================${NC}"
    echo ""

    # 檢查 gh-ost 是否運行
    if [ -S "$SOCKET" ]; then
        echo -e "${GREEN}✅ gh-ost 正在運行${NC}"
        echo ""

        # 獲取狀態
        STATUS=$(echo "status" | nc -U $SOCKET 2>/dev/null)

        if [ ! -z "$STATUS" ]; then
            echo -e "${YELLOW}📊 執行狀態:${NC}"
            echo "$STATUS" | grep -E "Copy:|Applied:|Backlog:|Time:|ETA:" | sed 's/^/  /'
            echo ""

            # 檢查是否暫停
            if echo "$STATUS" | grep -q "throttled: true"; then
                echo -e "${RED}⏸️  當前狀態: 已暫停${NC}"
            else
                echo -e "${GREEN}▶️  當前狀態: 執行中${NC}"
            fi
            echo ""
        fi

        # 檢查 MySQL 負載
        THREADS=$(mysql -h $DB_HOST -u $DB_USER -p"$DB_PASS" -N -e "
        SELECT VARIABLE_VALUE
        FROM information_schema.GLOBAL_STATUS
        WHERE VARIABLE_NAME='Threads_running'
        " 2>/dev/null)

        if [ ! -z "$THREADS" ]; then
            echo -e "${YELLOW}💻 MySQL 負載:${NC}"
            echo "  執行中執行緒: $THREADS"

            if [ "$THREADS" -gt 80 ]; then
                echo -e "  ${RED}⚠️  負載較高${NC}"
            elif [ "$THREADS" -gt 50 ]; then
                echo -e "  ${YELLOW}⚠️  負載中等${NC}"
            else
                echo -e "  ${GREEN}✅ 負載正常${NC}"
            fi
        fi
        echo ""

    else
        echo -e "${RED}❌ gh-ost 未運行或 socket 不存在${NC}"
        echo ""
    fi

    echo -e "${BLUE}=========================================="
    echo "控制選項:"
    echo "==========================================${NC}"
    echo "  [s] 查看詳細狀態"
    echo "  [p] 暫停執行"
    echo "  [r] 恢復執行"
    echo "  [f] 加快速度 (chunk-size=2000)"
    echo "  [l] 減慢速度 (chunk-size=500)"
    echo "  [e] 緊急暫停 (panic)"
    echo "  [c] 取消緊急暫停"
    echo "  [m] 查看 MySQL 進程"
    echo "  [g] 查看 ghost table"
    echo "  [q] 退出監控"
    echo ""
    echo -n "請選擇 [或按 Enter 重新整理]: "

    read -t 10 choice

    case $choice in
        s)
            clear
            echo "status" | nc -U $SOCKET 2>/dev/null
            echo ""
            echo "按 Enter 繼續..."
            read
            ;;
        p)
            echo "throttle" | nc -U $SOCKET 2>/dev/null
            echo -e "${YELLOW}⏸️  已發送暫停命令${NC}"
            sleep 2
            ;;
        r)
            echo "no-throttle" | nc -U $SOCKET 2>/dev/null
            echo -e "${GREEN}▶️  已發送恢復命令${NC}"
            sleep 2
            ;;
        f)
            echo "chunk-size=2000" | nc -U $SOCKET 2>/dev/null
            echo -e "${GREEN}⚡ 已調整為快速模式 (chunk-size=2000)${NC}"
            sleep 2
            ;;
        l)
            echo "chunk-size=500" | nc -U $SOCKET 2>/dev/null
            echo -e "${YELLOW}🐢 已調整為慢速模式 (chunk-size=500)${NC}"
            sleep 2
            ;;
        e)
            touch /tmp/ghost.panic
            echo -e "${RED}🚨 緊急暫停已啟動！${NC}"
            sleep 2
            ;;
        c)
            rm -f /tmp/ghost.panic
            echo -e "${GREEN}✅ 已取消緊急暫停${NC}"
            sleep 2
            ;;
        m)
            clear
            mysql -h $DB_HOST -u $DB_USER -p"$DB_PASS" -e "
            SELECT
                id,
                user,
                db,
                command,
                time,
                LEFT(info, 80) as query
            FROM information_schema.processlist
            WHERE db='$DB_NAME' OR user='$DB_USER'
            ORDER BY time DESC
            LIMIT 20;
            " 2>/dev/null
            echo ""
            echo "按 Enter 繼續..."
            read
            ;;
        g)
            clear
            mysql -h $DB_HOST -u $DB_USER -p"$DB_PASS" $DB_NAME -e "
            SELECT
                table_name,
                ROUND(data_length/1024/1024, 2) as 資料_MB,
                ROUND(index_length/1024/1024, 2) as 索引_MB,
                table_rows as 估計行數
            FROM information_schema.tables
            WHERE table_schema='$DB_NAME'
              AND table_name LIKE '%_gho'
            " 2>/dev/null
            echo ""
            echo "按 Enter 繼續..."
            read
            ;;
        q)
            clear
            echo "退出監控..."
            exit 0
            ;;
        *)
            # 按 Enter 或超時，重新整理
            clear
            ;;
    esac
done
