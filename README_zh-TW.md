# che-ical-mcp

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org/)
[![MCP](https://img.shields.io/badge/MCP-Compatible-green.svg)](https://modelcontextprotocol.io/)

**macOS 行事曆與提醒事項 MCP 伺服器** - 原生 EventKit 整合，完整的行事曆和任務管理。

[English](README.md) | [繁體中文](README_zh-TW.md)

---

## 為什麼選擇 che-ical-mcp？

| 功能 | 其他行事曆 MCP | che-ical-mcp |
|------|----------------|--------------|
| 行事曆事件 | 有 | 有 |
| **提醒事項/任務** | 無 | **有** |
| **多關鍵字搜尋** | 無 | **有** |
| **重複事件偵測** | 無 | **有** |
| **衝突檢測** | 無 | **有** |
| **批次操作** | 無 | **有** |
| **本地時區** | 無 | **有** |
| **來源消歧義** | 無 | **有** |
| 建立行事曆 | 部分 | 有 |
| 刪除行事曆 | 部分 | 有 |
| 事件提醒 | 部分 | 有 |
| 地點與網址 | 部分 | 有 |
| 開發語言 | Python | **Swift (原生)** |

---

## 快速開始

### 方式 A：下載 Release（推薦）

```bash
# 下載最新版本
curl -L https://github.com/kiki830621/che-ical-mcp/releases/latest/download/CheICalMCP -o /usr/local/bin/che-ical-mcp
chmod +x /usr/local/bin/che-ical-mcp

# 加入 Claude Code
claude mcp add che-ical-mcp /usr/local/bin/che-ical-mcp
```

### 方式 B：從原始碼編譯

```bash
# 複製並編譯
git clone https://github.com/kiki830621/che-ical-mcp.git
cd che-ical-mcp
swift build -c release

# 加入 Claude Code
claude mcp add che-ical-mcp "$(pwd)/.build/release/CheICalMCP"
```

首次使用時，macOS 會詢問**行事曆**和**提醒事項**存取權限 - 請點選「允許」。

---

## 全部 20 個工具

<details>
<summary><b>行事曆 (3)</b></summary>

| 工具 | 說明 |
|------|------|
| `list_calendars` | 列出所有行事曆和提醒事項清單 |
| `create_calendar` | 建立新行事曆 |
| `delete_calendar` | 刪除行事曆 |

</details>

<details>
<summary><b>事件 (4)</b></summary>

| 工具 | 說明 |
|------|------|
| `list_events` | 列出日期範圍內的事件 |
| `create_event` | 建立事件（支援提醒、地點、網址） |
| `update_event` | 更新事件 |
| `delete_event` | 刪除事件 |

</details>

<details>
<summary><b>提醒事項 (5)</b></summary>

| 工具 | 說明 |
|------|------|
| `list_reminders` | 列出提醒事項（全部或依清單） |
| `create_reminder` | 建立含到期日的提醒事項 |
| `update_reminder` | 更新提醒事項 |
| `complete_reminder` | 標記為已完成/未完成 |
| `delete_reminder` | 刪除提醒事項 |

</details>

<details>
<summary><b>進階功能 (8)</b> ✨ v0.3.0+ 新增</summary>

| 工具 | 說明 |
|------|------|
| `search_events` | 多關鍵字搜尋事件，支援 AND/OR 匹配 |
| `list_events_quick` | 快速捷徑：`today`、`tomorrow`、`this_week`、`next_7_days` 等 |
| `create_events_batch` | 一次建立多個事件 |
| `check_conflicts` | 檢查指定時間範圍是否有重疊事件 |
| `copy_event` | 複製事件到另一個日曆（可選擇移動） |
| `move_events_batch` | 批次移動事件到另一個日曆 |
| `delete_events_batch` | 批次刪除多個事件（v0.5.0） |
| `find_duplicate_events` | 跨日曆查找重複事件（v0.5.0） |

</details>

---

## 安裝方式

### 系統需求

- macOS 13.0+
- Xcode 命令列工具（僅從原始碼編譯時需要）

### 步驟 1：取得執行檔

#### 方式 A：從 Release 下載（推薦）

```bash
# 下載到 /usr/local/bin
curl -L https://github.com/kiki830621/che-ical-mcp/releases/latest/download/CheICalMCP -o /usr/local/bin/che-ical-mcp
chmod +x /usr/local/bin/che-ical-mcp
```

#### 方式 B：從原始碼編譯

```bash
git clone https://github.com/kiki830621/che-ical-mcp.git
cd che-ical-mcp
swift build -c release
```

### 步驟 2：設定

#### Claude Desktop

編輯 `~/Library/Application Support/Claude/claude_desktop_config.json`：

```json
{
  "mcpServers": {
    "che-ical-mcp": {
      "command": "/完整路徑/che-ical-mcp/.build/release/CheICalMCP"
    }
  }
}
```

#### Claude Code (CLI)

```bash
claude mcp add che-ical-mcp /完整路徑/che-ical-mcp/.build/release/CheICalMCP
```

### 步驟 3：授予權限

首次使用時，macOS 會詢問行事曆和提醒事項存取權限。請點選**允許**。

### 步驟 4：重新啟動 Claude

```bash
# Claude Desktop
osascript -e 'quit app "Claude"' && sleep 2 && open -a "Claude"

# Claude Code - 開啟新的 session
claude
```

---

## 使用範例

### 行事曆管理

```
「列出我所有的行事曆」
「下週有什麼行程？」
「明天下午 2 點建立一個標題為『團隊同步』的會議」
「星期五早上 10 點加一個牙醫預約，地點是『台北市信義路 123 號』」
「刪除『已取消的會議』這個事件」
```

### 提醒事項管理

```
「列出我未完成的提醒事項」
「顯示購物清單中的所有提醒事項」
「新增提醒事項：買牛奶」
「建立一個明天下午 5 點打電話給媽媽的提醒」
「將『買牛奶』標記為已完成」
「刪除關於雜貨的提醒事項」
```

### 進階功能（v0.3.0+）

```
「搜尋包含『會議』的事件」
「搜尋同時包含『專案』和『審查』的事件」
「今天有什麼行程？」
「顯示這週的行程」
「如果我在下午 2-3 點安排會議，會有衝突嗎？」
「幫我建立接下來 3 週的週會」
「把牙醫預約複製到工作行事曆」
「把舊行事曆的所有事件移到新行事曆」
「刪除所有已取消的事件」
「找出『IDOL』和『Idol』行事曆中的重複事件」
```

---

## 支援的行事曆來源

支援任何同步到 macOS 行事曆 App 的行事曆：

- iCloud 行事曆
- Google 日曆
- Microsoft Outlook/Exchange
- CalDAV 行事曆
- 本機行事曆

### 同名日曆消歧義（v0.6.0+）

如果你有來自不同來源的同名日曆（例如 iCloud 和 Google 都有「工作」日曆），可以使用 `calendar_source` 參數：

```
「在 iCloud 的工作日曆建立事件」
→ create_event(calendar_name: "工作", calendar_source: "iCloud", ...)

「顯示 Google 工作日曆的事件」
→ list_events(calendar_name: "工作", calendar_source: "Google", ...)
```

如果偵測到歧義，錯誤訊息會列出所有可用的來源。

---

## 疑難排解

| 問題 | 解決方法 |
|------|----------|
| Server disconnected | 重新編譯 `swift build -c release` |
| 權限被拒絕 | 在系統設定 > 隱私權中授予行事曆/提醒事項存取權限 |
| 找不到行事曆 | 確認行事曆在 macOS 行事曆 App 中可見 |
| 提醒事項未同步 | 在系統設定中檢查 iCloud 同步 |

---

## 技術細節

- **目前版本**：v0.6.0
- **框架**：[MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk) v0.10.0
- **行事曆 API**：EventKit（原生 macOS 框架）
- **傳輸**：stdio
- **平台**：macOS 13.0+（Ventura 及更新版本）
- **工具數量**：20 個工具，涵蓋行事曆、事件、提醒事項和進階操作

---

## 版本歷史

| 版本 | 變更 |
|------|------|
| v0.6.0 | **來源消歧義**：`calendar_source` 參數支援同名日曆區分 |
| v0.5.0 | 批次刪除、重複偵測、多關鍵字搜尋、改善權限錯誤、新增 PRIVACY.md |
| v0.4.0 | 事件複製/移動：`copy_event`、`move_events_batch` |
| v0.3.0 | 進階功能：搜尋、快速範圍、批次建立、衝突檢查、時區顯示 |
| v0.2.0 | Swift 重寫，完整支援提醒事項 |
| v0.1.x | Python 版本（已棄用） |

---

## 貢獻

歡迎貢獻！請隨時提交 Pull Request。

---

## 授權

MIT License - 詳見 [LICENSE](LICENSE)。

---

## 作者

由 **鄭澈** ([@kiki830621](https://github.com/kiki830621)) 建立

如果覺得有用，請給個 Star 支持一下！
