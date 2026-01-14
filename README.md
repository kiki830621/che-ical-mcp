# che-ical-mcp

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org/)
[![MCP](https://img.shields.io/badge/MCP-Compatible-green.svg)](https://modelcontextprotocol.io/)

**macOS Calendar & Reminders MCP server** - Native EventKit integration for complete calendar and task management.

[English](README.md) | [繁體中文](README_zh-TW.md)

---

## Why che-ical-mcp?

| Feature | Other Calendar MCPs | che-ical-mcp |
|---------|---------------------|--------------|
| Calendar Events | Yes | Yes |
| **Reminders/Tasks** | No | **Yes** |
| **Multi-keyword Search** | No | **Yes** |
| **Duplicate Detection** | No | **Yes** |
| **Conflict Detection** | No | **Yes** |
| **Batch Operations** | No | **Yes** |
| **Local Timezone** | No | **Yes** |
| **Source Disambiguation** | No | **Yes** |
| Create Calendar | Some | Yes |
| Delete Calendar | Some | Yes |
| Event Reminders | Some | Yes |
| Location & URL | Some | Yes |
| Language | Python | **Swift (Native)** |

---

## Quick Start

### For Claude Desktop

#### Option A: MCPB One-Click Install (Recommended)

Download the latest `.mcpb` file from [Releases](https://github.com/kiki830621/che-ical-mcp/releases) and double-click to install.

#### Option B: Manual Configuration

Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "che-ical-mcp": {
      "command": "/usr/local/bin/che-ical-mcp"
    }
  }
}
```

### For Claude Code (CLI)

```bash
# Download the latest release
curl -L https://github.com/kiki830621/che-ical-mcp/releases/latest/download/CheICalMCP -o /usr/local/bin/che-ical-mcp
chmod +x /usr/local/bin/che-ical-mcp

# Add to Claude Code
claude mcp add che-ical-mcp /usr/local/bin/che-ical-mcp
```

### Build from Source (Optional)

```bash
git clone https://github.com/kiki830621/che-ical-mcp.git
cd che-ical-mcp
swift build -c release
```

On first use, macOS will prompt for **Calendar** and **Reminders** access - click "Allow".

---

## All 20 Tools

<details>
<summary><b>Calendars (3)</b></summary>

| Tool | Description |
|------|-------------|
| `list_calendars` | List all calendars and reminder lists |
| `create_calendar` | Create a new calendar |
| `delete_calendar` | Delete a calendar |

</details>

<details>
<summary><b>Events (4)</b></summary>

| Tool | Description |
|------|-------------|
| `list_events` | List events in a date range |
| `create_event` | Create an event (with reminders, location, URL) |
| `update_event` | Update an event |
| `delete_event` | Delete an event |

</details>

<details>
<summary><b>Reminders (5)</b></summary>

| Tool | Description |
|------|-------------|
| `list_reminders` | List reminders (all or by list) |
| `create_reminder` | Create a reminder with due date |
| `update_reminder` | Update a reminder |
| `complete_reminder` | Mark as completed/incomplete |
| `delete_reminder` | Delete a reminder |

</details>

<details>
<summary><b>Advanced Features (8)</b> ✨ New in v0.3.0+</summary>

| Tool | Description |
|------|-------------|
| `search_events` | Search events by keyword(s) with AND/OR matching |
| `list_events_quick` | Quick shortcuts: `today`, `tomorrow`, `this_week`, `next_7_days`, etc. |
| `create_events_batch` | Create multiple events at once |
| `check_conflicts` | Check for overlapping events in a time range |
| `copy_event` | Copy an event to another calendar (with optional move) |
| `move_events_batch` | Move multiple events to another calendar |
| `delete_events_batch` | Delete multiple events at once (v0.5.0) |
| `find_duplicate_events` | Find duplicate events across calendars (v0.5.0) |

</details>

---

## Installation

### Requirements

- macOS 13.0+
- Xcode Command Line Tools (only if building from source)

### For Claude Desktop

#### Method 1: MCPB One-Click Install (Recommended)

1. Download `che-ical-mcp.mcpb` from [Releases](https://github.com/kiki830621/che-ical-mcp/releases)
2. Double-click the `.mcpb` file to install
3. Restart Claude Desktop

#### Method 2: Manual Configuration

1. Download the binary:
   ```bash
   curl -L https://github.com/kiki830621/che-ical-mcp/releases/latest/download/CheICalMCP -o /usr/local/bin/che-ical-mcp
   chmod +x /usr/local/bin/che-ical-mcp
   ```

2. Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:
   ```json
   {
     "mcpServers": {
       "che-ical-mcp": {
         "command": "/usr/local/bin/che-ical-mcp"
       }
     }
   }
   ```

3. Restart Claude Desktop

### For Claude Code (CLI)

```bash
# Download the binary
curl -L https://github.com/kiki830621/che-ical-mcp/releases/latest/download/CheICalMCP -o /usr/local/bin/che-ical-mcp
chmod +x /usr/local/bin/che-ical-mcp

# Register with Claude Code
claude mcp add che-ical-mcp /usr/local/bin/che-ical-mcp
```

### Build from Source (Optional)

```bash
git clone https://github.com/kiki830621/che-ical-mcp.git
cd che-ical-mcp
swift build -c release

# For Claude Code
claude mcp add che-ical-mcp "$(pwd)/.build/release/CheICalMCP"
```

### Grant Permissions

On first use, macOS will prompt for **Calendar** and **Reminders** access. Click **Allow** for both.

---

## Usage Examples

### Calendar Management

```
"List all my calendars"
"What's on my schedule next week?"
"Create a meeting tomorrow at 2 PM titled 'Team Sync'"
"Add a dentist appointment on Friday at 10 AM with location '123 Main St'"
"Delete the meeting called 'Cancelled Meeting'"
```

### Reminder Management

```
"List my incomplete reminders"
"Show all reminders in my Shopping list"
"Add a reminder: Buy milk"
"Create a reminder to call mom tomorrow at 5 PM"
"Mark 'Buy milk' as completed"
"Delete the reminder about groceries"
```

### Advanced Features (v0.3.0+)

```
"Search for events containing 'meeting'"
"Search for events with both 'project' AND 'review'"
"What do I have today?"
"Show me this week's schedule"
"Are there any conflicts if I schedule a meeting from 2-3 PM?"
"Create 3 weekly team meetings for the next 3 weeks"
"Copy the dentist appointment to my Work calendar"
"Move all events from 'Old Calendar' to 'New Calendar'"
"Delete all the cancelled events"
"Find duplicate events between 'IDOL' and 'Idol' calendars"
```

---

## Supported Calendar Sources

Works with any calendar synced to macOS Calendar app:

- iCloud Calendar
- Google Calendar
- Microsoft Outlook/Exchange
- CalDAV calendars
- Local calendars

### Same-Name Calendar Disambiguation (v0.6.0+)

If you have calendars with the same name from different sources (e.g., "Work" in both iCloud and Google), use the `calendar_source` parameter:

```
"Create an event in my iCloud Work calendar"
→ create_event(calendar_name: "Work", calendar_source: "iCloud", ...)

"Show events from my Google Work calendar"
→ list_events(calendar_name: "Work", calendar_source: "Google", ...)
```

If ambiguity is detected, the error message will list all available sources.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Server disconnected | Rebuild with `swift build -c release` |
| Permission denied | Grant Calendar/Reminders access in System Settings > Privacy |
| Calendar not found | Ensure the calendar is visible in macOS Calendar app |
| Reminders not syncing | Check iCloud sync in System Settings |

---

## Technical Details

- **Current Version**: v0.6.0
- **Framework**: [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk) v0.10.0
- **Calendar API**: EventKit (native macOS framework)
- **Transport**: stdio
- **Platform**: macOS 13.0+ (Ventura and later)
- **Tools**: 20 tools for calendars, events, reminders, and advanced operations

---

## Version History

| Version | Changes |
|---------|---------|
| v0.6.0 | **Source disambiguation**: `calendar_source` parameter for same-name calendars |
| v0.5.0 | Batch delete, duplicate detection, multi-keyword search, improved permission errors, PRIVACY.md |
| v0.4.0 | Copy/move events: `copy_event`, `move_events_batch` |
| v0.3.0 | Advanced features: search, quick range, batch create, conflict check, timezone display |
| v0.2.0 | Swift rewrite with full Reminders support |
| v0.1.x | Python version (deprecated) |

---

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

## Author

Created by **Che Cheng** ([@kiki830621](https://github.com/kiki830621))

If you find this useful, please consider giving it a star!
