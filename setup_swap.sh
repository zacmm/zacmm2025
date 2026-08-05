#!/bin/bash

# Swap 設定腳本
# 用於沒有 swap 空間的系統

echo "💾 Swap 空間設定工具"
echo "===================="
echo ""

# 檢查是否已有 swap
CURRENT_SWAP=$(free -m | grep Swap | awk '{print $2}')

if [ "$CURRENT_SWAP" -gt 0 ]; then
    echo "⚠️  系統已有 ${CURRENT_SWAP}MB swap 空間"
    echo ""
    read -p "是否仍要繼續？(y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# 檢查可用磁碟空間
AVAILABLE_SPACE=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')
echo "📊 可用磁碟空間: ${AVAILABLE_SPACE}GB"

if [ "$AVAILABLE_SPACE" -lt 5 ]; then
    echo "❌ 磁碟空間不足 5GB，無法建立 swap"
    exit 1
fi

# 建議 swap 大小
TOTAL_MEM=$(free -m | grep Mem | awk '{print $2}')
TOTAL_MEM_GB=$((TOTAL_MEM / 1024))

echo "📊 總記憶體: ${TOTAL_MEM_GB}GB"
echo ""
echo "建議 swap 大小："
echo "  選項 1: 4GB (推薦 - 記憶體的一半)"
echo "  選項 2: 2GB (最小)"
echo "  選項 3: 8GB (與記憶體相同)"
echo ""

read -p "請選擇 swap 大小 (1/2/3，預設 1): " SWAP_CHOICE

case $SWAP_CHOICE in
    2)
        SWAP_SIZE="2G"
        ;;
    3)
        SWAP_SIZE="8G"
        ;;
    *)
        SWAP_SIZE="4G"
        ;;
esac

echo ""
echo "將建立 $SWAP_SIZE swap 空間"
echo ""
read -p "確認繼續？(y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

echo ""
echo "🔧 開始建立 swap..."
echo ""

# 1. 建立 swap 檔案
echo "1️⃣  建立 swap 檔案..."
sudo fallocate -l $SWAP_SIZE /swapfile

if [ $? -ne 0 ]; then
    echo "⚠️  fallocate 失敗，嘗試使用 dd..."
    sudo dd if=/dev/zero of=/swapfile bs=1M count=$(echo $SWAP_SIZE | sed 's/G//' | awk '{print $1*1024}') status=progress
fi

# 2. 設定權限
echo "2️⃣  設定權限..."
sudo chmod 600 /swapfile

# 3. 設定 swap 區域
echo "3️⃣  設定 swap 區域..."
sudo mkswap /swapfile

# 4. 啟用 swap
echo "4️⃣  啟用 swap..."
sudo swapon /swapfile

# 5. 驗證
echo "5️⃣  驗證 swap..."
echo ""
sudo swapon --show
echo ""
free -h

# 6. 設定開機自動掛載
echo ""
echo "6️⃣  設定開機自動掛載..."

if grep -q "/swapfile" /etc/fstab; then
    echo "⚠️  /etc/fstab 已有 swapfile 設定"
else
    echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab
    echo "✅ 已添加到 /etc/fstab"
fi

# 7. 設定 swappiness
echo ""
echo "7️⃣  設定 swappiness（控制 swap 使用傾向）"
echo ""

CURRENT_SWAPPINESS=$(cat /proc/sys/vm/swappiness)
echo "當前 swappiness: $CURRENT_SWAPPINESS"
echo ""
echo "建議值："
echo "  10 - 僅在記憶體極度不足時使用 swap（推薦）"
echo "  20 - 偏向使用記憶體"
echo "  60 - 系統預設（較積極使用 swap）"
echo ""

read -p "請選擇 swappiness 值 (10/20/60，預設 10): " SWAPPINESS_CHOICE

case $SWAPPINESS_CHOICE in
    20)
        SWAPPINESS=20
        ;;
    60)
        SWAPPINESS=60
        ;;
    *)
        SWAPPINESS=10
        ;;
esac

echo "設定 swappiness 為 $SWAPPINESS..."
sudo sysctl vm.swappiness=$SWAPPINESS

# 永久設定
if grep -q "vm.swappiness" /etc/sysctl.conf; then
    sudo sed -i "s/vm.swappiness=.*/vm.swappiness=$SWAPPINESS/" /etc/sysctl.conf
else
    echo "vm.swappiness=$SWAPPINESS" | sudo tee -a /etc/sysctl.conf
fi

echo ""
echo "===================="
echo "✅ Swap 設定完成！"
echo "===================="
echo ""
echo "📊 當前狀態："
free -h
echo ""
echo "Swap 檔案位置: /swapfile"
echo "Swap 大小: $SWAP_SIZE"
echo "Swappiness: $SWAPPINESS"
echo ""
echo "💡 建議："
echo "  1. 使用 'free -h' 監控記憶體和 swap 使用"
echo "  2. 如果 swap 使用率持續 > 50%，考慮增加實體記憶體"
echo "  3. 設定 GCP 監控來追蹤記憶體使用趨勢"
echo ""
