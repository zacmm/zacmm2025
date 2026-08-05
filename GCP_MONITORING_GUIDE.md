# GCP Cloud Monitoring 使用指南

## 📊 GCP 內建監控系統

GCP 提供了強大的 **Cloud Monitoring**（原 Stackdriver）服務，可以監控：
- CPU 使用率
- 記憶體使用率
- 磁碟 I/O（讀寫速率）
- 網路流量
- 自訂指標

**優勢**：
✅ 視覺化圖表（比腳本更直觀）
✅ 歷史資料保存（可回溯）
✅ 自動告警（Email、SMS、Slack）
✅ 無需安裝額外軟體
✅ 整合 GCP 生態系統

---

## 🚀 快速開始

### 方法 1：使用 GCP Console（最簡單）

#### 1. 查看 VM 監控儀表板

1. 登入 [GCP Console](https://console.cloud.google.com/)
2. 前往 **Compute Engine** > **VM 執行個體**
3. 點擊你的 VM 名稱
4. 點擊上方的 **「監控」** 分頁

**可以看到**：
- CPU 使用率（過去 1 小時/1 天/1 週）
- 記憶體使用率
- 磁碟讀寫速率
- 網路流入/流出

#### 2. 查看詳細監控

前往 **Cloud Monitoring** 完整介面：

1. 左側選單 > **監控** (Monitoring)
2. 或直接訪問：https://console.cloud.google.com/monitoring

**主要功能**：
- **儀表板**：視覺化圖表
- **指標瀏覽器**：自訂查詢
- **告警**：設定閾值自動通知
- **正常運作時間檢查**：監控服務可用性

---

## 📈 關鍵指標監控

### 1. 記憶體使用率（最重要）

**如何查看**：

1. 前往 **Cloud Monitoring** > **指標瀏覽器**
2. 選擇資源類型：`VM Instance`
3. 選擇指標：
   - `agent.googleapis.com/memory/percent_used` - 記憶體使用百分比
   - `agent.googleapis.com/memory/bytes_used` - 使用量（bytes）

**圖表設定**：
- 時間範圍：1 天或 1 週
- 聚合：平均值（Average）
- 查看趨勢：是否持續增長（記憶體洩漏）

**⚠️ 注意**：
如果看不到記憶體指標，需要安裝 **Ops Agent**（見下方）

### 2. 磁碟 I/O（寫入速率）

**指標**：
- `compute.googleapis.com/instance/disk/write_bytes_count` - 寫入總量
- `compute.googleapis.com/instance/disk/write_ops_count` - 寫入次數

**分析重點**：
- 是否有突發的高寫入（Bleve 索引建立、日誌爆增）
- 是否持續高寫入（資料庫問題、日誌未輪替）

### 3. CPU 使用率

**指標**：
- `compute.googleapis.com/instance/cpu/utilization` - CPU 使用率

### 4. 磁碟空間使用

**指標**（需要 Ops Agent）：
- `agent.googleapis.com/disk/percent_used` - 磁碟使用百分比

---

## 🔧 安裝 Ops Agent（強烈推薦）

**為什麼需要**：
- GCP 預設只監控 CPU、網路、磁碟 I/O
- 安裝 Ops Agent 後可監控：
  - ✅ 記憶體使用率
  - ✅ 磁碟空間使用
  - ✅ 進程資訊
  - ✅ 應用程式日誌

### 安裝步驟（在 GCP VM 上執行）

```bash
# 1. 下載並執行安裝腳本
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
sudo bash add-google-cloud-ops-agent-repo.sh --also-install

# 2. 驗證安裝
sudo systemctl status google-cloud-ops-agent

# 3. 查看配置
sudo cat /etc/google-cloud-ops-agent/config.yaml
```

**安裝後立即可用**：
- 記憶體監控
- 磁碟空間監控
- 系統日誌自動上傳

### Ops Agent 配置（可選）

如果需要監控 Mattermost 日誌，編輯配置：

```bash
sudo nano /etc/google-cloud-ops-agent/config.yaml
```

添加 Mattermost 日誌監控：

```yaml
logging:
  receivers:
    mattermost:
      type: files
      include_paths:
        - /srv/gopath/src/github.com/zacmm/zacmm2025/server/logs/mattermost.log
      record_log_file_path: true
  service:
    pipelines:
      default_pipeline:
        receivers: [syslog, mattermost]

metrics:
  receivers:
    hostmetrics:
      type: hostmetrics
      collection_interval: 60s
  service:
    pipelines:
      default_pipeline:
        receivers: [hostmetrics]
```

重新啟動 agent：

```bash
sudo systemctl restart google-cloud-ops-agent
```

---

## 🔔 設定告警（自動通知）

### 建立記憶體使用率告警

1. 前往 **Cloud Monitoring** > **告警**
2. 點擊 **「建立政策」**

**設定條件**：
- **資源類型**：VM Instance
- **指標**：`agent.googleapis.com/memory/percent_used`
- **條件**：大於 **85%**
- **持續時間**：5 分鐘（避免誤報）

**設定通知**：
- 建立通知管道（Email、Slack、PagerDuty）
- 選擇通知對象

**範例告警政策**：

```
名稱: Mattermost VM - 記憶體使用過高
條件: 記憶體使用率 > 85% 持續 5 分鐘
通知: your-email@example.com
```

### 建立磁碟空間告警

**條件**：
- **指標**：`agent.googleapis.com/disk/percent_used`
- **條件**：大於 **80%**

### 建立磁碟寫入速率告警

**條件**：
- **指標**：`compute.googleapis.com/instance/disk/write_bytes_count`
- **條件**：速率（rate）大於 **50 MB/s** 持續 10 分鐘

---

## 📊 建立自訂儀表板

### 推薦的 Mattermost 監控儀表板

1. 前往 **Cloud Monitoring** > **儀表板**
2. 點擊 **「建立儀表板」**
3. 添加以下圖表：

#### 圖表 1：記憶體使用率（折線圖）
- **指標**：`agent.googleapis.com/memory/percent_used`
- **資源**：你的 VM
- **時間範圍**：1 天

#### 圖表 2：磁碟寫入速率（折線圖）
- **指標**：`compute.googleapis.com/instance/disk/write_bytes_count`
- **聚合**：速率（rate）
- **單位**：MB/s

#### 圖表 3：CPU 使用率（折線圖）
- **指標**：`compute.googleapis.com/instance/cpu/utilization`

#### 圖表 4：磁碟空間使用（儀表板）
- **指標**：`agent.googleapis.com/disk/percent_used`
- **顯示類型**：Gauge（儀表）

#### 圖表 5：網路流量（堆疊面積圖）
- **指標**：
  - `compute.googleapis.com/instance/network/received_bytes_count`
  - `compute.googleapis.com/instance/network/sent_bytes_count`

**儲存儀表板**，命名為「Mattermost 生產監控」

---

## 🔍 診斷問題的方法

### 當系統卡住時

1. **查看即時監控**：
   - GCP Console > Compute Engine > VM > 監控
   - 查看當下的 CPU、記憶體、磁碟 I/O

2. **回溯歷史資料**：
   - Cloud Monitoring > 指標瀏覽器
   - 選擇時間範圍：問題發生前後 2 小時
   - 查看記憶體、磁碟寫入的變化

3. **找出異常點**：
   - 記憶體是否突然暴增？（大量請求、檔案上傳）
   - 記憶體是否持續增長？（記憶體洩漏）
   - 磁碟寫入是否突增？（日誌爆增、Bleve 索引）

### 分析範例

**案例 1：記憶體持續增長**
```
08:00 - 記憶體 60%
12:00 - 記憶體 75%
16:00 - 記憶體 90%
18:30 - 記憶體 98% → 系統卡住
```
**診斷**：記憶體洩漏，Mattermost 進程未釋放記憶體

**案例 2：磁碟寫入突增**
```
平時：5 MB/s
14:00：突然升至 200 MB/s
持續 30 分鐘 → 系統卡住
```
**診斷**：可能是 Bleve 索引建立或日誌爆增

---

## 📝 查看日誌（Cloud Logging）

GCP 也提供強大的日誌查詢功能。

### 查看系統日誌

1. 前往 **Cloud Logging** > **日誌瀏覽器**
2. 選擇資源：`VM Instance` > 你的 VM

**查詢範例**：

#### 查詢 Mattermost 錯誤
```
resource.type="gce_instance"
logName="projects/YOUR_PROJECT/logs/syslog"
"mattermost"
severity>=ERROR
```

#### 查詢 OOM Killer 事件
```
resource.type="gce_instance"
"Out of memory"
OR "oom-killer"
OR "Killed process"
```

#### 查詢磁碟空間不足
```
resource.type="gce_instance"
"No space left on device"
OR "disk full"
```

### 匯出日誌到 BigQuery（可選）

可以將日誌匯出到 BigQuery 進行長期分析和複雜查詢。

---

## 🆚 GCP 監控 vs 自訂腳本對比

| 功能 | GCP Cloud Monitoring | 自訂腳本 |
|------|---------------------|---------|
| **視覺化** | ✅ 精美圖表、儀表板 | ❌ 僅文字輸出 |
| **歷史資料** | ✅ 自動保存 6 週 | ❌ 需手動保存 |
| **告警** | ✅ 自動 Email/Slack | ❌ 需自行實作 |
| **即時性** | ✅ 1 分鐘更新 | ⚠️ 依執行頻率 |
| **進程級監控** | ❌ 僅 VM 級別 | ✅ 可看個別進程 |
| **診斷詳細度** | ⚠️ 較概括 | ✅ 非常詳細 |
| **成本** | ⚠️ 超過免費額度收費 | ✅ 完全免費 |

**建議組合使用**：
- **日常監控**：使用 GCP Cloud Monitoring（視覺化、告警）
- **問題診斷**：當告警觸發時，SSH 進入 VM 執行自訂腳本獲取詳細資訊

---

## 💰 成本考量

### Cloud Monitoring 免費額度（每月）

- **指標攝取**：前 150 MB 免費
- **指標儲存**：免費
- **API 呼叫**：前 100 萬次免費
- **日誌**：前 50 GB 免費

**一般 Mattermost VM 的用量**：
- 通常在免費額度內
- 如果超過，費用也很低（每月 < $10）

### 節省成本技巧

1. **調整取樣頻率**：
   - 預設 60 秒取樣一次
   - 可調整為 120 秒（降低指標數量）

2. **只監控關鍵指標**：
   - 記憶體、磁碟 I/O、CPU
   - 不需要的指標可以關閉

---

## ✅ 推薦設定步驟（今天就做）

### 第 1 步：安裝 Ops Agent（10 分鐘）

```bash
# SSH 連線到 GCP VM
gcloud compute ssh YOUR_VM_NAME

# 安裝 Ops Agent
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
sudo bash add-google-cloud-ops-agent-repo.sh --also-install

# 驗證
sudo systemctl status google-cloud-ops-agent
```

### 第 2 步：建立儀表板（15 分鐘）

1. 前往 Cloud Monitoring
2. 建立儀表板包含：
   - 記憶體使用率
   - 磁碟寫入速率
   - CPU 使用率
   - 磁碟空間使用

### 第 3 步：設定告警（10 分鐘）

建立以下告警：
1. 記憶體 > 85% 持續 5 分鐘
2. 磁碟空間 > 80%
3. 磁碟寫入速率異常高

### 第 4 步：觀察 24-48 小時

- 查看儀表板瞭解正常基準線
- 等待告警（如果觸發）
- 分析趨勢找出問題

---

## 🚨 緊急處理流程（使用 GCP 監控）

當收到告警時：

```bash
# 1. 登入 GCP Console 查看儀表板
# 確認是哪個指標異常（記憶體/磁碟）

# 2. SSH 連線到 VM
gcloud compute ssh YOUR_VM_NAME

# 3. 執行詳細診斷腳本
./monitor_system.sh

# 4. 如果記憶體過高，清理 cache
sudo sync
echo 1 | sudo tee /proc/sys/vm/drop_caches

# 5. 如果仍然卡住，重啟服務
sudo systemctl restart mattermost

# 6. 回到 GCP 儀表板確認恢復
```

---

## 📚 相關文檔

- [Cloud Monitoring 文檔](https://cloud.google.com/monitoring/docs)
- [Ops Agent 安裝指南](https://cloud.google.com/stackdriver/docs/solutions/agents/ops-agent)
- [告警政策設定](https://cloud.google.com/monitoring/alerts)
- [指標清單](https://cloud.google.com/monitoring/api/metrics_gcp)

---

## 🎯 總結

**立即行動**：
1. ✅ 安裝 Ops Agent（獲取記憶體監控）
2. ✅ 建立監控儀表板（視覺化）
3. ✅ 設定告警（自動通知）
4. ✅ 觀察 24-48 小時（建立基準線）

**長期使用**：
- 日常：查看 GCP 儀表板
- 告警：收到通知後 SSH 進入執行診斷腳本
- 優化：根據監控資料調整系統配置

GCP Cloud Monitoring + 自訂診斷腳本 = 完美組合！ 🎉
