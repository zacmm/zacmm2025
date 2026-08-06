#!/bin/bash

echo "🔍 Mattermost Bleve 搜尋引擎啟用腳本"
echo "===================================="
echo ""

# 檢查是否在正確的目錄
if [ ! -d "server" ] || [ ! -f "server/config/config.json" ]; then
    echo "❌ 請在 Mattermost 根目錄執行此腳本"
    exit 1
fi

echo "📊 環境檢查"
echo "----------"

# 檢查磁碟空間
AVAILABLE_SPACE=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
echo "📦 可用磁碟空間: ${AVAILABLE_SPACE}GB"

if [ "$AVAILABLE_SPACE" -lt 10 ]; then
    echo "⚠️  警告：磁碟空間不足 10GB，建議至少保留 10GB"
    read -p "是否繼續？(y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 查詢訊息總數（如果可以連接資料庫）
echo "📈 正在查詢訊息總數..."
POSTS_COUNT=$(mysql -h 34.87.11.83 -u mmuser -pmmpass -e "SELECT COUNT(*) FROM mattermost_prod_local.Posts;" 2>/dev/null | tail -1)
if [ ! -z "$POSTS_COUNT" ]; then
    echo "💬 總訊息數: $POSTS_COUNT 筆"
    ESTIMATED_SIZE=$((POSTS_COUNT / 400000))
    echo "📊 預估索引大小: ${ESTIMATED_SIZE}GB"
    ESTIMATED_TIME=$((POSTS_COUNT / 10000 * 18 / 60))
    echo "⏱️  預估建立時間: ${ESTIMATED_TIME} 分鐘"
else
    echo "⚠️  無法查詢訊息數量，跳過估算"
fi

echo ""
echo "🔧 開始配置 Bleve"
echo "----------"

# 備份配置
BACKUP_FILE="server/config/config.json.backup_$(date +%Y%m%d_%H%M%S)"
echo "📋 備份配置檔案到: $BACKUP_FILE"
cp server/config/config.json "$BACKUP_FILE"

# 創建索引目錄
INDEX_DIR="./server/data/bleve-indexes"
echo "📁 創建索引目錄: $INDEX_DIR"
mkdir -p "$INDEX_DIR"

# 取得絕對路徑
ABS_INDEX_DIR=$(cd "$(dirname "$INDEX_DIR")" && pwd)/$(basename "$INDEX_DIR")
echo "✅ 索引目錄: $ABS_INDEX_DIR"

# 修改配置
echo "📝 更新 Bleve 配置..."
python3 << EOF
import json
import sys

config_file = 'server/config/config.json'

try:
    with open(config_file, 'r', encoding='utf-8') as f:
        config = json.load(f)

    # 更新 Bleve 設定（僅建立索引，不切換搜尋）
    config['BleveSettings'] = {
        'IndexDir': '$ABS_INDEX_DIR',
        'EnableIndexing': True,      # ✅ 建立索引
        'EnableSearching': False,    # ❌ 尚未切換搜尋（仍使用 MySQL）
        'EnableAutocomplete': False, # ❌ 尚未啟用自動完成
        'BatchSize': 10000
    }

    with open(config_file, 'w', encoding='utf-8') as f:
        json.dump(config, f, indent=4, ensure_ascii=False)

    print('✅ 配置更新成功')
except Exception as e:
    print(f'❌ 配置更新失敗: {e}', file=sys.stderr)
    sys.exit(1)
EOF

if [ $? -ne 0 ]; then
    echo "❌ 配置更新失敗，恢復備份..."
    cp "$BACKUP_FILE" server/config/config.json
    exit 1
fi

echo ""
echo "📄 新的 Bleve 配置:"
grep -A 6 "BleveSettings" server/config/config.json

echo ""
echo "🎯 下一步操作（階段 A：建立索引）"
echo "----------"
echo ""
echo "⚠️  重要說明："
echo "   此配置僅啟用索引建立，搜尋仍使用 MySQL FULLTEXT"
echo "   使用者完全不會受到影響！"
echo ""
echo "1️⃣  重啟 Mattermost 服務開始建立索引："
echo "   ./devops_backend_only.sh"
echo ""
echo "2️⃣  監控索引建立進度："
echo "   # 方法 1: 查看日誌"
echo "   sudo journalctl -u mattermost -f | grep -i bleve"
echo ""
echo "   # 方法 2: 監控索引目錄大小（預期 3-5 GB）"
echo "   watch -n 5 'du -sh $ABS_INDEX_DIR'"
echo ""
echo "3️⃣  等待索引建立完成（約 30-60 分鐘）"
echo "   索引大小達到 3-5 GB 即表示完成"
echo ""
echo "4️⃣  切換到 Bleve 搜尋（階段 B）："
echo "   索引建立完成後，執行以下腳本切換搜尋引擎："
echo "   ./switch_to_bleve.sh"
echo ""
echo "⚠️  注意事項："
echo "   - 索引建立期間可能會佔用較多 CPU 和記憶體"
echo "   - 建議在低峰期執行"
echo "   - 索引建立期間，搜尋仍使用 MySQL（無影響）"
echo ""
echo "🔄 如需回滾，執行："
echo "   cp $BACKUP_FILE server/config/config.json"
echo "   ./devops_backend_only.sh"
echo ""
echo "📚 詳細文檔請參考: BLEVE_ACTIVATION_PLAN.md"
echo ""
read -p "是否現在重啟服務？(y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "🚀 正在重啟服務..."
    ./devops_backend_only.sh
else
    echo ""
    echo "✅ 配置完成！請手動重啟服務以啟用 Bleve"
fi
