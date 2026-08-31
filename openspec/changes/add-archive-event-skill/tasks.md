每個任務標註它滿足的 spec requirement 與 design 決定，供 apply 階段逐條對照。

## 1. 建立 skill 骨架

- [x] 1.1 建立 `plugin/skills/archive-event/SKILL.md`，frontmatter 含三個欄位：`name: archive-event`；`description` 寫明觸發情境（從開會通知、公告、訊息串歸檔事件進行事曆）並與 `quick-event`（已知時間地點直接建立）明確區隔；`allowed-tools` 列出 `list_calendars`、`list_events`、`search_events`、`create_event`、`update_event`、`check_conflicts`、`list_reminders`。形狀對照既有 `plugin/skills/calendar-management/SKILL.md`。（滿足 design.md → Implementation Contract → interface）
- [x] 1.2 在 SKILL.md 寫「既有覆蓋」一節，列出 `quick-event` 已做衝突檢查、`create_event` 已內建同曆 idempotency、`find_duplicate_events` 只跨曆比對，並說明本 skill 不重造這三者。目的是讓後續維護者不會把已有的東西再實作一次。（依據 design.md → Context 的既有覆蓋表）

## 2. 更正判準

滿足 spec requirement **Correction selection by sender identity and parsable time**；實作 design.md 的 **決定一：更正判準用「寄件人身分＋內容含時間」，不用時間序也不用關鍵字**。

- [x] 2.1 寫「更正判準」一節：從 thread 末尾往前回溯，取第一封同時滿足「寄件人與原始通知相同」與「本文含可解析日期時間」的信；明寫不用時間序、不用關鍵字清單，並各附一句理由。附四封信的 worked example（原通知 → 無具體時間的提議 → 主辦方更正 → 與會者回覆），逐步走出「取第三封」的推導並說明為何不是第四封。（對應 spec scenario：A later reply without a time does not override the organizer's correction）
- [x] 2.2 在同一節寫「兩條件皆不滿足」的處置：列出候選信件與其寄件人、時間，交由操作者選擇，不得自行推定。明寫觸發情境為「同一人改用其他位址寄信」。（對應 spec scenario：Neither condition is satisfiable, so the operator decides）

## 3. update vs create

滿足 spec requirement **Re-archiving a corrected source updates the existing event**；實作 design.md 的 **決定二：改期走 update 而非 create，靠 notes 內的來源識別**。

- [x] 3.1 寫「update vs create」一節：歸檔前以來源識別（Message-ID）搜尋既有事件，命中則 `update_event`、未命中才 `create_event`。附一段說明為何 `create_event` 內建的 (title, start ±30s, calendar) key 解不了改期——改期後 start 已變，會判成新事件而留下兩個。（對應 spec scenario：A rescheduled meeting updates rather than duplicates）
- [x] 3.2 在同一節寫「來源無穩定識別碼」的退路：退回既有 create-time 行為，並在回報中聲明該來源的後續更正無法追蹤。（對應 spec scenario：A source without an identifier is archived）

## 4. notes 格式：推估標注與來源引用

滿足 spec requirements **Estimated field values are labelled in the event notes** 與 **Archived events carry a source citation**；實作 design.md 的 **決定三：推估欄位強制標注，格式固定**。

- [x] 4.1 寫「notes 格式」一節，給出固定兩行格式（來源行、推估行），明寫推估行為強制而非可選、無推估時整行省略不留空行。附具體範例：通知寫「8/13（四）下午 3:30，行政大樓 2008 室」無結束時間、同行事曆前兩次同類活動為 2 小時 → 事件 15:30–17:30，notes 含 `推估：結束時間 17:30（沿用同行事曆前次同類活動時長；通知未載明）`。（對應 spec scenarios：An unstated end time is estimated and labelled；A fully specified source produces no estimate line）
- [x] 4.2 在同一節寫來源行的欄位組成（寄件人、日期、主旨），並說明其用途是讓事件的依據在脫離對話脈絡後仍可回溯。（對應 spec scenario：The source of an event is recoverable months later）

## 5. 行事曆選擇與同日期限

- [x] ~~5.1~~（**superseded by 8.2** — v1「不讀設定檔」的內容已由決定五推翻，本項的 deliverable 被 8.2 改寫）寫「行事曆選擇」一節：查該類活動前次登錄在哪本行事曆並據此推導，查不到就問使用者。明寫 v1 不讀任何專案設定檔，並附一句說明為何（設定檔藏的行為約等於零）。（實作 design.md 的 **決定四：v1 的 default calendar 用推導，不用設定檔**）
- [x] 5.2 寫「同日期限提示」一節：事件建立或更新後，查當日的行事曆事件與提醒事項並在回報中列出。明寫涵蓋範圍僅此兩者，不宣稱涵蓋信件或 issue 追蹤系統中的期限。（滿足 spec requirement **Same-day deadlines are surfaced after archiving**）

## 6. 標示與 quick-event 的邊界

- [x] 6.1 [P] 修改 `plugin/commands/quick-event.md` 的 `description` 一行，明確其適用情境為「已知時間地點，直接建立」，使其與 archive-event 的「從來源推導並留下佐證」並排閱讀時無需額外說明即可分辨。不改該檔的執行流程與其餘內容。（滿足 design.md → Implementation Contract → verification 第三項）

## 7. 驗收

- [x] 7.1 對照 `openspec/changes/add-archive-event-skill/specs/event-source-archiving/spec.md` 的五個 requirement 逐條檢查 SKILL.md：Correction selection by sender identity and parsable time、Re-archiving a corrected source updates the existing event、Estimated field values are labelled in the event notes、Archived events carry a source citation、Same-day deadlines are surfaced after archiving。每個 requirement 的每個 scenario 都要能在文件中找到對應的操作指示；逐條記錄對應位置，缺漏者補寫。（滿足 design.md → Implementation Contract → behavior 五項的驗證）
- [x] 7.2 並排閱讀 `plugin/skills/archive-event/SKILL.md`、`plugin/skills/calendar-management/SKILL.md`、`plugin/commands/quick-event.md` 三者的 description，確認三個觸發情境互不重疊，且一個沒有本次脈絡的讀者能據此選對工具。
- [x] 7.3 確認未改動 `Sources/` 下任何檔案、未改動 `plugin/.claude-plugin/plugin.json`、未新增 `.claude/.ical/` 相關檔案（三者皆為 design.md → Implementation Contract → scope 明列的 out of scope）。以 `git status` 檢查實際變更檔案清單。

## 8. 專案層設定檔（2026-08-31 使用者裁決 — design 決定五）

滿足 spec requirement **Project-level configuration and archive state**。

- [x] 8.1 SKILL.md 新「Configuration and state」節：config.yaml 契約（v1 唯一欄位 `default_calendar`、附註解範例）、state/archives.json schema、兩檔缺省行為、壞損＝警告＋視為缺席
- [x] 8.2 SKILL.md「Which calendar」節改為三層 fallback：config.yaml → 推導（同類前次）→ 問使用者
- [x] 8.3 SKILL.md「Update or create」節改為 state 主索引 → notes 搜尋 fallback；成功歸檔後寫回 state
- [x] 8.4 驗收：spec 新 requirement 四個 scenario 均能在 SKILL.md 找到對應操作指示
