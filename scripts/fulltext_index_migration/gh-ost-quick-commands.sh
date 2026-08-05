#!/bin/bash
# =====================================================
# gh-ost 快速命令參考
# =====================================================

DB_HOST="34.87.11.83"
DB_USER="mmuser"
DB_PASS="mmpass"
DB_NAME="mattermost_prod_local"

echo "=========================================="
echo "gh-ost 快速命令參考"
echo "=========================================="
echo ""

cat << 'EOF'
## 1️⃣ 備份資料庫
mysqldump -h 34.87.11.83 -u mmuser -p'mmpass' \
  --single-transaction \
  --routines \
  --triggers \
  mattermost_prod_local > backup_$(date +%Y%m%d_%H%M%S).sql

## 2️⃣ 安裝 gh-ost
cd /tmp
wget https://github.com/github/gh-ost/releases/download/v1.1.6/gh-ost-binary-linux-amd64-20231207144046.tar.gz
tar -xzf gh-ost-binary-linux-amd64-20231207144046.tar.gz
sudo mv gh-ost /usr/local/bin/
sudo chmod +x /usr/local/bin/gh-ost
gh-ost --version

## 3️⃣ 執行 gh-ost（使用 screen）
screen -S gh-ost-migration

gh-ost \
  --host=34.87.11.83 \
  --port=3306 \
  --user=mmuser \
  --password=mmpass \
  --database=mattermost_prod_local \
  --table=Posts \
  --alter="DROP INDEX idx_posts_message_txt, ADD FULLTEXT INDEX idx_posts_message_txt (Message)" \
  --allow-on-master \
  --initially-drop-ghost-table \
  --initially-drop-old-table \
  --assume-rbr \
  --chunk-size=1000 \
  --max-load=Threads_running=50 \
  --critical-load=Threads_running=100 \
  --default-retries=120 \
  --serve-socket-file=/tmp/gh-ost.sock \
  --postpone-cut-over-flag-file=/tmp/ghost.postpone \
  --panic-flag-file=/tmp/ghost.panic \
  --exact-rowcount \
  --verbose \
  --execute

# 分離 screen: Ctrl+A 然後 D
# 重新連接: screen -r gh-ost-migration

## 4️⃣ 監控進度
watch -n 5 'echo "status" | nc -U /tmp/gh-ost.sock 2>/dev/null'

## 5️⃣ 互動控制
# 查看狀態
echo "status" | nc -U /tmp/gh-ost.sock

# 暫停
echo "throttle" | nc -U /tmp/gh-ost.sock

# 恢復
echo "no-throttle" | nc -U /tmp/gh-ost.sock

# 調整速度（減慢）
echo "chunk-size=500" | nc -U /tmp/gh-ost.sock

# 調整速度（加快）
echo "chunk-size=2000" | nc -U /tmp/gh-ost.sock

# 緊急暫停
touch /tmp/ghost.panic

# 取消緊急暫停
rm /tmp/ghost.panic

## 6️⃣ 允許最後切換
rm /tmp/ghost.postpone

## 7️⃣ 驗證結果
mysql -h 34.87.11.83 -u mmuser -p'mmpass' mattermost_prod_local -e "
SHOW INDEX FROM Posts WHERE Key_name = 'idx_posts_message_txt';
SELECT COUNT(*) FROM Posts WHERE DeleteAt = 0;
"

EOF
