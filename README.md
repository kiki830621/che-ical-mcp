# che-ical-mcp

macOS Calendar & Reminders management via MCP and EventKit.

## Features

| Category | Tool | Description |
|----------|------|-------------|
| **Calendars** | `list_calendars` | List all calendars and reminder lists |
| | `create_calendar` | Create a new calendar |
| | `delete_calendar` | Delete a calendar |
| **Events** | `list_events` | List events in a date range |
| | `create_event` | Create an event (with reminders, location, URL) |
| | `update_event` | Update an event |
| | `delete_event` | Delete an event |
| **Reminders** | `list_reminders` | List reminders |
| | `create_reminder` | Create a reminder |
| | `update_reminder` | Update a reminder |
| | `complete_reminder` | Mark as completed/incomplete |
| | `delete_reminder` | Delete a reminder |

## Requirements

- macOS 13.0+
- Xcode Command Line Tools

## Installation

### 1. Clone and Build

```bash
git clone https://github.com/kiki830621/che-ical-mcp.git
cd che-ical-mcp

# Build release version
swift build -c release

# Verify the binary exists
ls -la .build/release/CheICalMCP
```

### 2. Configure MCP Client

#### Option A: Claude Desktop

Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "che-ical-mcp": {
      "command": "/path/to/che-ical-mcp/.build/release/CheICalMCP"
    }
  }
}
```

#### Option B: Claude Code

Edit `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "che-ical-mcp": {
      "command": "/path/to/che-ical-mcp/.build/release/CheICalMCP"
    }
  }
}
```

Or use CLI:
```bash
claude mcp add che-ical-mcp /path/to/che-ical-mcp/.build/release/CheICalMCP
```

Replace `/path/to/` with your actual path.

### 3. Grant Permissions

On first use, macOS will prompt for Calendar and Reminders access. Click "Allow".

### 4. Restart

For Claude Desktop:
```bash
osascript -e 'quit app "Claude"' && sleep 2 && open -a "Claude"
```

For Claude Code:
```bash
# Start a new session
claude
```

## Usage Examples

```
"List all my calendars"
"What's on my schedule next week?"
"Create a meeting tomorrow at 2 PM in Conference Room A"
"List my incomplete reminders"
"Add a reminder: Buy milk"
"Mark 'Buy milk' as completed"
```

## Technical Details

- Built with Swift and [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk) v0.10.0
- Uses EventKit framework for native macOS Calendar and Reminders access
- Supports iCloud-synced calendars (including Google Calendar)

## Version History

- **v0.2.0** - Swift rewrite with Reminders support
- **v0.1.x** - Python version (deprecated, backup in `_python_backup/`)

## License

MIT

## Author

Created by Che Cheng ([@kiki830621](https://github.com/kiki830621))
