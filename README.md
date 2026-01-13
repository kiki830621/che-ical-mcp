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
| Create Calendar | Some | Yes |
| Delete Calendar | Some | Yes |
| Event Reminders | Some | Yes |
| Location & URL | Some | Yes |
| Language | Python | **Swift (Native)** |

---

## Quick Start

```bash
# Clone and build
git clone https://github.com/kiki830621/che-ical-mcp.git
cd che-ical-mcp
swift build -c release

# Add to Claude Code
claude mcp add che-ical-mcp "$(pwd)/.build/release/CheICalMCP"
```

On first use, macOS will prompt for **Calendar** and **Reminders** access - click "Allow".

---

## All 12 Tools

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

---

## Installation

### Requirements

- macOS 13.0+
- Xcode Command Line Tools

### Step 1: Build

```bash
git clone https://github.com/kiki830621/che-ical-mcp.git
cd che-ical-mcp
swift build -c release
```

### Step 2: Configure

#### For Claude Desktop

Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "che-ical-mcp": {
      "command": "/full/path/to/che-ical-mcp/.build/release/CheICalMCP"
    }
  }
}
```

#### For Claude Code (CLI)

```bash
claude mcp add che-ical-mcp /full/path/to/che-ical-mcp/.build/release/CheICalMCP
```

### Step 3: Grant Permissions

On first use, macOS will prompt for Calendar and Reminders access. Click **Allow** for both.

### Step 4: Restart Claude

```bash
# For Claude Desktop
osascript -e 'quit app "Claude"' && sleep 2 && open -a "Claude"

# For Claude Code - start a new session
claude
```

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

---

## Supported Calendar Sources

Works with any calendar synced to macOS Calendar app:

- iCloud Calendar
- Google Calendar
- Microsoft Outlook/Exchange
- CalDAV calendars
- Local calendars

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

- **Framework**: [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk) v0.10.0
- **Calendar API**: EventKit (native macOS framework)
- **Transport**: stdio
- **Platform**: macOS 13.0+ (Ventura and later)

---

## Version History

| Version | Changes |
|---------|---------|
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
