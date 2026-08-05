#!/bin/bash
#
# ⛔ 此腳本已停用（2026-08-05）
#
# 原內容：git show f65d75e258:devops.sh
#
# 停用原因：
#   1. 正式主機沒有 node/npm，腳本的前端編譯分支永遠不會執行。它只印一行警告
#      就繼續往下走，最後仍回報「零停機部署完成」——前端實際上從未更新。
#      而它建議的替代方案（dist 放進 git）也不成立，webapp/.gitignore 排除了 dist。
#   2. 主機 4 核 / 8GB 且 swap 吃緊，在服務運行中編譯有 OOM 風險。
#   3. 沒有健康檢查與回滾機制，只確認 process 存在就宣告成功。
#   4. 產出的 binary 無法追溯到確切 commit。
#
# 改用：GitHub Actions 建置 + 主機拉取
#

cat <<'EOF'

⛔ devops.sh 已停用

  現行部署流程：

    1. 推送程式碼
         git push origin main
       → GitHub Actions 自動建置並發布 Release
         （僅在異動 server/ 或 webapp/ 時觸發）

    2. 在主機部署
         cd /srv/gopath/src/github.com/zacmm/zacmm2025
         ./scripts/deploy/pull-deploy.sh

  常用選項：

    ./scripts/deploy/pull-deploy.sh --dry-run    預覽將執行的步驟，不實際變更
    ./scripts/deploy/pull-deploy.sh --tag <tag>  部署指定版本
    ./scripts/deploy/pull-deploy.sh --rollback   回退上一版

  確認線上版本：

    curl -s 'http://127.0.0.1:8065/api/v4/config/client?format=old' \
      | tr ',' '\n' | grep BuildHash

  說明文件：scripts/deploy/pull-deploy.sh 檔頭註解

EOF

exit 1
