# 升級路線圖與風險評估

> 記錄 2026-08 期間對「這個 fork 該怎麼跟上游走下去」的討論結論。
> 現況：已升級至上游 **v10.11.0**（ESR）基礎之上。

## 一、為什麼一定要升級

不是為了新功能，是為了**官方 App 還能連得上**。

Mattermost 的手機 App 與桌面 App 會逐步淘汰對舊 server 的支援。要繼續讓使用者用官方 App，
server 版本必須維持在支援範圍內。這是唯一真正的硬性期限——功能面上，v10.11 目前完全夠用。

| 期限 | 內容 |
|---|---|
| 2026-08-15 | v10.11 ESR 官方支援結束（不再有安全性修補） |
| 2027-05 前 | 需升到 v11.7 以維持官方 App 相容性 |

> ⚠️ 上述日期來自 2026-08 當時查詢 Mattermost 官方文件的結果，執行前應重新確認。

換句話說：**還有大約 9 個月的緩衝**，但期間必須自行承擔安全性修補的空窗。

## 二、v11 對本專案的三個衝擊

### 1. 中文搜尋會斷（最嚴重）

這是唯一「一定會壞、而且還沒有解法」的項目。

現況的中文搜尋靠 MySQL 全文索引，實作在 `server/channels/store/sqlstore/post_store.go`：

```go
searchClause := fmt.Sprintf("MATCH (%s) AGAINST (? IN BOOLEAN MODE)", searchType)
terms, err = removeMysqlStopWordsFromTerms(terms)
```

v11 移除了 MySQL 支援，這段程式碼失去載體。而替代方案都有問題：

| 方案 | 障礙 |
|---|---|
| Elasticsearch / OpenSearch | **需要企業版授權**。`server/public/model/license.go:148` 將 `Elasticsearch` 列為授權功能，而正式主機回報 `BuildEnterpriseReady: ""`（Team Edition） |
| Bleve | 免費，但 v11.7.0 已移除 `bleveengine`，`searchengine.go` 只剩 `ElasticsearchEngine` |
| PostgreSQL 原生 `to_tsvector` | 不做中文斷詞。「今天天氣很好」會被當成單一 token，搜「天氣」找不到 |
| PostgreSQL + `zhparser` / `pg_jieba` | 技術上可行，但需自行編譯擴充、自行改寫 `post_store.go` 的搜尋路徑，且未經驗證 |

**結論：中文搜尋方案是整條升級路線的前置條件，不是可以邊做邊想的細節。**

### 2. MySQL 支援移除 → 必須遷移到 PostgreSQL

見下節「PostgreSQL 遷移風險評估」。

### 3. 客製程式碼的重新套用成本

v10.10 → v10.11 的實測：12 個真實衝突。v10.11 → v11.x 跨越大版本，衝突數量與性質都會更嚴重。

**這次升級的實際教訓見 [`CUSTOMIZATIONS.md`](./CUSTOMIZATIONS.md)** ——
「衝突全部取上游」會靜默刪掉客製功能且編譯照樣通過。

## 三、PostgreSQL 遷移風險評估

### 🔴 高風險：中文搜尋

同上節。遷移的當下中文搜尋就會失效，不是漸進劣化。

### 🟢 低風險：已查證沒問題的項目

| 項目 | 查證結果 |
|---|---|
| `?` 佔位符 | `sqlx_wrapper.go:153` 呼叫 `Rebind()`，自動轉為 `$1, $2`，客製 SQL 不需改寫 |
| Whitelist migration | **PostgreSQL 版本已存在**：`migrations/postgres/000142_create_whitelist_table.up.sql` |
| `whitelist_store.go`（73 行） | 標準 SQL + `?` 佔位符，會被 Rebind 處理 |
| `channel_store.go` 客製（4 行） | 只是 `COALESCE(...) AS MentionCountRoot`，兩種資料庫語法相同 |
| `app/whitelist.go`（193 行） | 純 Go 邏輯，零資料庫分支判斷 |

### 🟡 中風險：可解但需驗證

**大小寫敏感性**
MySQL 預設 `utf8mb4_general_ci` 大小寫不敏感，PostgreSQL 敏感。
客製 SQL 中的 `Posts.Type NOT LIKE 'system_%'` 剛好全小寫不受影響，
但使用者名稱、頻道名稱的比對行為需實測。

**遷移工具**
版本庫內只有舊版 schema dump（`mattermost-mysql-*.sql`），**沒有 MySQL→PostgreSQL 轉換工具**。
需另外評估官方文件做法或 `pgloader`。資料量 5.7GB 決定停機窗口長度。

**migration 編號共存**
`000142` 兩種資料庫版本都在，但識別字大小寫慣例不同
（MySQL 用 `Whitelist`/`UserId`，PostgreSQL 用 `whitelist`/`userid`）。
符合 Mattermost 慣例，但**實際跑過才算數**。

## 四、建議順序

原本討論的順序是「先在 v10.11 換 DB + 中文搜尋，再升到最新版」。
這個順序需要修正一處：

```
1. 決定中文搜尋方案      ← 前置條件，不能跳過
2. 遷移到 PostgreSQL     ← 遷移當下就需要新的搜尋實作
3. 升級到 v11.7
```

理由：第 2 步一完成，`MATCH...AGAINST` 立刻失效。
如果第 1 步還沒有答案，遷移完就是「上線後中文搜不到」。

### 可以立刻開始的兩件低成本工作

**A. 本機驗證中文搜尋**
開一個 PostgreSQL、匯入部分正式資料，實測：
- 原生 `to_tsvector` 對中文的實際表現（預期：不可用，但要量化）
- 加上 `zhparser` 或 `pg_jieba` 後的表現
- 改寫 `post_store.go` 搜尋路徑的工作量

完全不碰正式環境，產出是「方案可不可行」的實證。

**B. 整理客製清單**
見 [`CUSTOMIZATIONS.md`](./CUSTOMIZATIONS.md)。趁 `backup/main-before-v1011` 分支還在，
把客製的意圖記錄下來——因為歷史改寫後 `git log -- <file>` 只看得到上游 commit。

## 五、其他已知待辦

| 項目 | 狀態 |
|---|---|
| Bleve 從未啟用 | `EnableIndexing: false`、`IndexDir` 空、無索引目錄、`ActiveSearchBackend: "database"`。`enable_bleve.sh` / `BLEVE_ACTIVATION_PLAN.md` 存在但未使用 |
| 未驗證的客製 | 訊息不合併、未讀計數、靜音頻道紅點、emoji 反應、IP 白名單——測試團隊頻道無資料，需在真實流量下驗證 |
| 主機安全 | SSH `PermitRootLogin yes` + `PasswordAuthentication yes`，累積 52,063 次登入失敗 |
| MySQL 3306 對外開放 | `allow-mysql-3306` 防火牆規則為 `0.0.0.0/0`。**經確認保留**（本地開發除錯用） |
