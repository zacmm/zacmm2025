# Bleve 搜尋引擎啟用計劃

## 📊 環境資訊

- **Mattermost 版本**：10.10.0
- **訊息總數**：1,948,479 筆
- **當前搜尋引擎**：MySQL FULLTEXT
- **目標搜尋引擎**：Bleve

## 🎯 目標與預期效果

### 為什麼啟用 Bleve？

1. **支援特殊字符搜尋**
   - ✅ 可以搜尋 "1,234"、"$100" 等包含特殊符號的內容
   - ✅ 不受 MySQL FULLTEXT 分詞限制

2. **更好的中文支援**
   - ✅ 更準確的中文分詞
   - ✅ 支援拼音搜尋（可選）

3. **性能提升**
   - ✅ 搜尋速度 10-50ms（vs MySQL 的 100-500ms）
   - ✅ 不會有 LIKE 查詢的全表掃描問題

### 預期資源需求

| 項目 | 需求 |
|------|------|
| **磁碟空間** | 3-5 GB（索引檔案） |
| **記憶體** | 2-4 GB（建立索引期間） |
| **CPU** | 建立索引時會較高負載 |
| **建立時間** | 30-60 分鐘 |

## 📝 啟用步驟（兩階段安全啟用）

### ⭐ 推薦流程：分階段啟用

為了降低風險，建議採用兩階段啟用方式：

**階段 A：建立索引（不影響現有搜尋）**
- 執行 `enable_bleve.sh`
- 設定：`EnableIndexing: true`, `EnableSearching: false`
- 結果：Bleve 在背景建立索引，使用者仍使用 MySQL 搜尋
- 時間：30-60 分鐘（建立索引）

**階段 B：切換到 Bleve 搜尋**
- 等待索引建立完成並驗證
- 執行 `switch_to_bleve.sh`
- 設定：`EnableSearching: true`, `EnableAutocomplete: true`
- 結果：立即切換到 Bleve 搜尋引擎
- 時間：< 1 分鐘（僅需重啟）

---

### 階段 1：準備階段（10 分鐘）

#### 1.1 檢查磁碟空間

```bash
# 在生產伺服器執行
df -h

# 確保 /srv 或數據目錄至少有 10GB 可用空間
```

#### 1.2 檢查當前配置

```bash
# 查看當前 Mattermost 配置
cd /srv/gopath/src/github.com/zacmm/zacmm2025/server
cat config/config.json | grep -A 5 "BleveSettings"
```

#### 1.3 備份配置

```bash
# 備份當前配置
cp config/config.json config/config.json.backup_$(date +%Y%m%d)
```

### 階段 2：配置 Bleve（5 分鐘）

#### 2.1 修改配置檔案（階段 A：僅建立索引）

使用 `enable_bleve.sh` 腳本會自動設定為：

```json
"BleveSettings": {
    "IndexDir": "/srv/gopath/src/github.com/zacmm/zacmm2025/server/data/bleve-indexes",
    "EnableIndexing": true,      // ✅ 建立索引
    "EnableSearching": false,    // ❌ 尚未切換搜尋（仍使用 MySQL）
    "EnableAutocomplete": false, // ❌ 尚未啟用自動完成
    "BatchSize": 10000
}
```

**配置說明**：
- `IndexDir`: 索引儲存位置（絕對路徑）
- `EnableIndexing`: 啟用索引建立（背景執行，不影響現有搜尋）
- `EnableSearching`: 是否使用 Bleve 搜尋（階段 A 設為 false）
- `EnableAutocomplete`: 是否啟用自動完成（階段 A 設為 false）
- `BatchSize`: 批次大小（10000 是推薦值）

#### 2.2 切換到 Bleve 搜尋（階段 B：索引建立完成後）

等待索引建立完成後，使用 `switch_to_bleve.sh` 腳本會更新為：

```json
"BleveSettings": {
    "IndexDir": "/srv/gopath/src/github.com/zacmm/zacmm2025/server/data/bleve-indexes",
    "EnableIndexing": true,      // ✅ 持續更新索引
    "EnableSearching": true,     // ✅ 使用 Bleve 搜尋
    "EnableAutocomplete": true,  // ✅ 啟用自動完成
    "BatchSize": 10000
}
```

#### 2.3 創建索引目錄

腳本會自動創建，也可手動執行：

```bash
# 創建索引目錄
mkdir -p /srv/gopath/src/github.com/zacmm/zacmm2025/server/data/bleve-indexes

# 設定權限
sudo chown -R mattermost:mattermost /srv/gopath/src/github.com/zacmm/zacmm2025/server/data
```

### 階段 3：建立索引（30-60 分鐘）

#### 3.1 執行 enable_bleve.sh（階段 A）

```bash
# 在專案根目錄執行
cd /srv/gopath/src/github.com/zacmm/zacmm2025
chmod +x enable_bleve.sh
./enable_bleve.sh
```

腳本會自動：
1. 檢查磁碟空間
2. 備份配置檔案
3. 設定 Bleve（僅 EnableIndexing: true）
4. 重啟服務開始建立索引

**重要**：此時搜尋仍使用 MySQL FULLTEXT，不會影響使用者

#### 3.2 監控索引建立進度

```bash
# 方法 1：查看日誌
sudo journalctl -u mattermost -f | grep -i "bleve\|index"

# 方法 2：檢查索引目錄大小
watch -n 5 'du -sh /srv/gopath/src/github.com/zacmm/zacmm2025/server/data/bleve-indexes'

# 方法 3：使用 API 查詢索引狀態（需要系統管理員權限）
curl -X GET 'http://localhost:8065/api/v4/elasticsearch/stats' \
  -H 'Authorization: Bearer YOUR_TOKEN'
```

#### 3.3 索引建立時間估算

```
195 萬筆訊息 ÷ 10000 (BatchSize) = 195 個批次
每批次約 15-20 秒
總時間：195 × 18秒 ≈ 58 分鐘
```

### 階段 4：切換到 Bleve 搜尋（< 5 分鐘）

#### 4.1 檢查索引狀態

```bash
# 檢查索引檔案是否生成
ls -lh /srv/gopath/src/github.com/zacmm/zacmm2025/server/data/bleve-indexes/

# 應該看到類似的檔案結構：
# posts.bleve/

# 檢查索引大小（應該約 3-5 GB）
du -sh /srv/gopath/src/github.com/zacmm/zacmm2025/server/data/bleve-indexes/
```

#### 4.2 執行 switch_to_bleve.sh（階段 B）

索引建立完成後，執行切換腳本：

```bash
# 在專案根目錄執行
cd /srv/gopath/src/github.com/zacmm/zacmm2025
chmod +x switch_to_bleve.sh
./switch_to_bleve.sh
```

腳本會自動：
1. 檢查索引大小（警告如果小於 1GB）
2. 備份配置檔案
3. 設定 EnableSearching: true 和 EnableAutocomplete: true
4. 重啟服務切換到 Bleve

**重要**：切換後所有搜尋都會使用 Bleve

### 階段 5：驗證與測試（10 分鐘）

#### 5.1 測試搜尋功能

在 Mattermost Web 介面測試：

1. **一般搜尋測試**
   - 搜尋常見詞彙（如："會議"）
   - 應該立即返回結果

2. **特殊字符搜尋測試**
   - 搜尋 "1,234"
   - 搜尋 "$100"
   - 搜尋 "#重要"
   - 應該都能找到相關結果

3. **中文搜尋測試**
   - 搜尋中文詞彙
   - 檢查分詞是否準確

#### 5.2 性能驗證

```bash
# 查看搜尋響應時間（應該在 50ms 以內）
# 在日誌中觀察 search 相關的執行時間
sudo journalctl -u mattermost -n 100 | grep "search"
```

### 階段 6：優化與調整（可選）

#### 6.1 記憶體優化

如果記憶體不足，可以調整 BatchSize：

```json
"BleveSettings": {
    ...
    "BatchSize": 5000  // 降低批次大小
}
```

#### 6.2 索引重建（如果需要）

```bash
# 使用 mmctl 重建索引
./server/bin/mmctl search elasticsearch purge --confirm
./server/bin/mmctl search elasticsearch index
```

## ⚠️ 注意事項

### 風險與對策

| 風險 | 對策 |
|------|------|
| **磁碟空間不足** | 確保至少有 10GB 可用空間 |
| **記憶體不足** | 建立索引期間可能影響服務性能，建議在低峰期進行 |
| **索引建立失敗** | 保留 MySQL FULLTEXT 作為備用，關閉 Bleve 即可回滾 |
| **搜尋結果不準確** | 可以調整 Bleve 的分詞設定或重建索引 |

### 回滾方案

#### 階段 A 回滾（索引建立階段）

如果索引建立有問題，只需停止索引建立：

```json
"BleveSettings": {
    "IndexDir": "/srv/gopath/src/github.com/zacmm/zacmm2025/server/data/bleve-indexes",
    "EnableIndexing": false,   // ❌ 停止索引建立
    "EnableSearching": false,
    "EnableAutocomplete": false,
    "BatchSize": 10000
}
```

此時搜尋仍使用 MySQL，影響極小。

#### 階段 B 回滾（搜尋切換階段）

如果 Bleve 搜尋有問題，立即切回 MySQL：

```json
"BleveSettings": {
    "IndexDir": "/srv/gopath/src/github.com/zacmm/zacmm2025/server/data/bleve-indexes",
    "EnableIndexing": true,    // ✅ 保持索引更新
    "EnableSearching": false,  // ❌ 切回 MySQL 搜尋
    "EnableAutocomplete": false,
    "BatchSize": 10000
}
```

或使用備份的配置檔案：

```bash
# 恢復配置
cp server/config/config.json.backup_YYYYMMDD_HHMMSS server/config/config.json

# 重啟服務
./devops_backend_only.sh
```

重啟服務後會自動回到 MySQL FULLTEXT 搜尋。

## 📊 性能對比（預期）

| 搜尋類型 | MySQL FULLTEXT | Bleve | 改善 |
|---------|---------------|-------|------|
| **一般文字** | 100-500ms | 10-50ms | 5-10x |
| **特殊字符** | 500-5000ms（LIKE） | 10-50ms | 10-100x |
| **中文搜尋** | 一般 | 更準確 | 質的提升 |

## ✅ 完成檢查清單

### 階段 A：建立索引（不影響搜尋）

- [ ] 確認磁碟空間充足（至少 10GB）
- [ ] 執行 `enable_bleve.sh` 腳本
- [ ] 確認配置：EnableIndexing: true, EnableSearching: false
- [ ] 重啟 Mattermost 服務
- [ ] 監控索引建立進度（watch 索引目錄大小）
- [ ] 等待索引建立完成（約 30-60 分鐘）
- [ ] 確認索引大小約 3-5 GB

### 階段 B：切換到 Bleve 搜尋

- [ ] 執行 `switch_to_bleve.sh` 腳本
- [ ] 確認配置：EnableSearching: true, EnableAutocomplete: true
- [ ] 重啟 Mattermost 服務
- [ ] 測試一般搜尋功能
- [ ] 測試特殊字符搜尋（1,234、$100 等）
- [ ] 測試中文搜尋
- [ ] 驗證性能提升（< 100ms）
- [ ] 記錄索引大小和建立時間
- [ ] 確認無錯誤日誌

## 📞 問題排查

### 問題 1：索引建立很慢

**原因**：資料庫查詢或磁碟 I/O 緩慢

**解決方案**：
- 降低 BatchSize 到 5000
- 確保資料庫連線正常
- 檢查磁碟 I/O 性能

### 問題 2：搜尋結果不完整

**原因**：索引尚未完全建立

**解決方案**：
- 等待索引完全建立
- 檢查日誌是否有錯誤

### 問題 3：記憶體使用過高

**原因**：BatchSize 太大

**解決方案**：
- 降低 BatchSize
- 在低峰期建立索引

## 🎉 成功標準

啟用成功的標誌：

1. ✅ 索引目錄大小約 3-5GB
2. ✅ 搜尋 "1,234" 能找到正確結果
3. ✅ 搜尋響應時間 < 100ms
4. ✅ 日誌中沒有 Bleve 相關錯誤
5. ✅ 服務運行穩定，無記憶體洩漏

---

**建立日期**：2025-11-12
**預計執行時間**：總計 1-2 小時（大部分時間是等待索引建立）
