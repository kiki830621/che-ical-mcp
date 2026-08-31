# MCP 功能驗證：先確認測試表面的 binary 版本，再選路徑

Binary 更新（release／plugin-update）後，**session 內的 MCP server 仍是舊版** — 它是
session 啟動時 spawn 的長駐 process，重啟 Claude Code（或 Claude Desktop `Cmd+Q`）
之前不會換 binary。驗證新功能時選錯表面，會拿舊 binary 的行為當新功能的證據（或反過來）。

## 鐵律：動手前先做行為探測，不憑假設判定版本

對測試表面呼叫**新版才有的欄位或 tool**，從回應判定版本。例：v1.16.0 的
`create_event` 回應會 echo `excluded_occurrence_dates` + `exclusion_count`；v1.15.0
的舊 parser 靜默忽略該欄位、回應無此欄。一次呼叫即分辨，成本近零。

**兩個方向都踩過**（2026-08-31，#186 undo 補驗）：
- 假設「session MCP = 舊版不可用」而不探測 → 繞路手寫 JSON-RPC harness（浪費，且引入新 confound）
- 反方向同樣危險：假設 session MCP 已是新版 → 舊 binary 靜默忽略新欄位，測試「通過」但什麼都沒驗到

## 三個測試表面的特性（封閉列舉 — 只有這三個，不得類推第四種）

| 表面 | Binary 版本 | 長駐狀態（undo stack 等） | read-after-write |
|------|------------|--------------------------|------------------|
| **Session MCP tools**（`mcp__che-ical-mcp__*`） | session 啟動時的 `~/bin/CheICalMCP`（更新後 = **舊版**，重啟才換） | ✅ 有 | ✅ 正常 |
| **`--cli` 單發**（`<binary> --cli` 或 stdin JSON） | 指定路徑的 binary — 可直接指 `mcpb/server/CheICalMCP`（**剛 build 的最新版**） | ❌ 無 — 每次呼叫是獨立 process，in-memory 狀態（undo/redo stack）隨 process 消失，`undo` 永遠回 "Nothing to undo" | ✅ 跨 process 讀正常 |
| **手動 spawn stdio server**（JSON-RPC pipe 長駐 process） | 指定路徑的 binary | ✅ 有 | ❌ **不可靠** — 同 process 內緊接查詢讀不到剛寫入的事件（加 1.5s pacing 亦然，2026-08-31 實測）；list 斷言面失效，只有 tool 回應訊息可作證據 |

## 路徑選擇（依待驗功能的性質）

1. **Stateless 功能**（欄位驗證、事件建立/查詢/排除語意）→ `--cli` 指向 repo 內剛 build
   的 binary。每次 fresh process、跨 process 讀正常，是 release 前實機驗證的首選。
2. **Stateful 功能**（undo/redo、任何 in-memory 跨呼叫狀態）→ 唯一乾淨表面是
   **重啟後的 session MCP tools**。`--cli` 結構上驗不了（per-process stack）；手動
   spawn 只能拿到 tool 回應訊息級的證據（"Undone batch (3 operations)" 可證機制在動，
   但「事件真的回來了」的 list 斷言會被 read-after-write confound 汙染）。
3. Release／plugin-update 完成的報告**必須明示**：「本 session 的 MCP server 仍為
   舊版 vX，重啟後生效」— 別讓下一個動作在錯的表面上驗證。

## 事故記錄（為什麼是規則不是備忘）

2026-08-31 #186 undo 補驗：v1.16.0 出貨後要驗 #182/#185 的 undo 新行為。先假設
session MCP 不可用（未探測）→ 手寫 stdio harness → 三個 FAIL 全是 harness confound
（read-after-write）而非產品 bug，浪費兩輪偵錯；使用者指正後改用 session MCP 行為
探測，一次呼叫即確認 server 為 v1.15.0。手動 harness 唯一的淨收穫是 tool 回應級
證據（#185 batch undo 機制證實）與一個真訊號（series restore `ekcaderrordomain
1010`）— 但兩者本可在重啟後 30 秒內以乾淨表面取得。
