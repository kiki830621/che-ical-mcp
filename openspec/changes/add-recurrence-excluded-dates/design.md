# Design: add-recurrence-excluded-dates

## Context

EventKit 的 `EKRecurrenceRule` 建構式（`EventKitManager.swift` `createRecurrenceRule(from:)`）不暴露 EXDATE；排除場次唯一路徑是對已儲存的 series 逐 occurrence `remove(.thisEvent)`。occurrence 解析已有 #7 建立的 `findOccurrence(identifier:on:in:)`：以事件時區 `startOfDay` ±1 day 的 predicate 枚舉、比對 `eventIdentifier`。`frequency` enum 僅 daily/weekly/monthly/yearly（無 sub-daily），故 rule 生成的 occurrence 每日最多一個，day-granular 解析語意安全（D3）。

`parseRecurrenceRule` 由四個 caller 共用（create_event / create_events_batch / update_event / create_reminder）；後兩者不支援 exclusion。

## Goals / Non-Goals

**Goals**：單一 MCP 操作建立「含排除場次」的週期事件；失敗不留半配置 series（以補償刪除逼近）；undo stack 一致；idempotent retry。

**Non-Goals**：見 proposal（不偵測既有 series 多出的 exclusion、不支援 update_event 排除、不引入 batch undo、不宣稱真交易性）。

## Decisions

### D1 — 實作點：`EventKitManager.createEvent`

兩個 handler 已 funnel 到同一 `createEvent`；EventKit 枚舉與 undo 記錄都在 manager 層。`RecurrenceRuleInput` 加 `excludedOccurrenceDates: [Date]?`（immutable let，維持 value-type 慣例）。

**替代方案（否決）**：server-level post-create helper — 需要兩個 handler 各自組裝 create→exclude→rollback 序列，血緣重複且 undo 時序難以保證。

### D2 — 兩段式驗證＋two-pass 執行

```
pre-save（Server 層，零變異）        post-save（Manager 層）
┌────────────────────────┐          ┌─────────────────────────────┐
│ 型別/索引式錯誤          │          │ save master                 │
│ normalize 後去重拒絕     │   ──▶    │ PASS 1: resolve 全部 dates  │──任一失敗──▶ 補償刪除（零 occurrence 已動）
│ rule 窗口粗界檢查        │          │ PASS 2: 統一 remove          │──中途失敗──▶ 補償刪除＋回報殘留
│ 數量 cap = 100          │          │ 記錄 undo（見 D4）           │
└────────────────────────┘          └─────────────────────────────┘
```

「每個日期必須對應 rule 生成的 occurrence」只能在 save 後以枚舉驗證（EventKit 限制）；two-pass 保證 resolve 失敗時狀態乾淨（尚未移除任何 occurrence）。

### D4 — Undo 記錄點後移

現行 `createEvent` 在 save 後立即 `record(.createEvent(...))`。改為 exclusion pass 全部成功後才記錄；補償刪除路徑不記任何 entry。undo「建立含排除的 series」＝刪整個 series，`.createEvent` 單一 entry 已達成 — 不需 `.batch`。無 exclusion 的呼叫行為不變（記錄點等價）。

### D5 — Idempotency：requested-dates 子集檢查

Duplicate path（`findDuplicateEvent` ±30s＋title）early return 前，若請求含 exclusions：對每個 requested date 跑 `findOccurrence` — 全部缺場 → `skipped`（回應標注既有 series）；任一仍在 → 擲 conflict 錯誤（`TrustedErrorMessage`，含既有 event ID）。已知限制：既有 series「多出的」exclusion 不偵測（文件化）。

### D6 — Caller gating

`parseRecurrenceRule(from:defaultTimezone:allowsExclusions:)` — `create_event` / batch 傳 `true`；`update_event` / `create_reminder` 傳 `false`，遇到欄位擲 `ToolError`（明確訊息，非靜默忽略；符合 Validation.swift #101 F2 紀律）。

### D7 — 回應契約

成功：`excluded_occurrence_dates`（normalized `yyyy-MM-dd`，事件時區）＋ `exclusion_count`。rollback 失敗：錯誤訊息含 master event ID＋已套用的 exclusion 清單（不靜默）。batch per-item 同構；exclusion 失敗（含補償結果）轉為該 item `{"success": false, "error": …}`，不中斷其他 item（維持 batch 既有 partial-failure 語意 — all-or-nothing 的邊界是**單一 series**，不是整個 batch）。

### 測試 seam

per CLAUDE.md：不擴 `EventKitManaging`；新 narrow protocol `RecurrenceExclusionSource`（create-series / resolve-occurrence / remove-occurrence / delete-series 的最小面）＋ `CheICalMCPServer.init` 注入參數（預設 `EventKitManager.shared`）。Handler tests 複製 `CleanupHandlerTests` 結構；validation tests 進 `InputValidationTests` 風格的純 unit 檔。

## Risks / Trade-offs

| 風險 | 處置 |
|---|---|
| 補償刪除自身失敗 → 半配置 series 殘留 | 錯誤回報殘留 master ID＋已套用清單；不靜默（Residue：真交易性不可得） |
| duplicate 啟發式（±30s＋title）誤判 | conflict 判定繼承其誤判率；錯誤訊息附既有 event ID 供人工核對 |
| N 次 predicate 枚舉的效能 | cap=100；resolve pass 可重用單一 day-window predicate per date（與 delete_event 現行成本同階） |
| undo 記錄點後移影響無 exclusion 路徑 | 無 exclusion 時記錄點語意等價（save 即成功）；以既有測試防 regression |

## Migration Plan

純新增選填欄位 — 無 schema migration、無版本破壞。舊 client 不傳欄位 → 行為 byte-equivalent。`mcpb/manifest.json` 僅 name+description，無需 schema 變更（ManifestParityTests 四項檢查不受影響）。

## Open Questions

(none — D1–D7 已在 spectra-discuss 收斂；unattended run 的假設已明文記錄於 proposal Non-Goals)
