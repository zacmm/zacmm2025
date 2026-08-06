# Mattermost 管理腳本集

本目錄包含用於 Mattermost 系統管理、部署和故障排除的腳本工具。

## 資料庫設定腳本

### `setup_mysql_remote.sh`
**功能**：設定 MySQL 遠端連線配置  
**用途**：配置 MySQL 伺服器允許遠端連接，包含防火牆設定、用戶權限配置  
**執行**：`sudo ./setup_mysql_remote.sh`

### `setup_mysql_remote.sql`
**功能**：MySQL 遠端用戶權限設定 SQL 腳本  
**用途**：建立 `mmuser` 用戶並授予 `mattermost_dev` 資料庫權限  
**執行**：`mysql -u root -p < setup_mysql_remote.sql`

## 診斷檢查腳本

### `check_production_db.sh`
**功能**：檢查正式環境資料庫配置和狀態  
**用途**：診斷正式環境的資料庫連線設定、進程狀態、環境變數等  
**執行**：`./check_production_db.sh`

### `check_production_permissions.sh`
**功能**：檢查正式環境使用者權限  
**用途**：驗證使用者權限分配和角色設定  
**執行**：`./check_production_permissions.sh`

### `debug_production_config.sh`
**功能**：診斷正式環境配置問題  
**用途**：深度分析系統配置、角色權限、系統設定  
**執行**：`./debug_production_config.sh`

### `find_db_config.sh`
**功能**：搜尋資料庫配置檔案  
**用途**：自動定位 Mattermost 配置檔案位置  
**執行**：`./find_db_config.sh`

## 權限管理腳本

### `fix_permission_tags.sql`
**功能**：修復錯誤的權限標籤 SQL 腳本  
**用途**：清理資料庫中格式錯誤的權限標籤（如 `sysconsole_read_*_read`）  
**執行**：`mysql -h HOST -u USER -p DATABASE < fix_permission_tags.sql`

### `fix_remote_permissions.sh`
**功能**：修復遠端 Mattermost 權限標籤  
**用途**：執行權限標籤修復並驗證結果  
**執行**：`./fix_remote_permissions.sh`

## 使用者管理腳本

### `create_admin_user.sh`
**功能**：建立新的系統管理員帳號  
**用途**：透過資料庫直接建立具有管理員權限的使用者  
**執行**：`./create_admin_user.sh`
**注意**：建議使用 mmctl 工具替代此腳本

### `fix_playplus_password.sh`
**功能**：修復 playplus 帳號密碼  
**用途**：同步 playplus 和 plusplus 帳號的密碼雜湊值  
**執行**：`./fix_playplus_password.sh`

### `reset_playplus_password.sh`
**功能**：重設 playplus 密碼指令說明  
**用途**：提供使用 Mattermost CLI 重設密碼的標準方法  
**執行**：查看腳本內容，按照說明執行

## 服務管理腳本

### `restart_remote_service.sh`
**功能**：重新啟動遠端 Mattermost 服務  
**用途**：安全地停止和重新啟動遠端 Mattermost 服務  
**執行**：`./restart_remote_service.sh`
**要求**：需要 SSH 金鑰配置

## 使用建議

### 執行前檢查
1. **權限確認**：確保腳本具有執行權限 (`chmod +x script_name.sh`)
2. **環境檢查**：確認資料庫連線資訊正確
3. **備份資料**：執行資料庫變更前建議先備份

### 資料庫連線資訊
```bash
DB_HOST="34.143.235.227"
DB_PORT="3306" 
DB_USER="mmuser"
DB_PASS="mmpass"
DB_NAME="mattermost_dev"
```

### 常用工具
- **mmctl**：建議使用官方 CLI 工具進行使用者和系統管理
- **MySQL CLI**：用於直接資料庫操作和診斷
- **systemctl**：服務管理（如果有 systemd 服務）

## 安全注意事項

⚠️ **重要警告**：
- 這些腳本包含敏感資訊（密碼、資料庫連線）
- 請勿將包含實際密碼的腳本提交到版本控制
- 執行前請確認目標環境，避免影響正式服務
- 建議在測試環境先驗證腳本功能

## 腳本開發歷程

這些腳本是在解決以下問題時開發的：
1. 權限標籤格式錯誤導致的 403 錯誤
2. 遠端資料庫連線和配置問題  
3. 使用者帳號建立和權限分配
4. 系統診斷和故障排除

建立時間：2025年8月22-25日  
適用版本：Mattermost 2025 版本