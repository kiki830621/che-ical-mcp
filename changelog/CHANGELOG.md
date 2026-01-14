# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-01-14

### Added
- **Timezone display**: All date outputs now include local time (`*_local` fields) and `timezone` identifier
- **Search events** (`search_events`): Search events by keyword in title, notes, or location
- **Quick time range** (`list_events_quick`): Shortcuts for common ranges:
  - `today`, `tomorrow`
  - `this_week`, `next_week`
  - `this_month`
  - `next_7_days`, `next_30_days`
- **Batch create** (`create_events_batch`): Create multiple events in one call with per-event success/failure reporting
- **Conflict detection** (`check_conflicts`): Check for overlapping events before scheduling

### Changed
- Tool count increased from 12 to 16
- All event and reminder outputs now include timezone information

### Removed
- Python backup directory (`_python_backup/`) - Swift rewrite is complete

## [0.2.0] - 2026-01-13

### Added
- **Complete Swift rewrite** using official MCP Swift SDK v0.10.0
- **Reminder support** with full CRUD operations:
  - `list_reminders` - List reminders with completion filter
  - `create_reminder` - Create with due date, priority, alarms
  - `update_reminder` - Update any reminder property
  - `complete_reminder` - Mark as completed/incomplete
  - `delete_reminder` - Remove reminder
- **Calendar management**:
  - `create_calendar` - Create event calendars or reminder lists
  - `delete_calendar` - Remove calendars
- Native EventKit integration for better macOS compatibility

### Changed
- **BREAKING**: Rewritten from Python to Swift
- Claude Desktop config now points to Swift binary `.build/release/CheICalMCP`

### Technical Notes
- Uses MCP Swift SDK v0.10.0 (github.com/modelcontextprotocol/swift-sdk)
- Direct EventKit API access (no PyObjC bridge)
- StdioTransport for JSON-RPC communication
- Requires macOS 13.0+

## [0.1.0] - 2025-01-13

### Added
- Fork from [Omar-V2/mcp-ical](https://github.com/Omar-V2/mcp-ical)
- Renamed project to `che-ical-mcp`
- Added changelog directory with Keep a Changelog format

### Changed
- Updated MCP dependency from `>=1.2.1` to `>=1.25,<2` (latest stable v1.x)
- Renamed Python module from `mcp_ical` to `che_ical_mcp`
- Updated CLI command from `mcp-ical` to `che-ical-mcp`

### Technical Notes
- MCP v1.25 supports spec 2025-11-25 features:
  - Tasks Primitive (async task handling)
  - Sampling with Tools (server-side agent loops)
  - Elicitation (server-initiated user interactions)
  - Standardized tool name format (SEP-986)
- Current implementation uses basic FastMCP API (fully compatible with v1.25)
