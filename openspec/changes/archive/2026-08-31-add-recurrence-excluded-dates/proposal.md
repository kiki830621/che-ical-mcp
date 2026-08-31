# Proposal: add-recurrence-excluded-dates

## Why

`create_event` 與 `create_events_batch` 可以定義 recurrence rule，但無法在同一操作內排除已知場次。Client 目前必須：建立 series → 取得 event ID → 逐日呼叫 `delete_event`（`span: "this"`）。這增加 N+1 次 round trip，且任一排除失敗會留下半配置的 series（GitHub issue #182）。

EventKit 的 `EKRecurrenceRule` 不暴露 EXDATE，因此本功能以「create → resolve → remove」組合實現，並以補償刪除逼近 all-or-nothing 契約。

## What Changes

在 `create_event` 與 `create_events_batch` item 的 `recurrence` 物件內新增選填欄位 `excluded_occurrence_dates`（字串陣列，沿用既有 `occurrence_date` date grammar）：

1. **解析與 caller gating**：`parseRecurrenceRule` 解析新欄位並加 `allowsExclusions` 參數 — `update_event` / `create_reminder` 傳入該欄位時擲明確錯誤（共用 parser 的另外兩個 caller 不支援此欄位）。
2. **Pre-save 驗證**（零變異）：非陣列/非字串元素（索引式錯誤）、normalize 後重複拒絕、日期須落在 rule 窗口粗界（end_date / occurrence_count）、數量上限 100。
3. **Post-save two-pass 執行**（`EventKitManager.createEvent` 內）：save master 後**先 resolve 全部** excluded dates 為 occurrence（任一無法對應 → 補償刪除整個 series，此時零 occurrence 被移除）→ **再統一 remove**（`.thisEvent`）；移除中途失敗 → 補償刪除＋回報殘留狀態。
4. **Undo 語意**：`.createEvent` undo 記錄點從 save 後移到 exclusion pass 成功後；補償刪除路徑不記 entry（stack 無殘留假 entry）。
5. **Idempotency / conflict**：duplicate path（±30s＋title 啟發式）命中且請求含 exclusions 時，逐一檢查 requested dates 在既有 series 是否已缺場 — 全缺 → `skipped`（idempotent retry）；任一仍在 → conflict 錯誤。
6. **回應欄位**：`excluded_occurrence_dates`（normalized `yyyy-MM-dd`，事件時區）＋ `exclusion_count`；batch per-item 同構 deterministic。
7. **Schema 同步**：`create_event` 與 batch item 兩份 `recurrence` schema copy 同步新欄位。

## Non-Goals

- **不偵測既有 series「多出的」exclusion**（D5 limitation）：完整集合比對需重建 EventKit 的 recurrence 展開邏輯，drift 風險大於漏測價值；文件化為已知限制。
- **不支援 `update_event` 增修 exclusion**：本 change 僅覆蓋建立時排除；事後排除沿用既有 `delete_event span:"this"`。
- **不引入 `UndoOperation.batch` 組合**：undo「建立含排除的 series」＝刪除整個 series，既有 `.createEvent` entry 已足（僅移動記錄點）。
- **不提供真交易性**：EventKit 無交易 API；all-or-nothing 以補償刪除逼近，rollback 自身失敗時明確回報殘留（master event ID＋已套用清單），不靜默。

## Capabilities

### New Capabilities

- `recurrence-excluded-dates`: 建立週期事件時以單一 MCP 操作排除指定場次 — 欄位驗證、two-pass 執行、補償刪除、undo 一致性、idempotent retry / conflict 判定、回應欄位契約。

### Modified Capabilities

(none — `event-attendees` spec 涉及同一 create_event surface 但無行為交集，僅需 consistency check)

## Impact

- Affected specs: 新增 `specs/recurrence-excluded-dates/spec.md`；`event-attendees` 無 normative 變更
- Affected code:
  - `Sources/CheICalMCP/Server.swift`（兩份 recurrence schema、`parseRecurrenceRule`、`handleCreateEvent`、`handleCreateEventsBatch`）
  - `Sources/CheICalMCP/EventKit/EventKitManager.swift`（`RecurrenceRuleInput`、`createEvent` 的 exclusion 執行＋補償路徑、duplicate path 檢查）
  - `Tests/CheICalMCPTests/`（validation unit tests＋handler tests＋新 narrow `*Source` seam）
  - 文件：`README.md`、`README_zh-TW.md`、`plugin/skills/calendar-management/SKILL.md`、`CHANGELOG.md`
