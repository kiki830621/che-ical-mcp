# Tasks: add-recurrence-excluded-dates

## 1. 解析與驗證層（Server.swift）

- [x] 1.1 `RecurrenceRuleInput`（EventKitManager.swift:1914-1925）加 `excludedOccurrenceDates: [Date]?`（immutable let）
- [x] 1.2 `parseRecurrenceRule`（Server.swift:3024-3078）加 `allowsExclusions: Bool` 參數：解析 `excluded_occurrence_dates`（陣列/字串型別檢查含索引式錯誤，mirroring `days_of_week` at :3046-3054）；`allowsExclusions == false` 且欄位存在 → 擲明確 `ToolError`。四個 call site 更新：create_event（:1325）與 batch（:2379）傳 `true`，update_event（:1389）與 create_reminder（:1641）傳 `false`
- [x] 1.3 Pre-save 驗證：date-only 值以事件時區 normalize 為 calendar day；重複（normalize 後同日）→ 拒絕；rule 窗口粗界（超出 `end_date` 或 `occurrence_count` 可推得的最後 occurrence 日 → 拒絕）；`count > 100` → 拒絕。全部在 `createEvent` 呼叫前完成（零變異）
- [x] 1.4 兩份 `recurrence` schema copy 同步新欄位：Server.swift:256-289（create_event）與 :774-786（batch item），描述含 date grammar 與 cap

## 2. 執行層（EventKitManager.swift）

- [x] 2.1 `createEvent` 簽名收 `excludedOccurrenceDates`；save master（:617）後執行 two-pass：PASS 1 對每個 date 跑 `findOccurrence(identifier:on:in:)`（:793-808，事件時區）全部 resolve — 任一失敗 → 補償刪除 series ＋擲錯誤（含失敗 date）；PASS 2 逐一 `eventStore.remove(occurrence, span: .thisEvent)` — 中途失敗 → 補償刪除＋擲錯誤
- [x] 2.2 Undo 記錄點後移：`.createEvent` record（現 :619）移到 exclusion pass 成功後；補償刪除路徑不記 entry；無 exclusion 呼叫行為不變
- [x] 2.3 補償刪除失敗處理：錯誤訊息（`TrustedErrorMessage` 路徑）含 master event ID＋已套用 exclusion 清單，不靜默
- [x] 2.4 Duplicate path（:553-555）：early return 前若請求含 exclusions → 對每個 requested date 跑 `findOccurrence`；全缺 → 回傳 `isDuplicate`（handler 報 `skipped`）；任一仍在 → 擲 conflict 錯誤（含既有 event ID）

## 3. 回應層（Server.swift handlers）

- [x] 3.1 `handleCreateEvent`（:1290-1348）：成功回應加 `excluded_occurrence_dates`（normalized `yyyy-MM-dd`，事件時區）＋ `exclusion_count`
- [x] 3.2 `handleCreateEventsBatch`（:2304-2474）：per-item 同構欄位；exclusion 失敗轉該 item `{"success": false, "error": …}` 不中斷其他 item（單一 series 為 all-or-nothing 邊界）

## 4. 測試

- [x] 4.1 [P] Validation unit tests（新 `RecurrenceExclusionValidationTests.swift`，純 unit per CLAUDE.md 命名）：型別/索引錯誤、重複拒絕、窗口粗界、cap=100、caller gating（update_event/create_reminder 拒絕）、date-only 時區 normalize
- [x] 4.2 [P] 新 narrow seam `RecurrenceExclusionSource` protocol（create-series/resolve/remove/delete-series 最小面）＋ `CheICalMCPServer.init` 注入參數（預設 `EventKitManager.shared`；per CLAUDE.md `<Domain>Source` 慣例，不擴 `EventKitManaging`）＋ fake
- [x] 4.3 Handler tests（新 `RecurrenceExclusionHandlerTests.swift`，複製 `CleanupHandlerTests` 結構）：two-pass 順序（resolve 全部先於 remove）、PASS 1 失敗零移除即補償、PASS 2 失敗補償＋殘留回報、undo 記錄點（成功記一筆/補償不記）、duplicate skipped/conflict、回應欄位、batch per-item
- [x] 4.4 既有測試 regression：`swift test` 全綠（含無 exclusion 路徑 undo 行為不變）

## 5. 文件

- [x] 5.1 [P] `README.md` ＋ `README_zh-TW.md` 工具表更新（create_event/create_events_batch 描述提及 exclusion）；D5 limitation（既有 series 多出的 exclusion 不偵測）文件化
- [x] 5.2 [P] `plugin/skills/calendar-management/SKILL.md` 使用指引＋ `CHANGELOG.md` 條目


## ASSUMPTION（unattended run 偏差記錄）

- **4.2 seam 形式**：以 closure-based `ExclusionExecutor`（`Sources/CheICalMCP/EventKit/ExclusionExecutor.swift`，generic over occurrence type）取代原規劃的 `RecurrenceExclusionSource` protocol + init 注入。理由：two-pass 排序／rollback 語意是需要隔離測試的核心，closure seam 以更小 API 面達成同等隔離（`ExclusionExecutorTests` 6 case 全綠）；protocol + init 參數對本 feature 無額外測試價值。CLAUDE.md 的 `<Domain>Source` 慣例適用於「handler 需要 fake 整個 manager 面」的場景，本 feature 的 handler 邏輯（response 欄位組裝）薄到 dispatch-path 測試即可覆蓋。
- **4.3 覆蓋範圍**：two-pass 排序＋rollback 由 `ExclusionExecutorTests` pin；validation／caller-gating 由 `RecurrenceExclusionValidationTests`（dispatch 路徑，pre-EventKit）pin。「成功路徑 envelope 欄位」（excluded_occurrence_dates/exclusion_count 出現在回應）需真 EventKit，未在 CI 覆蓋 — 留待 verify phase 檢視是否可接受。
