# 客製清單與升級陷阱

> 這個版本庫是 Mattermost 的**快照式 fork**（`git init` + 單一初始 commit），
> 與上游沒有共同祖先。客製內容只能靠 `git diff <上游 tag> HEAD` 辨識，
> commit 訊息不保證還原得出「為什麼這樣改」。

## 一、2026-08-11 的真實事故：升級弄丟了兩個 API

### 症狀

```
取得白名單失敗 HTTP 404
{"id":"api.context.404.app_error",
 "detailed_error":"There doesn't appear to be an api call for the
                   url='/api/v4/users/{id}/whitelist'."}
```

### 根因

v10.11.0 升級時，`server/channels/api4/user.go` 與 `api4/team.go` 產生衝突，
當時以「取上游版本」解決，**整段客製 handler 被刪除**：

| 遺失內容 | 檔案 |
|---|---|
| `/users/{user_id}/whitelist` GET/POST/DELETE 三條路由 + 三個 handler | `api4/user.go` |
| `/teams/{team_id}/invite_id` 路由 + handler + `InviteIdResponse` | `api4/team.go` |

而衝突的**真正原因**是 v10.11 改了 audit API 名稱：

```go
// v10.10                          →  v10.11
audit.Fail                         →  model.AuditStatusFail
audit.AddEventParameter(rec, ...)  →  model.AddEventParameterToAuditRec(rec, ...)
```

正確做法是「保留 handler、改用新 API」，而不是整段丟掉。

### 為什麼沒被發現

- **編譯通過**——刪掉客製比修正客製更容易讓 build 綠燈
- **App / Store 層完好**——`app/whitelist.go`、`whitelist_store.go` 是**新增檔案**，不會衝突，所以活下來了
- **前端完好**——`client4.ts`、`whitelist_modal.tsx` 照樣呼叫，只是打到不存在的路由
- `invite_id` 甚至更隱蔽：`invitation_modal.tsx` 有 fallback 邏輯，靜默降級不報錯

### 教訓

> **新增的獨立檔案是安全的；插進上游檔案裡的客製才是會消失的那些。**

升級後的驗收不能只看「編譯過、服務起得來」，必須逐一比對客製清單。

### 修復時一併做的結構調整

修復沒有把 handler 放回原位，而是搬進 fork 專屬檔案：

| | 原本 | 現在 |
|---|---|---|
| 白名單 | `api4/user.go` 內 +135 行 | `api4/whitelist.go`（獨立檔） |
| 邀請碼 | `api4/team.go` 內 +48 行 | `api4/team_invite.go`（獨立檔） |
| 上游檔案足跡 | **183 行** | **`api.go` 的 3 行註冊** |

註冊集中在 `api4/api.go` 的 `InitAPI()` 尾端並用註解標記：

```go
// --- fork 客製端點（升級後請確認這個區塊仍存在）---
api.InitWhitelist()
api.InitTeamInvite()
```

這是上游自己的既有模式（`InitIPFiltering()`、`InitLimits()` 都是獨立檔案）。
效果：下次升級只要看 `git diff <tag> HEAD -- server/channels/api4/api.go`
就能確認客製端點是否還在，不必在 3,700 行的 `user.go` 裡找。

**`api4/post.go`（管理員訊息篩選）仍是就地插入，下次升級輪到它。** 建議比照辦理。

### 事後的系統性複查

修復後做了兩項全面掃描，確認沒有其他遺漏：

```bash
# 1. 路由層級：比對所有 .Handle("...") 註冊
#    結果：舊有而現無的路由 = 0

# 2. 函式層級：比對相對各自上游 tag 新增的 func 定義
#    結果：舊客製 87 個函式，無任何一個在 HEAD 中消失
```

## 二、客製分類

### A. 新增檔案（升級時**不會**衝突，安全）

| 檔案 | 行數 | 功能 |
|---|---|---|
| `server/channels/api4/whitelist.go` | 124 | 白名單 API（3 個端點） |
| `server/channels/api4/team_invite.go` | 46 | 邀請碼 API |
| `server/channels/app/whitelist.go` | 193 | IP 白名單 |
| `server/channels/store/sqlstore/whitelist_store.go` | 73 | 白名單 store |
| `server/public/model/whitelist_item.go` | 38 | 白名單 model |
| `server/channels/store/sqlstore/invite_store.go` | 56 | 邀請碼 store |
| `server/channels/store/localcachelayer/invite_layer.go` | 26 | 邀請碼快取 |
| `webapp/.../admin_console/posts/index.tsx` | 422 | 管理員訊息篩選頁面 |
| `webapp/.../admin_console/posts/posts.scss` | 339 | 同上樣式 |
| `webapp/.../admin_console/whitelist_modal/whitelist_modal.tsx` | 186 | 白名單管理介面 |
| `webapp/.../admin_console/remove_posts/index.tsx` | 119 | 批次刪文 |
| `webapp/.../team_settings/.../team_invite_section.tsx` | 127 | 團隊邀請碼區塊 |
| `webapp/.../post_view/reaction_details/*.tsx` | 146 | emoji 反應明細 |
| `webapp/.../message_filter/*` | 178 | 訊息篩選元件 |
| `webapp/src/sass/components/_custom-message-style.scss` | 336 | 訊息樣式客製 |
| `webapp/src/utils/custom_message_utils.js` | 176 | 訊息不合併邏輯 |
| `webapp/src/utils/license_utils.js` | 39 | 授權顯示客製 |

### B. 插入上游檔案（升級時**會**衝突，高風險）

**每次升級都必須逐一確認這些檔案的客製是否還在。**

| 檔案 | 差異 | 客製內容 |
|---|---|---|
| `server/channels/store/sqlstore/post_store.go` | +226/-26 | **中文全文搜尋**（`MATCH...AGAINST`）、管理員訊息篩選查詢 |
| `server/channels/api4/post.go` | +89 | 管理員訊息篩選 API（`/posts_all`）⚠️ **上游檔案，下次升級高風險** |
| `server/channels/app/post.go` | +99 | 管理員訊息篩選邏輯 ⚠️ **上游檔案** |
| `server/channels/web/handlers.go` | +85 | IP 白名單攔截中介層 ⚠️ **上游檔案** |
| `server/channels/api4/api.go` | +5 | `PostsAll` 路由前綴 + 客製端點註冊區塊 |
| `server/public/model/config.go` | +9 | `DeleteAccountLink` 設定 |
| `server/config/client.go` | +1 | 同上，送到前端 |
| `server/channels/store/sqlstore/channel_store.go` | +4/-4 | 未讀計數 `COALESCE` |
| `server/channels/store/sqlstore/team_store.go` | +12/-2 | 邀請碼相關 |
| `webapp/.../login/login.tsx` | +18/-3 | IP 白名單拒絕訊息 |
| `webapp/.../post/post_component.tsx` | +14/-10 | 訊息不合併 |
| `webapp/.../post_view/post_list_virtualized.tsx` | +48/-1 | 訊息列表客製 |
| `webapp/.../post_view/post_time/post_time.tsx` | +22/-6 | 時間顯示 |
| `webapp/.../post_view/reaction_list/reaction_list.tsx` | +31/-21 | emoji 反應 |
| `webapp/.../sidebar/.../channel_mention_badge.tsx` | +7/-3 | 靜音頻道紅點 |
| `webapp/.../sidebar/unread_channels.tsx` | +13/-2 | 未讀頻道 |
| `webapp/.../settings_sidebar/settings_sidebar.tsx` | +37/-12 | 設定側欄 |
| `webapp/.../user_settings/security/user_settings_security.tsx` | +27/-2 | 刪除帳號連結 |
| `webapp/.../system_users_list_actions/index.tsx` | +41/-2 | 白名單管理入口 |
| `webapp/src/store/index.ts` | +17/-3 | store 客製 |
| `webapp/src/utils/constants.tsx` | +5 | 常數 |

> 上表的行數為對 v10.11.0 的差異，含上游churn，僅供辨識用。
> 完整清單：`git diff --numstat v10.11.0 HEAD -- server/ webapp/channels/src/`

## 三、升級檢查清單

每次升級上游版本後，**在部署前**逐項確認：

```bash
# 1. 路由是否完整（最容易靜默遺失的一層）
for f in server/channels/api4/*.go; do
  grep -oE '\.Handle\("[^"]*"' "$f" | sed "s|^|$(basename $f) |"
done | sort -u > /tmp/routes_new.txt
# 與升級前的分支比對，comm -23 舊 新 應為空

# 2. 客製函式是否完整
git diff <舊上游tag> <備份分支> -- 'server/**/*.go' | grep -E "^\+func " | sort -u
# 逐一確認每個函式名在 HEAD 中仍存在

# 3. 關鍵字存在性檢查
for s in getUserWhitelist getInviteId DeleteAccountLink \
         removeMysqlStopWordsFromTerms; do
  echo "$s: $(grep -rl "$s" server/ webapp/channels/src/ 2>/dev/null | wc -l)"
done
```

### 功能面驗收（編譯通過不代表功能還在）

- [ ] 管理後台 → 使用者 → IP 白名單可開啟、可新增/刪除
- [ ] 團隊設定 → 邀請碼可顯示
- [ ] 中文搜尋可搜到中文訊息
- [ ] 管理後台 → 訊息篩選頁可查詢
- [ ] 訊息不合併（同一人連續發言不併成一則）
- [ ] 靜音頻道有紅點
- [ ] emoji 反應明細可展開
- [ ] 個人設定 → 安全性 → 刪除帳號連結存在（若有設定 `DeleteAccountLink`）

## 四、備份分支

| 分支 | 用途 |
|---|---|
| `backup/main-before-v1011` | v10.11.0 升級前的完整歷史（51 個 commit），**保留**——這是唯一還原「為什麼這樣改」的來源 |

歷史改寫之後 `git log -- <file>` 只看得到上游 commit，客製的逐筆來源已消失。
要判斷某段客製的意圖，必須查這個分支。
