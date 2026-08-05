# Fulltext 索引遷移專案

## 📁 專案說明

此資料夾包含用於解決 Mattermost 搜尋包含逗號的短詞（如 `1,234`、`$1,234`）無法找到的問題。

**問題根源**：MySQL `innodb_ft_min_token_size = 3`，導致逗號分隔後的短 token 無法被索引。

## 🎯 解決方案

提供兩種完整方案：

### 方案 A：啟用 Elasticsearch（推薦）⭐
- **優點**：設置簡單、搜尋功能更強大、可隨時啟用/停用
- **缺點**：需要額外服務、增加 1-2GB 記憶體使用
- **時間**：1-2 小時
- **文件**：`ELASTICSEARCH_SETUP.md`

### 方案 B：修改 MySQL 配置 + 重建索引
- **優點**：不需額外服務、保持現有架構
- **缺點**：執行時間較長、需要仔細規劃
- **時間**：4-6 小時
- **文件**：`gh-ost_execution_plan.md`

## 📊 環境資訊

- **資料庫主機**: 34.87.11.83
- **資料庫**: mattermost_prod_local
- **主要表**: Posts (1,813,704 筆，1.66 GB)
- **MySQL 版本**: 8.0.43
- **Binlog**: 已啟用 (ROW 格式) ✅

## 📦 檔案說明

### Elasticsearch 方案
- **`ELASTICSEARCH_SETUP.md`** - Elasticsearch 完整架設指南

### MySQL 索引重建方案
- **`gh-ost_execution_plan.md`** - 完整執行計畫（8000+ 字）
- **`gh-ost-monitor.sh`** - 互動式監控面板
- **`gh-ost-quick-commands.sh`** - 快速命令參考
- **`check_mysql_for_online_ddl.sh`** - 環境檢查腳本
- **`rebuild_fulltext_indexes.sql`** - SQL 腳本（備用，會鎖表）

## 🚀 快速決策指南

### 選擇 Elasticsearch 如果：
- ✅ 希望快速解決問題（1-2 小時）
- ✅ 伺服器有額外 1-2GB 記憶體
- ✅ 願意維護額外的搜尋服務
- ✅ 想要更強大的搜尋功能（模糊搜尋、同義詞等）

### 選擇 MySQL 索引重建如果：
- ✅ 偏好保持現有架構簡單
- ✅ 不想增加額外服務
- ✅ 可以接受較長的執行時間（4-6 小時）
- ✅ 有充足的磁碟空間（3.5+ GB）

## 📞 支援資源

- **Elasticsearch 方案**: 參閱 `ELASTICSEARCH_SETUP.md`
- **MySQL 方案**: 參閱 `gh-ost_execution_plan.md`
- **問題追蹤**: 詢問 Claude Code

---

**最後更新**: 2024-11-11
**版本**: 1.0
**狀態**: 待選擇方案並執行
