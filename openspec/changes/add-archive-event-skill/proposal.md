## Why

把「開會通知信 → 行事曆事件」這件事，目前每次都要人重走同一組判斷，而 29 個 EventKit 工具沒有一個會提醒這些判斷存在。其中兩項的失敗是**安靜的**——事件建立成功、行事曆看起來完全正常，錯的是內容：

1. **取到被更正前的時間**。通知發出後改期，若只讀第一封通知就登錄，日期是錯的。
2. **推估值被當成通知載明的事實**。通知常不寫結束時間，推估出來的值若不標注，未來讀的人無從分辨哪些是原文、哪些是猜的。

會報錯的問題寫進文件就夠了（人會去查）；安靜失敗必須在流程裡主動攔，因為人不知道要查。這是需要 skill 而非 README 段落的核心理由。

## What Changes

- 新增 `archive-event` skill，把來源推導與佐證固化為五個步驟：thread-aware 取最後更正、來源識別的 update-vs-create、推估欄位標注、來源引用、鄰近期限提示。
- **更正判準改用身分與內容，不用時間序**：從 thread 末尾往前回溯，取第一封同時滿足「寄件人與原始通知相同」且「本文含可解析的日期時間」的信。兩條件皆不滿足時列候選讓人挑，不猜。
- **改期時走 update 而非 create**：事件 notes 帶來源識別，歸檔前先搜同來源的既有事件。這補的是既有 idempotency 的缺口——它以標題與開始時間為 key，改期後開始時間變了就會判成新事件，於是留下兩個。
- **推估欄位強制標注**：notes 以固定格式寫出推估值、依據與「通知未載明」；無推估則整行省略。
- 調整 `quick-event` 的 description 以標示邊界：該命令處理「已知時間地點，建一個」，本 skill 處理「從來源推導並留下佐證」。

## Capabilities

### New Capabilities

- `event-source-archiving`: 從敘事來源（開會通知、公告、訊息串）推導行事曆事件，並在事件上留下可回溯的來源與推估佐證。

### Modified Capabilities

(none)

## Impact

- Affected specs: event-source-archiving（新增）
- Affected code:
  - New: plugin/skills/archive-event/SKILL.md
  - Modified: plugin/commands/quick-event.md
  - Removed: (none)

不動 Swift 端——本 skill 只編排既有 MCP 工具，不需要新 tool。`plugin.json` 亦不需改，該檔不宣告 skills 或 commands，兩者皆為慣例自動發現。
