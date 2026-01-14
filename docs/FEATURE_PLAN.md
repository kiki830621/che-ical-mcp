# 計劃：che-ical-mcp 功能擴充

> **狀態**: ✅ 已完成 (v0.3.0 + v0.4.0)
> - v0.3.0: 時區顯示、搜尋、快速範圍、批次建立、衝突檢查
> - v0.4.0: copy_event、move_events_batch
> - 工具總數: 18 個

## 目標

為 che-ical-mcp 添加 5 個新功能：
1. 時區顯示 - 返回本地時間而非 UTC
2. 搜尋/模糊查詢 - 按關鍵字搜尋事件
3. 快速時間範圍 - today, this_week, next_7_days 捷徑
4. 批次操作 - 一次建立/更新多個事件
5. 衝突檢查 - 建立前檢查時間重疊

---

## 現有架構

```
Sources/CheICalMCP/
├── main.swift              # 進入點
├── Server.swift            # MCP 工具定義 (602 行)
└── EventKit/
    └── EventKitManager.swift  # EventKit 封裝 (513 行)
```

**現有 12 個工具：**
- 日曆：list_calendars, create_calendar, delete_calendar
- 事件：list_events, create_event, update_event, delete_event
- 提醒：list_reminders, create_reminder, update_reminder, complete_reminder, delete_reminder

---

## 功能 1：時區顯示

### 問題
目前輸出 UTC：`2026-01-14T10:00:00Z`
用戶看到 10:00，實際是 18:00（台北時間）

### 方案
在輸出時添加本地時間和時區資訊：
```json
{
  "start_date": "2026-01-14T10:00:00Z",
  "start_date_local": "2026-01-14T18:00:00",
  "timezone": "Asia/Taipei"
}
```

### 修改位置
- `Server.swift` 第 16-17 行：新增 localDateFormatter
- `Server.swift` 第 375-389 行：事件輸出格式
- `Server.swift` 第 486-502 行：提醒輸出格式

### 實作
```swift
// 新增本地時間格式化器
private let localDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    f.timeZone = TimeZone.current
    return f
}()

// 輸出時添加本地時間
"start_date": dateFormatter.string(from: event.startDate),
"start_date_local": localDateFormatter.string(from: event.startDate),
"timezone": TimeZone.current.identifier
```

---

## 功能 2：搜尋/模糊查詢

### 新增工具
```swift
Tool(
    name: "search_events",
    description: "Search events by keyword in title, notes, or location",
    inputSchema: .object([
        "properties": .object([
            "keyword": .object(["type": .string("string"), "description": .string("Search keyword")]),
            "start_date": .object(["type": .string("string"), "description": .string("Optional start date")]),
            "end_date": .object(["type": .string("string"), "description": .string("Optional end date")]),
            "calendar_name": .object(["type": .string("string"), "description": .string("Optional calendar filter")])
        ]),
        "required": .array([.string("keyword")])
    ])
)
```

### EventKitManager 新增方法
```swift
func searchEvents(keyword: String, startDate: Date?, endDate: Date?, calendar: EKCalendar?) async throws -> [EKEvent] {
    let events = try await listEvents(startDate: startDate ?? .distantPast, endDate: endDate ?? .distantFuture, calendar: calendar)
    let lowercased = keyword.lowercased()
    return events.filter { event in
        event.title?.lowercased().contains(lowercased) == true ||
        event.notes?.lowercased().contains(lowercased) == true ||
        event.location?.lowercased().contains(lowercased) == true
    }
}
```

---

## 功能 3：快速時間範圍

### 方案 A：新增獨立工具（推薦）
```swift
Tool(
    name: "list_events_quick",
    description: "List events with quick time range shortcuts",
    inputSchema: .object([
        "properties": .object([
            "range": .object([
                "type": .string("string"),
                "enum": .array([.string("today"), .string("tomorrow"), .string("this_week"), .string("next_week"), .string("this_month"), .string("next_7_days"), .string("next_30_days")]),
                "description": .string("Quick time range")
            ]),
            "calendar_name": .object(["type": .string("string")])
        ]),
        "required": .array([.string("range")])
    ])
)
```

### 輔助函數
```swift
private func getDateRange(for shortcut: String) -> (start: Date, end: Date) {
    let calendar = Calendar.current
    let now = Date()
    let startOfToday = calendar.startOfDay(for: now)

    switch shortcut {
    case "today":
        return (startOfToday, calendar.date(byAdding: .day, value: 1, to: startOfToday)!)
    case "tomorrow":
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        return (tomorrow, calendar.date(byAdding: .day, value: 1, to: tomorrow)!)
    case "this_week":
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        return (weekStart, calendar.date(byAdding: .day, value: 7, to: weekStart)!)
    case "next_week":
        let nextWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!)!
        return (nextWeekStart, calendar.date(byAdding: .day, value: 7, to: nextWeekStart)!)
    case "this_month":
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        return (monthStart, calendar.date(byAdding: .month, value: 1, to: monthStart)!)
    case "next_7_days":
        return (startOfToday, calendar.date(byAdding: .day, value: 7, to: startOfToday)!)
    case "next_30_days":
        return (startOfToday, calendar.date(byAdding: .day, value: 30, to: startOfToday)!)
    default:
        return (startOfToday, calendar.date(byAdding: .day, value: 1, to: startOfToday)!)
    }
}
```

---

## 功能 4：批次操作

### 新增工具
```swift
Tool(
    name: "create_events_batch",
    description: "Create multiple events at once",
    inputSchema: .object([
        "properties": .object([
            "events": .object([
                "type": .string("array"),
                "items": .object([
                    "type": .string("object"),
                    "properties": .object([
                        "title": .object(["type": .string("string")]),
                        "start_time": .object(["type": .string("string")]),
                        "end_time": .object(["type": .string("string")]),
                        // ... 其他欄位
                    ])
                ])
            ])
        ]),
        "required": .array([.string("events")])
    ])
)
```

### EventKitManager 新增方法
```swift
func createEventsBatch(_ inputs: [EventInput]) async throws -> [EKEvent] {
    var results: [EKEvent] = []
    for input in inputs {
        let event = try await createEvent(...)
        results.append(event)
    }
    return results
}
```

---

## 功能 5：衝突檢查

### 新增工具
```swift
Tool(
    name: "check_conflicts",
    description: "Check for overlapping events in a time range",
    inputSchema: .object([
        "properties": .object([
            "start_time": .object(["type": .string("string"), "description": .string("Start time to check")]),
            "end_time": .object(["type": .string("string"), "description": .string("End time to check")]),
            "calendar_name": .object(["type": .string("string"), "description": .string("Optional calendar filter")]),
            "exclude_event_id": .object(["type": .string("string"), "description": .string("Exclude this event from check (for updates)")])
        ]),
        "required": .array([.string("start_time"), .string("end_time")])
    ])
)
```

### EventKitManager 新增方法
```swift
func checkConflicts(startDate: Date, endDate: Date, calendar: EKCalendar?, excludeEventId: String?) async throws -> [EKEvent] {
    let events = try await listEvents(startDate: startDate, endDate: endDate, calendar: calendar)
    return events.filter { event in
        if let excludeId = excludeEventId, event.eventIdentifier == excludeId {
            return false
        }
        // 檢查時間重疊
        return event.startDate < endDate && event.endDate > startDate
    }
}
```

---

## 關鍵檔案

| 檔案 | 修改內容 |
|------|---------|
| `Server.swift` | 新增 5 個工具定義、5 個 handler、修改日期輸出格式 |
| `EventKitManager.swift` | 新增 searchEvents、checkConflicts 方法 |

---

## 實作順序

1. **時區顯示** - 影響最小，只改輸出格式
2. **快速時間範圍** - 新增工具，不改現有邏輯
3. **搜尋** - 新增工具 + EventKitManager 方法
4. **衝突檢查** - 新增工具 + EventKitManager 方法
5. **批次操作** - 最複雜，需要處理部分失敗

---

## 驗證方式

```bash
# 編譯
cd /Users/che/Library/CloudStorage/Dropbox/che_workspace/projects/mcp/che-ical-mcp
swift build -c release

# 測試時區顯示
echo '{"jsonrpc":"2.0","id":1,"method":"initialize",...}
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"list_events","arguments":{"start_date":"2026-01-14T00:00:00Z","end_date":"2026-01-15T00:00:00Z"}}}' | .build/release/CheICalMCP

# 測試搜尋
{"name":"search_events","arguments":{"keyword":"尾牙"}}

# 測試快速範圍
{"name":"list_events_quick","arguments":{"range":"this_week"}}

# 測試衝突檢查
{"name":"check_conflicts","arguments":{"start_time":"2026-01-14T14:00:00Z","end_time":"2026-01-14T15:00:00Z"}}
```
