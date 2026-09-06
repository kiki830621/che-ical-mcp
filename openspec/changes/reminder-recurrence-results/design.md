## Decisions

1. 新 reminder recurrence serializer 完整擷取公開規則；event formatter 不改動。星期整數陣列加 days_of_week_details，保留 week_number。
2. due 採 date/time/timezone/date_time，純日期及浮動時間不製造絕對時刻；保留既有 due_date 輸出。
3. completion 的 operation.type 為 complete/reopen，status=succeeded 只表示 save 已成功。target 是修改前快照；legacy action/is_completed 不重定義。
4. 儲存前後都在 actor 內擷取值，觀測只對已知同 ID、相同 calendar、recurrence 與到期進展建立關聯。任何身分疑義回傳 unknown。無可靠系列結束證據，不輸出 none。
5. 新 ReminderCompletionSource 僅有完成方法，handler 以 fake 驗證 JSON。不得擴大 cleanup 的 EventKitManaging。
6. 儲存後在同一個 actor 執行期內、任何 suspension 之前，同步讀取同一物件一次；EventKit 於 save 時就地推進重複提醒，所以這一次讀取已反映後繼。不輪詢、不等待雲端刷新、不呼叫 reset —— 之後的讀取只可能看到其他寫入者的變動，會把並行編輯誤認為本次後繼（verify 報告 rows 2/10）。後續未知不改成寫入失敗。
7. （已拆出）recurring undo/redo 的 occurrence 身分 guard 另開 PR；本變更的 completion 一律記錄既有 `.completeReminder`。

## Validation

規則/日期與純決策單元測試、completion handler/dispatch 測試；既有 macOS CI 執行 swift build + swift test。Linux 本機只能檢查 diff/JSON。實際帳號的 rollover 另列為尚待實機驗證，不把 CI fake 當成實測。
