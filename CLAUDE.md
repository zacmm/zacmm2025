# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 關於 Mattermost

Mattermost 是一個開源的協作平台，提供聊天、工作流自動化、語音通話、螢幕分享和 AI 整合功能。這個版本庫是 Mattermost 平台的主要開發源碼，使用 Go 和 React 編寫，以單一 Linux 二進制檔運行，並依賴 PostgreSQL。

## 本地開發環境啟動步驟

### 完整啟動流程
按照以下步驟在本地運行 Mattermost：

1. **確保 Docker Desktop 已啟動** (macOS/Windows)
   ```bash
   # macOS 啟動 Docker Desktop
   open -a Docker
   # 等待 Docker 完全啟動
   docker info
   ```

2. **啟動 Docker 服務** (資料庫、Redis、MinIO 等)
   ```bash
   # 在 server 目錄下執行
   cd server
   make start-docker
   ```

3. **啟動後端服務**
   ```bash
   # 在 server 目錄下執行
   make run-server
   # 服務會運行在 http://localhost:8065
   ```

4. **啟動前端開發服務** (在新的終端視窗)
   ```bash
   # 在 webapp 目錄下執行
   cd webapp
   npm run run  # 注意：是 'npm run run' 而不是 'npm run dev'
   ```

5. **訪問應用程式**
   - 打開瀏覽器訪問 http://localhost:8065
   - 首次訪問需要創建管理員帳號

### 停止服務
```bash
# 在 server 目錄下
make stop-docker  # 停止 Docker 容器
# 使用 Ctrl+C 停止後端和前端服務
```

## 常用開發命令

### 伺服器 (Go 後端)
```bash
# 建置並運行伺服器
make run-server

# 運行測試
make test-server

# 快速測試 (不包含長時間運行的測試)
make test-server-quick

# 檢查代碼風格
make check-style

# 修復代碼風格問題
make golangci-lint

# 建置二進制檔
make build

# 建置 mmctl 工具
make mmctl-build

# 生成模擬檔案
make mocks

# 運行類型檢查
make vet
```

### 前端 (React/TypeScript)
```bash
# 進入 webapp 目錄並運行前端開發服務
cd webapp && npm run run  # 正確的命令是 'npm run run'

# 建置前端
cd webapp && make dist

# 運行前端測試
cd webapp && make test

# 檢查 TypeScript 類型
cd webapp && npm run check-types

# 檢查代碼風格
cd webapp && npm run check

# 修復代碼風格問題
cd webapp && npm run fix
```

### 同時運行前後端
```bash
# 同時啟動伺服器和前端
make run

# 停止所有服務
make stop
```

### 測試命令
```bash
# 運行所有測試
make test

# 只運行 E2E 測試
cd e2e-tests && make run

# 運行特定套件的測試
cd server && go test ./channels/app/...
cd webapp && npm test -- --testNamePattern="specific test"
```

## 代碼架構

### 後端 (Go) 結構
- **`server/`** - 主要後端代碼
  - **`channels/app/`** - 核心業務邏輯層，包含所有主要功能的實現
  - **`channels/api4/`** - REST API 端點處理器
  - **`channels/store/`** - 數據存取層，包含資料庫操作
  - **`channels/web/`** - Web 相關處理器和中間件
  - **`channels/wsapi/`** - WebSocket API 處理器
  - **`platform/services/`** - 平台服務 (快取、搜尋引擎、共享通道等)
  - **`public/model/`** - 公共數據模型和結構體
  - **`cmd/mattermost/`** - 主要應用程式入口點
  - **`cmd/mmctl/`** - 命令列管理工具

### 前端 (React/TypeScript) 結構
- **`webapp/`** - 主要前端代碼
  - **`channels/`** - 主要 Web 應用程式
  - **`platform/`** - 共享平台組件和工具
    - **`client/`** - API 客戶端程式庫
    - **`types/`** - TypeScript 類型定義
    - **`components/`** - 可重用的 React 組件

### 關鍵架構模式
- **應用程式層** (`channels/app/`): 包含所有業務邏輯，是連接 API 和資料存取的核心
- **API 層** (`channels/api4/`): RESTful 端點，處理 HTTP 請求並調用應用程式層
- **存儲層** (`channels/store/`): 資料庫抽象層，支援 PostgreSQL 和 MySQL
- **WebSocket 層** (`channels/wsapi/`): 即時通訊功能的處理器
- **中間件和 Web 層**: 處理驗證、CORS、靜態檔案等

## 開發注意事項

### 資料庫
- 預設使用 PostgreSQL，也支援 MySQL
- 遷移檔案位於 `server/channels/db/migrations/`
- 使用 `make new-migration name=<migration_name>` 建立新的遷移

### Docker 支援
- 使用 `make start-docker` 啟動開發環境的 Docker 服務
- 包含 PostgreSQL、Redis、MinIO、Elasticsearch 等服務

### 企業版功能
- 企業版代碼位於 `enterprise/` 目錄 (需要額外的授權)
- 建置時可透過 `BUILD_ENTERPRISE=true` 啟用企業功能

### 測試環境
- 伺服器測試使用 Go 標準測試框架和 testify
- 前端測試使用 Jest 和 React Testing Library
- E2E 測試支援 Cypress 和 Playwright

### 代碼風格
- Go 代碼遵循 `golangci-lint` 規範
- 前端代碼使用 ESLint 和 Prettier
- 使用 `make check-style` 檢查整體代碼風格

## 插件開發
- 插件 API 位於 `server/public/plugin/`
- 預打包插件位於 `prepackaged_plugins/`
- 使用 `make plugin-checker` 驗證插件

## 國際化 (i18n)
- 翻譯檔案位於 `server/i18n/` 和 `webapp/platform/i18n/`
- 使用 `make i18n-extract` 提取翻譯字串

## 生產環境部署

部署採 **GitHub Actions 建置 + 主機拉取（pull-based）**，正式主機不編譯任何東西。

> ⚠️ `devops.sh` 與 `devops_backend_only.sh` 已於 2026-08-05 停用，執行會直接中止。
> 不要使用它們，也不要參考其內容撰寫新的部署方式。

### 相關檔案

- **`.github/workflows/deploy-build.yml`** — CI 建置，產物發布為 GitHub Release
- **`scripts/deploy/pull-deploy.sh`** — 主機端部署腳本
- **`setup_service.sh`** — 建立 systemd 服務（一次性，仍然有效）

### 日常部署流程

```bash
# 1. 本機：推送程式碼
git push origin main
#    → 異動 server/ 或 webapp/ 時，GitHub Actions 自動建置並發布 Release
#    → 也可在 Actions 頁面手動觸發 "Deploy Build"

# 2. 主機：拉取並部署
ssh mattermost_v1
cd /srv/gopath/src/github.com/zacmm/zacmm2025
./scripts/deploy/pull-deploy.sh
```

部署為人工執行，CI 不會自動上線。停機時間約 4 秒。

### pull-deploy.sh 選項

```bash
./scripts/deploy/pull-deploy.sh --dry-run     # 預覽步驟，不實際變更
./scripts/deploy/pull-deploy.sh --tag <tag>   # 部署指定版本
./scripts/deploy/pull-deploy.sh --rollback    # 回退上一版
```

流程：查詢 Release → 下載 → 驗證 SHA256 → 解壓 → 停止服務 → 以 `mv` 原子切換 →
啟動服務 → 健康檢查（`status` / `database_status` / `filestore_status` 三項，上限 3 分鐘）
→ 失敗自動回滾。舊版保留為 `server/bin/mattermost.prev` 與 `webapp/channels/dist.prev`。

### 確認線上執行的版本

```bash
curl -s 'http://127.0.0.1:8065/api/v4/config/client?format=old' \
  | tr ',' '\n' | grep -E 'BuildHash|BuildNumber|BuildDate'
```

`BuildHash` 是 CI 注入的 `GITHUB_SHA`，可直接對應 commit；
`BuildNumber` 是 `GITHUB_RUN_NUMBER`，本機編譯的產物會是 `dev`，可藉此分辨來源。

### 為什麼不在主機上編譯

- 主機沒有 node/npm，前端無法在主機建置
- 主機 4 核 / 8GB 且 swap 吃緊，編譯與服務搶記憶體有 OOM 風險
- CI 建置可追溯、有紀錄，且不佔用個人機器

### 前端產物路徑

`server/client` 是指向 `../webapp/channels/dist` 的 symlink，Go 服務由此提供靜態檔。
兩者都在 `.gitignore` 中，不隨 git 操作變動。

### 服務管理指令

```bash
# 服務控制
sudo systemctl start mattermost     # 啟動
sudo systemctl stop mattermost      # 停止
sudo systemctl restart mattermost   # 重啟
sudo systemctl status mattermost    # 狀態檢查

# 日誌查看
sudo journalctl -u mattermost -f    # 即時日誌
tail -f server/logs/mattermost.log  # 應用程式日誌

# 進程檢查
ps aux | grep mattermost            # 檢查進程
netstat -tlnp | grep :8065          # 檢查端口
```

### 注意事項

- 首次部署需要執行 `setup_service.sh` 來建立 systemd 服務
- 服務會在系統重開機後自動啟動
- 生產模式下前端靜態文件會直接由 Go 服務器提供
- 確保 nginx 配置代理到 `127.0.0.1:8065`