#!/usr/bin/env bash
#
# 正式環境部署腳本（在主機上執行）
#
# 從 GitHub Release 拉取 CI 建置好的產物並部署。採 pull-based 架構，
# 全程只有主機對 GitHub 的 outbound HTTPS，不需開放任何 inbound port。
#
# 用法：
#   ./pull-deploy.sh                 部署最新的 Release
#   ./pull-deploy.sh --tag <tag>     部署指定版本
#   ./pull-deploy.sh --dry-run       只顯示將要做什麼，不實際執行
#   ./pull-deploy.sh --rollback      回到上一版
#
# 產物來源：.github/workflows/deploy-build.yml

set -euo pipefail

REPO="zacmm/zacmm2025"
APP_DIR="/srv/gopath/src/github.com/zacmm/zacmm2025"
BIN_DIR="${APP_DIR}/server/bin"
DIST_DIR="${APP_DIR}/webapp/channels/dist"
PING_URL="http://127.0.0.1:8065/api/v4/system/ping"
SERVICE="mattermost"
WORK_DIR="/tmp/mm-deploy-$$"

DRY_RUN=false
ROLLBACK=false
TAG=""

log()  { printf '%s  %s\n' "$(date '+%H:%M:%S')" "$*"; }
die()  { printf '\n❌ %s\n' "$*" >&2; exit 1; }
run()  { if $DRY_RUN; then echo "      [dry-run] $*"; else eval "$@"; fi; }

cleanup() { rm -rf "${WORK_DIR}"; }
trap cleanup EXIT

# ---------------------------------------------------------------------------
# 參數解析
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)  DRY_RUN=true; shift ;;
    --rollback) ROLLBACK=true; shift ;;
    --tag)      TAG="${2:-}"; shift 2 ;;
    -h|--help)  sed -n '2,20p' "$0"; exit 0 ;;
    *)          die "未知參數：$1" ;;
  esac
done

# ---------------------------------------------------------------------------
# 健康檢查
#
# 回傳 0 表示健康，非 0 表示失敗（呼叫端會觸發自動回滾）。
#
# 檢查 ping?get_server_status=true，要求 status、database_status、
# filestore_status 三項全為 OK 才算通過。只看 HTTP 200 不夠——服務在資料庫
# 連不上的狀態下仍可能回應 200，那種部署放行了等於沒檢查。
#
# 上限 3 分鐘：一般啟動約 10-30 秒，留足緩衝避免誤判；但資料庫 5.7GB 而
# innodb_buffer_pool_size 僅 128MB，冷啟動偏慢，所以不壓到 1 分鐘。
# 用 SECONDS 計算截止時間而非固定重試次數，確保連同 curl 逾時在內真的不超過 3 分鐘。
# ---------------------------------------------------------------------------
health_check() {
  local timeout=180   # 總等待上限（秒）
  local interval=5    # 每次檢查間隔（秒）
  local url="${PING_URL}?get_server_status=true"
  local deadline=$(( SECONDS + timeout ))
  local started=${SECONDS}
  local body=""

  while (( SECONDS < deadline )); do
    body=$(curl -sf --max-time 3 "${url}" 2>/dev/null) || body=""

    # 注意：'"status":"OK"' 是 '"database_status":"OK"' 的子字串，
    # 必須用前置的 , 或 { 錨定，否則三項只要有一項 OK 就會全部誤判成通過
    if [[ -n "${body}" ]] \
       && grep -qE '[,{]"status":"OK"'       <<< "${body}" \
       && grep -q   '"database_status":"OK"' <<< "${body}" \
       && grep -q   '"filestore_status":"OK"' <<< "${body}"; then
      log "   通過（耗時 $(( SECONDS - started )) 秒）"
      return 0
    fi

    sleep "${interval}"
  done

  log "   逾時：${timeout} 秒內未通過"
  [[ -n "${body}" ]] && log "   最後回應：${body:0:200}" || log "   服務完全沒有回應"
  return 1
}

# ---------------------------------------------------------------------------
# 回滾
# ---------------------------------------------------------------------------
do_rollback() {
  log "↩️  執行回滾"
  [[ -f "${BIN_DIR}/mattermost.prev" ]] || die "找不到上一版 binary，無法回滾"
  [[ -d "${DIST_DIR}.prev" ]]           || die "找不到上一版前端，無法回滾"

  run "sudo systemctl stop ${SERVICE}"
  run "mv -f '${BIN_DIR}/mattermost' '${BIN_DIR}/mattermost.failed'"
  run "mv -f '${BIN_DIR}/mattermost.prev' '${BIN_DIR}/mattermost'"
  run "rm -rf '${DIST_DIR}.failed' && mv '${DIST_DIR}' '${DIST_DIR}.failed'"
  run "mv '${DIST_DIR}.prev' '${DIST_DIR}'"
  run "sudo systemctl start ${SERVICE}"

  if $DRY_RUN || health_check; then
    # 必須清掉版本記錄：回滾後執行中的已不是記錄裡那一版，
    # 若保留舊記錄，下次部署會誤判「已經是這個版本了」而拒絕執行，
    # 導致回滾之後推不回去。
    $DRY_RUN || rm -f "${APP_DIR}/.deployed-version"
    log "✅ 回滾完成，服務已恢復"
    log "   版本記錄已清除，可直接執行部署推回新版"
  else
    die "回滾後服務仍不健康，需要人工介入：sudo journalctl -u ${SERVICE} -n 100"
  fi
}

if $ROLLBACK; then
  do_rollback
  exit 0
fi

# ---------------------------------------------------------------------------
# 1. 取得 Release 資訊
# ---------------------------------------------------------------------------
log "🔍 查詢 Release"
API="https://api.github.com/repos/${REPO}/releases"
[[ -n "${TAG}" ]] && API="${API}/tags/${TAG}" || API="${API}/latest"

META=$(curl -sfL "${API}") || die "無法取得 Release 資訊，請確認網路與 tag 是否存在"
TAG=$(echo "${META}" | grep -m1 '"tag_name"' | cut -d'"' -f4)
[[ -n "${TAG}" ]] || die "解析 tag 失敗"

log "   版本：${TAG}"

# 分支建置會標記為 prerelease，不會出現在 /releases/latest；
# 只有明確 --tag 指定時才可能走到這裡，此時提醒使用者確認是刻意為之。
if grep -q '"prerelease": *true' <<< "${META}"; then
  SRC=$(grep -m1 '來源分支' <<< "${META}" | sed 's/.*來源分支：\\`\([^\\]*\)\\`.*/\1/')
  log "   ⚠️  這是分支建置（prerelease）${SRC:+，來源分支：${SRC}}"
  log "       部署未合併的版本請確認是刻意為之"
fi

# 目前執行中的版本，供比對
CURRENT=$(cat "${APP_DIR}/.deployed-version" 2>/dev/null || echo "未知")
log "   目前：${CURRENT}"

if [[ "${TAG}" == "${CURRENT}" ]]; then
  log "⚠️  已經是這個版本了，若要強制重新部署請先刪除 ${APP_DIR}/.deployed-version"
  exit 0
fi

# ---------------------------------------------------------------------------
# 2. 下載並驗證
# ---------------------------------------------------------------------------
mkdir -p "${WORK_DIR}"
BASE="https://github.com/${REPO}/releases/download/${TAG}"

log "⬇️  下載產物"
for f in server-linux-amd64.tar.gz webapp-dist.tar.gz SHA256SUMS; do
  curl -sfL --retry 3 -o "${WORK_DIR}/${f}" "${BASE}/${f}" || die "下載 ${f} 失敗"
  log "   ${f}  $(du -h "${WORK_DIR}/${f}" | cut -f1)"
done

log "🔐 驗證校驗碼"
(cd "${WORK_DIR}" && sha256sum -c SHA256SUMS) || die "校驗碼不符，產物可能損毀"

log "📦 解壓"
mkdir -p "${WORK_DIR}/server" "${WORK_DIR}/webapp"
tar xzf "${WORK_DIR}/server-linux-amd64.tar.gz" -C "${WORK_DIR}/server"
tar xzf "${WORK_DIR}/webapp-dist.tar.gz"        -C "${WORK_DIR}/webapp"
[[ -f "${WORK_DIR}/server/mattermost" ]]        || die "產物不完整：缺少 mattermost"
[[ -f "${WORK_DIR}/webapp/dist/root.html" ]]    || die "產物不完整：缺少前端 root.html"

# ---------------------------------------------------------------------------
# 3. 切換（服務會中斷數十秒）
# ---------------------------------------------------------------------------
log "⏸️  停止服務"
run "sudo systemctl stop ${SERVICE}"

log "🔄 切換版本"
run "rm -f '${BIN_DIR}/mattermost.prev' '${BIN_DIR}/mmctl.prev'"
run "mv -f '${BIN_DIR}/mattermost' '${BIN_DIR}/mattermost.prev'"
run "mv -f '${BIN_DIR}/mmctl' '${BIN_DIR}/mmctl.prev' 2>/dev/null || true"
run "mv '${WORK_DIR}/server/mattermost' '${BIN_DIR}/mattermost'"
run "mv '${WORK_DIR}/server/mmctl' '${BIN_DIR}/mmctl'"

run "rm -rf '${DIST_DIR}.prev'"
run "mv '${DIST_DIR}' '${DIST_DIR}.prev'"
run "mv '${WORK_DIR}/webapp/dist' '${DIST_DIR}'"

run "chmod +x '${BIN_DIR}/mattermost' '${BIN_DIR}/mmctl'"
run "sudo chown -R mattermost:mattermost '${BIN_DIR}' '${DIST_DIR}'"

log "▶️  啟動服務"
run "sudo systemctl start ${SERVICE}"

# ---------------------------------------------------------------------------
# 4. 驗證，失敗則自動回滾
# ---------------------------------------------------------------------------
log "🩺 健康檢查"
if $DRY_RUN || health_check; then
  $DRY_RUN || echo "${TAG}" > "${APP_DIR}/.deployed-version"
  log "✅ 部署完成：${TAG}"
  log "   上一版保留於 mattermost.prev 與 dist.prev，可用 --rollback 回退"
else
  log "❌ 健康檢查未通過，自動回滾中"
  do_rollback
  exit 1
fi
