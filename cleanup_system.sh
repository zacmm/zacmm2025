#!/bin/bash

# 系統清理腳本 - 釋放磁碟空間和記憶體

echo "🧹 系統清理工具"
echo "================"
echo ""

# 檢查是否在正確的目錄
if [ ! -d "server" ] || [ ! -f "README.md" ]; then
    echo "❌ 請在專案根目錄執行"
    exit 1
fi

echo "📊 清理前狀態："
echo "記憶體使用:"
free -h

echo ""
echo "磁碟使用:"
df -h .

echo ""
echo "日誌檔案大小:"
du -sh server/logs 2>/dev/null || echo "無日誌目錄"

echo ""
echo "===================="
echo ""

# ============================================
# 1. 清理舊日誌檔案
# ============================================

echo "1️⃣  清理舊日誌檔案（保留最近 7 天）"

if [ -d "server/logs" ]; then
    # 列出要刪除的檔案
    OLD_LOGS=$(find server/logs -name "*.log" -mtime +7 2>/dev/null)

    if [ -z "$OLD_LOGS" ]; then
        echo "   ✅ 沒有超過 7 天的日誌檔案"
    else
        echo "   將刪除以下檔案:"
        find server/logs -name "*.log" -mtime +7 -ls 2>/dev/null

        echo ""
        read -p "   確認刪除？(y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            find server/logs -name "*.log" -mtime +7 -delete 2>/dev/null
            echo "   ✅ 已刪除舊日誌檔案"
        else
            echo "   ⏭️  跳過"
        fi
    fi
else
    echo "   ⚠️  日誌目錄不存在"
fi

echo ""

# ============================================
# 2. 壓縮舊日誌
# ============================================

echo "2️⃣  壓縮舊日誌檔案（3 天前的檔案）"

if [ -d "server/logs" ]; then
    OLD_UNCOMPRESSED=$(find server/logs -name "*.log" -mtime +3 ! -name "*.gz" 2>/dev/null)

    if [ -z "$OLD_UNCOMPRESSED" ]; then
        echo "   ✅ 沒有需要壓縮的日誌檔案"
    else
        echo "   將壓縮以下檔案:"
        find server/logs -name "*.log" -mtime +3 ! -name "*.gz" -ls 2>/dev/null | head -5

        echo ""
        read -p "   確認壓縮？(y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            find server/logs -name "*.log" -mtime +3 ! -name "*.gz" -exec gzip {} \; 2>/dev/null
            echo "   ✅ 已壓縮舊日誌檔案"
        else
            echo "   ⏭️  跳過"
        fi
    fi
fi

echo ""

# ============================================
# 3. 清理臨時檔案
# ============================================

echo "3️⃣  清理臨時檔案"

# 清理 Go build cache
if [ -d "$HOME/.cache/go-build" ]; then
    CACHE_SIZE=$(du -sh "$HOME/.cache/go-build" 2>/dev/null | cut -f1)
    echo "   Go build cache 大小: $CACHE_SIZE"

    read -p "   是否清理 Go build cache？(y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$HOME/.cache/go-build"
        echo "   ✅ 已清理 Go build cache"
    else
        echo "   ⏭️  跳過"
    fi
fi

echo ""

# 清理 npm cache
if [ -d "webapp/.npm-cache" ]; then
    CACHE_SIZE=$(du -sh webapp/.npm-cache 2>/dev/null | cut -f1)
    echo "   npm cache 大小: $CACHE_SIZE"

    read -p "   是否清理 npm cache？(y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf webapp/.npm-cache
        echo "   ✅ 已清理 npm cache"
    else
        echo "   ⏭️  跳過"
    fi
fi

echo ""

# ============================================
# 4. 清理系統 cache（需要 sudo）
# ============================================

echo "4️⃣  清理系統 page cache（釋放記憶體）"
echo "   ⚠️  此操作需要 sudo 權限且會清空系統快取"
echo "   ⚠️  這是安全的操作，不會遺失資料"

read -p "   是否執行？(y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "   正在同步檔案系統..."
    sudo sync

    echo "   正在清理 page cache..."
    echo 1 | sudo tee /proc/sys/vm/drop_caches > /dev/null

    echo "   ✅ 已清理系統 cache"
else
    echo "   ⏭️  跳過"
fi

echo ""

# ============================================
# 5. 顯示清理後狀態
# ============================================

echo "===================="
echo ""
echo "📊 清理後狀態："
echo "記憶體使用:"
free -h

echo ""
echo "磁碟使用:"
df -h .

echo ""
echo "日誌檔案大小:"
du -sh server/logs 2>/dev/null || echo "無日誌目錄"

echo ""
echo "===================="
echo "✅ 清理完成！"
echo ""

# ============================================
# 6. 建議
# ============================================

echo "💡 建議："
echo ""
echo "1. 設定自動化日誌輪替:"
echo "   sudo nano /etc/logrotate.d/mattermost"
echo ""
echo "2. 定期執行此腳本（例如每週）:"
echo "   crontab -e"
echo "   0 2 * * 0 /path/to/cleanup_system.sh"
echo ""
echo "3. 監控系統狀態:"
echo "   ./monitor_system.sh"
echo ""
