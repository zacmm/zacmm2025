#!/bin/bash
#
# ⛔ 此腳本已停用（2026-08-05）
#
# 原內容可於 git 歷史取得：git show HEAD~1:devops_backend_only.sh
#
# 停用原因同 devops.sh：在正式主機上編譯（4 核 / 8GB 且 swap 吃緊，有 OOM 風險）、
# 無健康檢查、無回滾機制、產物無法追溯到確切 commit。
# 本腳本只編譯後端，更容易造成前後端版本不一致。
#
# 注意：enable_bleve.sh 與 switch_to_bleve.sh 會呼叫本腳本，執行到該步驟時會停下來。
#       那兩個腳本中「重新編譯後端」的步驟，請改用下列部署流程。
#

cat <<'EOF'

⛔ devops_backend_only.sh 已停用

  現行部署流程：

    1. git push origin main            → GitHub Actions 自動建置並發布 Release
    2. 在主機執行：
         cd /srv/gopath/src/github.com/zacmm/zacmm2025
         ./scripts/deploy/pull-deploy.sh

  若只是要重啟服務（不更換版本）：

    sudo systemctl restart mattermost

EOF

exit 1
