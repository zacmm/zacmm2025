#!/bin/bash

echo "🔄 切換到 Bleve 搜尋引擎"
echo "====================================="
echo ""

# 檢查是否在正確的目錄
if [ ! -d "server" ] || [ ! -f "server/config/config.json" ]; then
    echo "❌ 請在 Mattermost 根目錄執行此腳本"
    exit 1
fi

echo "📊 檢查索引狀態"
echo "----------"

# 檢查索引目錄
CURRENT_INDEX_DIR=$(python3 -c "import json; f=open('server/config/config.json'); c=json.load(f); print(c.get('BleveSettings', {}).get('IndexDir', '')); f.close()" 2>/dev/null)

if [ -z "$CURRENT_INDEX_DIR" ]; then
    echo "❌ 配置中未找到 IndexDir，請先執行 enable_bleve.sh"
    exit 1
fi

echo "📁 索引目錄: $CURRENT_INDEX_DIR"

# 檢查索引是否存在
if [ ! -d "$CURRENT_INDEX_DIR" ]; then
    echo "❌ 索引目錄不存在，請先執行 enable_bleve.sh 建立索引"
    exit 1
fi

# 檢查索引大小
INDEX_SIZE=$(du -sh "$CURRENT_INDEX_DIR" 2>/dev/null | cut -f1)
echo "📦 索引大小: $INDEX_SIZE"

# 如果索引太小，可能尚未建立完成
INDEX_SIZE_BYTES=$(du -s "$CURRENT_INDEX_DIR" 2>/dev/null | cut -f1)
if [ "$INDEX_SIZE_BYTES" -lt 1000000 ]; then
    echo "⚠️  警告：索引大小小於 1GB，可能尚未建立完成"
    echo "   建議等待索引建立完成後再切換"
    echo "   預期大小：3-5 GB（195 萬筆訊息）"
    echo ""
    read -p "是否仍要繼續切換？(y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""
echo "🔧 準備切換搜尋引擎"
echo "----------"

# 備份配置
BACKUP_FILE="server/config/config.json.backup_$(date +%Y%m%d_%H%M%S)"
echo "📋 備份配置檔案到: $BACKUP_FILE"
cp server/config/config.json "$BACKUP_FILE"

# 修改配置
echo "📝 啟用 Bleve 搜尋和自動完成..."
python3 << EOF
import json
import sys

config_file = 'server/config/config.json'

try:
    with open(config_file, 'r', encoding='utf-8') as f:
        config = json.load(f)

    # 檢查是否已啟用索引
    if not config.get('BleveSettings', {}).get('EnableIndexing'):
        print('❌ EnableIndexing 未啟用，請先執行 enable_bleve.sh', file=sys.stderr)
        sys.exit(1)

    # 啟用搜尋和自動完成
    config['BleveSettings']['EnableSearching'] = True
    config['BleveSettings']['EnableAutocomplete'] = True

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
echo "⚠️  切換說明"
echo "----------"
echo ""
echo "切換後的搜尋流程："
echo "  1️⃣  特殊字符搜尋（如 1,234、\$100）→ Bleve"
echo "  2️⃣  一般文字搜尋 → Bleve"
echo "  3️⃣  自動完成 → Bleve"
echo ""
echo "優點："
echo "  ✅ 搜尋速度提升 5-10 倍（10-50ms）"
echo "  ✅ 支援特殊字符搜尋"
echo "  ✅ 更準確的中文分詞"
echo ""
echo "注意事項："
echo "  ⚠️  切換後若有問題，可使用以下命令回滾："
echo "     cp $BACKUP_FILE server/config/config.json"
echo "     ./devops_backend_only.sh"
echo ""

read -p "是否現在重啟服務以啟用 Bleve 搜尋？(y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "🚀 正在重啟服務..."
    ./devops_backend_only.sh
else
    echo ""
    echo "✅ 配置完成！請手動重啟服務以啟用 Bleve 搜尋"
    echo "   重啟指令: ./devops_backend_only.sh"
fi

echo ""
echo "📊 驗證搜尋"
echo "----------"
echo "重啟後請測試："
echo "  1. 搜尋 '1,234' - 應該能找到包含千分位的數字"
echo "  2. 搜尋 '\$100' - 應該能找到包含金額的訊息"
echo "  3. 搜尋一般文字 - 應該比之前更快"
echo ""
echo "📚 詳細文檔: BLEVE_ACTIVATION_PLAN.md"
