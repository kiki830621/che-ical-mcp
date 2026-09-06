## Why

Issue #194：讀取提醒沒有重複規則，且完成操作回傳 store 物件的狀態，讓下一筆未完成提醒看起來像本次操作失敗。

## What Changes

- list/search 增加 has_recurrence、完整公開 recurrence_rules 與保留精度的 due。
- completion 以不可變快照區分操作結果與下一筆觀測，保留舊欄位。
- 同 ID 的原地推進可在身分與日期條件成立時回報 confirmed；未確認狀態為 unknown，不以查詢失敗重試寫入。
- （已拆出）重複提醒 undo/redo 的 occurrence 身分驗證，以及非布林 `completed` 的拒絕，各自另開 PR；本變更不含。

## Capabilities

### New Capabilities

- reminder-recurrence-results: 重複提醒讀取與完成結果。

### Modified Capabilities

無。

## Impact

Server.swift、EventKitManager.swift、新增 ReminderRecurrence.swift、ReminderCompletion.swift、測試與雙語 README。

## Non-Goals

不變更 event 回傳、不新增 recurrence 寫入欄位、不用標題推斷系列、不預測或建立下一筆、不承諾跨裝置同步或 exactly-once。不使用未驗證的 external ID 關聯；不同 ID 的後繼項目暫以 unknown 明示。CLI 缺少 Spectra；本變更手動保留規格，macOS 編譯/測試由既有 CI 執行。
