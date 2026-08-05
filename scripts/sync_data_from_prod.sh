#!/bin/bash

# 同步生產環境的 data 目錄到本地開發環境
# 使用方式: ./sync_data_from_prod.sh

set -e

# 設定變數
REMOTE_HOST="mattermost"
REMOTE_DATA_PATH="/srv/gopath/src/github.com/zacmm/zacmm-server/data"
LOCAL_DATA_PATH="/srv/gopath/src/github.com/zacmm/zacmm2025/server/data"

echo "開始同步 data 目錄..."
echo "來源: ${REMOTE_HOST}:${REMOTE_DATA_PATH}"
echo "目標: ${LOCAL_DATA_PATH}"
echo ""

# 確認本地目錄存在
if [ ! -d "${LOCAL_DATA_PATH}" ]; then
    echo "本地目錄不存在，正在建立: ${LOCAL_DATA_PATH}"
    mkdir -p "${LOCAL_DATA_PATH}"
fi

# 使用 rsync 同步
# -a: archive mode (保留權限、時間戳等)
# -v: verbose (顯示詳細資訊)
# -z: compress (傳輸時壓縮)
# -P: 顯示進度並保留部分傳輸的檔案
# --delete: 刪除目標目錄中來源不存在的檔案
rsync -avzP \
    --delete \
    "${REMOTE_HOST}:${REMOTE_DATA_PATH}/" \
    "${LOCAL_DATA_PATH}/"

echo ""
echo "同步完成！"

# 顯示目錄大小
echo ""
echo "目錄大小:"
du -sh "${LOCAL_DATA_PATH}"
