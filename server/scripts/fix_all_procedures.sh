#!/bin/bash

# 批量修復所有 CREATE PROCEDURE 的 migration 檔案
# 在每個 CREATE PROCEDURE 前加入 DROP PROCEDURE IF EXISTS

cd "$(dirname "$0")/../channels/db/migrations/mysql" || exit 1

count=0
for file in *.sql; do
  if grep -q "^CREATE PROCEDURE" "$file" 2>/dev/null; then
    # 提取 procedure 名稱
    proc_name=$(grep "^CREATE PROCEDURE" "$file" | sed 's/CREATE PROCEDURE \([^ (]*\).*/\1/' | head -1)

    if [ -n "$proc_name" ]; then
      # 檢查是否已經有 DROP PROCEDURE
      if ! grep -q "DROP PROCEDURE IF EXISTS ${proc_name}" "$file"; then
        # 在 CREATE PROCEDURE 前加入 DROP PROCEDURE IF EXISTS
        sed -i.bak "s/^CREATE PROCEDURE ${proc_name}/DROP PROCEDURE IF EXISTS ${proc_name};\n\nCREATE PROCEDURE ${proc_name}/" "$file"
        echo "Fixed: $file ($proc_name)"
        count=$((count + 1))
      fi
    fi
  fi
done

echo ""
echo "Total fixed: $count files"
