## Context

此 repo 已有 29 個 EventKit MCP 工具、兩個 agent-facing skill（`calendar-management` 工具使用指南、`troubleshoot-tcc` 權限排錯），以及一個 `quick-event` 命令。缺的不是工具，是「從敘事來源推導事件」時該做哪些判斷的固化。

三次實際操作（2026-08-07 一個工作階段內）暴露出七個必經判斷，其中五個沒有任何既有覆蓋。兩個判斷的失敗是安靜的：取到被更正前的時間、推估值未標注來源。安靜失敗無法靠文件防範，因為讀文件的前提是知道要查。

既有覆蓋須先釐清，避免重造：

| 既有機制 | 涵蓋什麼 | 不涵蓋什麼 |
|---|---|---|
| `quick-event` 命令 | parse → 列行事曆 → 衝突檢查 → 建立 | 來源推導、更正追蹤、佐證留存 |
| `create_event` 內建 idempotency | 同一行事曆內「標題＋開始時間 ±30 秒」重複 | 改期後開始時間已變的同一活動 |
| `find_duplicate_events` 工具 | 跨行事曆的重複比對 | 同一行事曆內（實作明確跳過同曆配對）|
| `calendar-management` skill | 工具分類與常見流程 | 從來源推導的判斷紀律 |

## Goals / Non-Goals

**Goals:**

- 讓「來源 → 事件」的五個判斷成為流程的一部分，而非依賴操作者記得。
- 兩個安靜失敗獲得主動攔截：更正追蹤靠身分與內容判準，推估值靠強制標注。
- 事件本身帶有可回溯的佐證——三個月後打開該事件，能知道它憑什麼是這個時間。
- 只編排既有 MCP 工具，不新增 Swift 端 tool。

**Non-Goals:**

- **不做跨系統的 deadline 聚合**。「鄰近期限提示」只覆蓋行事曆與提醒事項兩個來源；其他來源（信件、issue 追蹤系統）的期限不在射程內。
- **不判斷某活動值不值得進行事曆**。那是人的取捨，本 skill 只在使用者已決定要歸檔之後接手。
- **不改 Swift 端**。既有 29 個工具足夠；`create_event` 的 idempotency key 不動，改期問題在 skill 層用來源識別解決。

## Decisions

### 決定五：專案層設定檔 v1 即納入 — YAML 設定＋JSON 狀態雙軌（2026-08-31 使用者裁決）

初版 design 曾依 interface depth check 將 `.claude/.ical/` 排除於 v1（論證：`default_calendar` 藏的行為約等於零、刪掉只是「每次問一次」、五項新能力無一依賴）。使用者於 2026-08-31 attended session **裁決推翻**：v1 即納入。格式依姊妹 plugin `.claude/.mail/` 成形慣例雙軌：

- **`.claude/.ical/config.yaml`** — 人讀人寫，註解記設定理由。v1 唯一欄位：`default_calendar`（選填字串）。
- **`.claude/.ical/state/archives.json`** — 機器查。來源識別 → 歸檔事件映射（`{"<message-id>": {"event_id", "calendar", "archived_at"}}`），作為 update-vs-create 的**主索引**；事件 notes 內的來源識別保留，降為 fallback 與人讀佐證（notes 可能被使用者事後編修，state 檔不會）。

**載入契約（缺省安全）**：兩檔皆選填。config 缺席或無 `default_calendar` → 行事曆選擇 fallback 至推導（決定四從唯一機制降級為第二層）；state 缺席 → 索引視為未命中、走 notes 搜尋，成功歸檔後建檔寫入。任一檔壞損（YAML/JSON parse 失敗）→ 回報中明確警告並視為缺席，**不靜默吞**。

depth-check 原始論證保留於上供未來重審：若 config 長期只有一欄且推導命中率高，v2 可再評估收回。


### 決定一：更正判準用「寄件人身分＋內容含時間」，不用時間序也不用關鍵字

從 thread 末尾往前回溯，取第一封同時滿足下列兩條件的信：

- (a) 寄件人與原始通知的寄件人相同
- (b) 本文含可解析的日期時間

**為何不用時間序**：thread 最後一封常是與會者的確認回覆，而非主辦方的改期通知。實際案例中，若取最後一封會取到回覆，時間就錯了——而且錯得安靜。

**為何不用「更正／改期」關鍵字**：主辦方未必使用這些詞。實際案例的更正信寫的是「更正資訊如下」，但同樣可能寫成「因故調整」「新的時間是」。關鍵字清單永遠補不完，每漏一種寫法就是一次安靜失敗。

**為何 (b) 是關鍵**：沒有時間的信在定義上不可能是改期通知。這一條把「我也覺得延後好」這類無具體時間的提議排除，而它們正是純時間序判準會誤取的東西。

**兩條件皆不滿足時不猜**：列出候選讓使用者挑。同一人用不同位址寄信（機構信箱與個人信箱）是真實情形，(a) 會漏判；此時交還給人，比猜錯好。

### 決定二：改期走 update 而非 create，靠 notes 內的來源識別

`create_event` 的 idempotency key 是「標題＋開始時間 ±30 秒＋同一行事曆」。改期後開始時間已變，於是判為新事件——建了第二個，錯的那個留著。

解法是在事件 notes 寫入來源識別（信件的 Message-ID）。歸檔前先搜尋同來源的既有事件：命中則 `update_event`，未命中才 `create_event`。

**為何不在 skill 層自訂「標題＋時段」判準**：那是把 server 端已有的 key 換個地方重寫一次，同樣解不了改期（改期時兩個欄位都可能變）。來源識別是唯一在改期前後保持不變的東西。

**為何不改 Swift 端的 idempotency key**：那會影響所有 `create_event` 呼叫者，包括不帶來源資訊的一般用法。skill 層解決的影響面剛好等於需要它的範圍。

### 決定三：推估欄位強制標注，格式固定

notes 採固定格式；沒有推估時整行省略，不製造雜訊：

```
來源：<寄件人> <日期>「<主旨>」
推估：結束時間 17:30（沿用同行事曆前次同類活動時長；通知未載明）
```

**為何強制而非可選**：忘記標注的時候，正是最需要它的時候。做成可選等於沒做——這條是防止「把推測偽裝成事實」的唯一防線。

**為何寫進 notes 而非只在對話中說明**：對話會消失，事件會留下。三個月後讀事件的人（可能是使用者自己）沒有當時的對話脈絡。

### 決定四（部分由決定五取代：推導自唯一機制降為第二層 fallback，2026-08-31）：v1 的 default calendar 用推導，不用設定檔

查詢該類活動前次登錄在哪本行事曆，據此推導；查不到就問使用者。

**為何不用設定檔**：見 Non-Goals 第一項。推導的準確度在同類活動重複出現時等同設定檔，而在首次出現時本來就需要問——設定檔並不能免除首次的詢問，只是把它提前。

## Implementation Contract

### Behavior

歸檔一份來源後，使用者能觀察到：

1. 建立或更新的事件時間，來自 thread 中依決定一判準選出的那封信，而非第一封。
2. 事件 notes 含來源行，格式為 `來源：<寄件人> <日期>「<主旨>」`。
3. 若任何欄位為推估，notes 含推估行，載明推估值、依據與「通知未載明」。無推估則無此行。
4. 對已歸檔過的來源再次歸檔時，更新既有事件而非新增第二個。
5. 事件建立後，若同日在行事曆或提醒事項中存在其他期限，於回報中列出。

### Interface

`plugin/skills/archive-event/SKILL.md`，單一檔案，frontmatter 含 `name`、`description`、`allowed-tools`，形狀沿用既有 `calendar-management` 與 `troubleshoot-tcc`。

`allowed-tools` 至少涵蓋：`list_calendars`、`list_events`、`search_events`、`create_event`、`update_event`、`check_conflicts`、`list_reminders`。

不新增 MCP tool，不改 `plugin.json`（該檔不宣告 skills 或 commands，兩者皆慣例自動發現）。

### Verification

- 決定一的判準以 SKILL.md 內的 worked example 驗證：一個四封信的 thread（原通知 → 無具體時間的提議 → 主辦方更正 → 與會者回覆），文件須明確走出「取第三封」的推導，並說明為何不是第四封。
- 決定三的格式以 SKILL.md 內的具體範例驗證：通知寫「8/13（四）下午 3:30，行政大樓 2008 室」無結束時間、同行事曆前次同類活動為 2 小時 → 事件 15:30–17:30，notes 含 `推估：結束時間 17:30（沿用同行事曆前次同類活動時長；通知未載明）`。
- `quick-event` description 修改後，與 `archive-event` 的 description 並排閱讀時，兩者的適用情境不重疊且無需額外說明即可分辨。

### Scope

**In scope**：新增 `plugin/skills/archive-event/SKILL.md`；修改 `plugin/commands/quick-event.md` 的 description 一行。

**Out of scope**：Swift 端（`Sources/` 下所有檔案）、`plugin.json`、既有兩個 skill 的內容、`.claude/.ical/` 設定檔。

## Risks / Trade-offs

- **決定一的 (a) 條件會漏判改用其他位址寄信的更正**。緩解：漏判時走「列候選讓人挑」而非靜默取錯，失敗模式從安靜變為可見。
- **來源識別依賴來源本身有穩定識別碼**。信件有 Message-ID；口頭轉述或截圖沒有。緩解：無識別碼時退回既有 idempotency 行為，並在回報中說明該來源無法追蹤更正。
- **推估行會讓 notes 變長**。取捨：可讀性讓位給可追溯性。無推估時省略該行，一般情形不受影響。
- **skill 的判準無法被自動測試**。SKILL.md 是給 agent 讀的散文，沒有 CI 可跑。緩解：Verification 一節要求把判準寫成 worked example，讓推導過程本身可被人閱讀檢查。

## Migration Plan

無。新增 skill 不影響既有行為；`quick-event` 的 description 修改不改變其執行流程。

## Open Questions

無。三個原始未決項（設定檔格式、更正判準、重複判準）已於 discuss 階段收斂為上述決定一至四。
