#!/usr/bin/env bash
# 清理 Mattermost data 目錄中超過 N 天的舊上傳檔案
# 配套腳本: scripts/cleanup_old_data.sh 清理同一保留期的 DB 列 (Posts/FileInfo)
# 用法: mattermost-data-cleanup.sh [--dry-run] [--days N] [--quiet]
set -uo pipefail

# 以 idle IO 與最低 CPU 優先度重啟自身,避免與 prod Mattermost 競爭資源
if [ -z "${MM_CLEANUP_NICED:-}" ] && command -v ionice >/dev/null 2>&1; then
  export MM_CLEANUP_NICED=1
  exec ionice -c3 nice -n 19 "$0" "$@"
fi

BASE_DIR="/srv/gopath/src/github.com/zacmm/zacmm2025/server/data"
DAYS=365
DRY_RUN=false
QUIET=false
LOG_DIR="/var/log/mattermost-cleanup"
LOCK_FILE="/var/lock/mattermost-cleanup.lock"
KEEP_REPORTS=30

# 永不清理的頂層目錄 (使用者大頭照、自訂 emoji,刪掉無法重新產生)
SKIP_DIRS=("users" "emoji")

usage() {
  cat <<EOF
Usage: $0 [--dry-run] [--days N] [--quiet]
  --dry-run    只列要刪的內容,不實際刪除
  --days N     mtime 超過 N 天才刪 (預設 $DAYS)
  --quiet      不寫到 stdout,只寫報告檔
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --days)    DAYS="$2"; shift 2 ;;
    --quiet)   QUIET=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[ -d "$BASE_DIR" ] || { echo "BASE_DIR 不存在: $BASE_DIR" >&2; exit 1; }
[[ "$DAYS" =~ ^[0-9]+$ ]] || { echo "--days 必須是數字" >&2; exit 1; }

mkdir -p "$LOG_DIR"
REPORT="$LOG_DIR/$(date +'%Y%m%d_%H%M%S')_cleanup.log"

if [ "$QUIET" = true ]; then
  exec >"$REPORT" 2>&1
else
  exec > >(tee -a "$REPORT") 2>&1
fi

exec 200>"$LOCK_FILE"
if ! flock -n 200; then
  echo "[$(date '+%F %T')] 另一個清理程序正在執行,跳過。"
  exit 0
fi

echo "=== Mattermost data 清理 $(date '+%F %T') ==="
echo "BASE_DIR  : $BASE_DIR"
echo "保留天數  : $DAYS 天 (刪 mtime > $DAYS 天)"
echo "DRY_RUN   : $DRY_RUN"
echo "REPORT    : $REPORT"
echo ""

echo "--- 開始前 df ---"
df -h "$BASE_DIR" /
echo ""

finish() {
  echo ""
  echo "--- 結束時 df ---"
  df -h "$BASE_DIR" / 2>/dev/null || true
  ls -1t "$LOG_DIR"/*_cleanup.log 2>/dev/null | tail -n +$((KEEP_REPORTS+1)) | xargs -r rm -f
}
trap finish EXIT

TOTAL_BYTES=0
TOTAL_FILES=0
TOTAL_EMPTY_DIRS=0
TOTAL_TOP_DIRS_REMOVED=0

DELETE_FLAG=()
[ "$DRY_RUN" = false ] && DELETE_FLAG=(-delete)

echo "--- 處理日期目錄 ---"
printf '%-12s %8s %12s %12s %8s\n' "DATE_DIR" "FILES" "BYTES" "EMPTY_DIRS" "REM_TOP"

shopt -s nullglob
for folder in "$BASE_DIR"/*/; do
  folder_name="${folder%/}"; folder_name="${folder_name##*/}"

  skip=false
  for s in "${SKIP_DIRS[@]}"; do
    [ "$folder_name" = "$s" ] && skip=true && break
  done
  if [ "$skip" = true ]; then
    printf '%-12s %s\n' "$folder_name" "(SKIPPED: 受保護目錄)"
    continue
  fi

  # -depth 讓 find 由葉到根;檔案先被刪掉,父目錄在回程才檢查 -empty,
  # 因此檔案+空目錄可在單次 traversal 完成,省一次 ~O(inode) 的掃描
  read -r files bytes empty_dirs < <(
    find "$folder" -mindepth 1 -depth \
      \( -type f -mtime "+$DAYS" -printf 'f %s\n' "${DELETE_FLAG[@]}" \) -o \
      \( -type d -empty           -printf 'd 0\n' "${DELETE_FLAG[@]}" \) \
      2>/dev/null \
      | awk 'BEGIN{fc=0; bytes=0; dc=0}
             $1=="f" { fc++; bytes+=$2 }
             $1=="d" { dc++ }
             END    { printf "%d %d %d\n", fc, bytes, dc }'
  )

  top_removed=0
  if [ -z "$(ls -A "$folder" 2>/dev/null)" ]; then
    if [ "$DRY_RUN" = false ]; then
      rmdir "$folder" 2>/dev/null && top_removed=1
    else
      top_removed=1
    fi
  fi

  if [ "$files" -gt 0 ] || [ "$empty_dirs" -gt 0 ] || [ "$top_removed" -gt 0 ]; then
    human=$(numfmt --to=iec --format='%.2f' "$bytes" 2>/dev/null || echo "${bytes}B")
    printf '%-12s %8d %12s %12d %8d\n' \
      "$folder_name" "$files" "$human" "$empty_dirs" "$top_removed"
  fi

  TOTAL_FILES=$((TOTAL_FILES + files))
  TOTAL_BYTES=$((TOTAL_BYTES + bytes))
  TOTAL_EMPTY_DIRS=$((TOTAL_EMPTY_DIRS + empty_dirs))
  TOTAL_TOP_DIRS_REMOVED=$((TOTAL_TOP_DIRS_REMOVED + top_removed))
done

echo ""
echo "=== 總計 ==="
human_total=$(numfmt --to=iec --format='%.2f' "$TOTAL_BYTES" 2>/dev/null || echo "${TOTAL_BYTES}B")
echo "刪除檔案數      : $TOTAL_FILES"
echo "釋放空間        : $TOTAL_BYTES bytes ($human_total)"
echo "刪除空子目錄    : $TOTAL_EMPTY_DIRS"
echo "刪除空日期目錄  : $TOTAL_TOP_DIRS_REMOVED"
if [ "$DRY_RUN" = true ]; then
  echo "*** DRY-RUN 模式,未實際刪除 ***"
fi
exit 0
