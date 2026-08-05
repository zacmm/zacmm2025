#!/bin/bash

# =====================================================
# Mattermost 批次刪除訊息腳本（使用 mmctl）
# =====================================================
# 用途：使用 mmctl 批次刪除指定時間範圍的訊息
# 優點：使用官方 API，更安全
# 缺點：速度較慢，需要逐條處理
# =====================================================

set -e

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
export MMCTL_LOCAL_SOCKET_PATH=/tmp/mattermost_local.socket
MMCTL="./bin/mmctl"
DB_HOST="34.87.11.83"
DB_USER="mmuser"
DB_PASS="mmpass"
DB_NAME="mattermost_prod_local"

# 顯示標題
echo -e "${BLUE}========================================"
echo "Mattermost 批次刪除訊息工具"
echo -e "========================================${NC}"
echo ""

# 檢查 mmctl 是否存在
if [ ! -f "$MMCTL" ]; then
    echo -e "${RED}錯誤：找不到 mmctl${NC}"
    echo "請確保在 server 目錄下執行此腳本"
    exit 1
fi

# 函數：顯示使用說明
show_usage() {
    echo "使用方式："
    echo "  $0 <team:channel> <before_date> [--permanent]"
    echo ""
    echo "參數："
    echo "  team:channel   - 團隊:頻道名稱，例如 taipei:town-square"
    echo "  before_date    - 刪除此日期之前的訊息，格式: YYYY-MM-DD"
    echo "  --permanent    - 永久刪除（可選，預設為軟刪除）"
    echo ""
    echo "範例："
    echo "  $0 taipei:town-square 2024-01-01"
    echo "  $0 taipei:town-square 2024-01-01 --permanent"
    exit 1
}

# 檢查參數
if [ $# -lt 2 ]; then
    show_usage
fi

CHANNEL="$1"
BEFORE_DATE="$2"
PERMANENT=""

if [ "$3" == "--permanent" ]; then
    PERMANENT="--permanent --confirm"
    echo -e "${RED}警告：將執行永久刪除！${NC}"
fi

# 驗證日期格式
if ! date -j -f "%Y-%m-%d" "$BEFORE_DATE" >/dev/null 2>&1; then
    echo -e "${RED}錯誤：日期格式不正確，請使用 YYYY-MM-DD${NC}"
    exit 1
fi

# 轉換日期為 ISO 8601 格式
SINCE_DATE=$(date -j -f "%Y-%m-%d" -v+1d "$BEFORE_DATE" "+%Y-%m-%dT00:00:00Z" 2>/dev/null)

echo -e "${YELLOW}配置資訊：${NC}"
echo "  頻道: $CHANNEL"
echo "  刪除日期: $BEFORE_DATE 之前的訊息"
echo "  刪除模式: $([ -n "$PERMANENT" ] && echo "永久刪除" || echo "軟刪除")"
echo ""

# 確認
read -p "確定要繼續嗎？(y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "已取消"
    exit 0
fi

echo ""
echo -e "${BLUE}步驟 1: 獲取要刪除的訊息列表...${NC}"

# 使用 SQL 獲取要刪除的訊息 ID
# 因為 mmctl post list 只能列出最近的訊息，我們需要從資料庫查詢
DELETE_TIMESTAMP=$(date -j -f "%Y-%m-%d" "$BEFORE_DATE" "+%s")000

echo "查詢 $BEFORE_DATE 之前的訊息..."

POST_IDS=$(mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -e "
SELECT p.Id
FROM Posts p
JOIN Channels c ON p.ChannelId = c.Id
JOIN Teams t ON c.TeamId = t.Id
WHERE CONCAT(t.Name, ':', c.Name) = '$CHANNEL'
  AND p.CreateAt < $DELETE_TIMESTAMP
  AND p.DeleteAt = 0
LIMIT 10000;
" 2>/dev/null)

if [ -z "$POST_IDS" ]; then
    echo -e "${GREEN}沒有找到需要刪除的訊息${NC}"
    exit 0
fi

# 計算訊息數量
POST_COUNT=$(echo "$POST_IDS" | wc -l | tr -d ' ')
echo -e "${YELLOW}找到 $POST_COUNT 條訊息${NC}"
echo ""

# 再次確認
if [ $POST_COUNT -gt 100 ]; then
    echo -e "${RED}警告：將刪除 $POST_COUNT 條訊息！${NC}"
    read -p "確定要繼續嗎？(y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "已取消"
        exit 0
    fi
fi

echo -e "${BLUE}步驟 2: 開始批次刪除...${NC}"

# 批次刪除（每次 50 條）
BATCH_SIZE=50
DELETED=0
FAILED=0

echo "$POST_IDS" | while IFS= read -r line; do
    BATCH+=("$line")

    if [ ${#BATCH[@]} -eq $BATCH_SIZE ]; then
        echo "刪除第 $((DELETED+1)) - $((DELETED+BATCH_SIZE)) 條..."

        if $MMCTL post delete "${BATCH[@]}" $PERMANENT --local 2>/dev/null; then
            DELETED=$((DELETED + BATCH_SIZE))
            echo -e "${GREEN}✓ 成功${NC}"
        else
            FAILED=$((FAILED + BATCH_SIZE))
            echo -e "${RED}✗ 失敗${NC}"
        fi

        BATCH=()
        sleep 0.5  # 避免請求過快
    fi
done

# 處理剩餘的訊息
if [ ${#BATCH[@]} -gt 0 ]; then
    echo "刪除剩餘 ${#BATCH[@]} 條..."
    if $MMCTL post delete "${BATCH[@]}" $PERMANENT --local 2>/dev/null; then
        DELETED=$((DELETED + ${#BATCH[@]}))
        echo -e "${GREEN}✓ 成功${NC}"
    else
        FAILED=$((FAILED + ${#BATCH[@]}))
        echo -e "${RED}✗ 失敗${NC}"
    fi
fi

echo ""
echo -e "${BLUE}========================================"
echo "完成"
echo -e "========================================${NC}"
echo -e "${GREEN}成功刪除: $DELETED 條${NC}"
if [ $FAILED -gt 0 ]; then
    echo -e "${RED}失敗: $FAILED 條${NC}"
fi
echo ""
