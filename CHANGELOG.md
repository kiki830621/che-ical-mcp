# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.0] - 2026-01-14

### Added
- **`delete_events_batch`**: Delete multiple events at once, much more efficient than calling `delete_event` multiple times
- **`find_duplicate_events`**: Find duplicate events across calendars before merging, matches by title (case-insensitive) and time (configurable tolerance)
- **Multi-keyword search**: `search_events` now supports multiple keywords with `match_mode` parameter (`any` for OR, `all` for AND)
- **PRIVACY.md**: Added privacy policy document explaining data handling

### Changed
- **Improved permission error messages**: When calendar/reminders access is denied, now provides clear instructions for granting permissions
- **Enhanced search_events response**: Now includes search metadata (keywords used, match mode, result count)

## [0.4.0] - 2026-01-14

### Added
- **`copy_event`**: Copy an event to another calendar, with optional `delete_original` flag for move behavior
- **`move_events_batch`**: Move multiple events to another calendar at once

## [0.3.0] - 2026-01-13

### Added
- **`search_events`**: Search events by keyword in title, notes, or location
- **`list_events_quick`**: Quick time range shortcuts (today, tomorrow, this_week, next_week, this_month, next_7_days, next_30_days)
- **`create_events_batch`**: Create multiple events at once with success/failure tracking
- **`check_conflicts`**: Check for overlapping events in a time range
- **Local timezone display**: All date responses now include both UTC and local time
- **Timezone field**: All responses include the current timezone identifier

## [0.2.0] - 2026-01-12

### Changed
- Complete rewrite from Python to Swift
- Native EventKit integration (no AppleScript)

### Added
- Full Reminders support: `list_reminders`, `create_reminder`, `update_reminder`, `complete_reminder`, `delete_reminder`
- Calendar management: `create_calendar`, `delete_calendar`
- Event alarms/reminders support
- URL support for events

## [0.1.0] - 2026-01-10

### Added
- Initial Python version
- Basic calendar event operations via AppleScript
- `list_calendars`, `list_events`, `create_event`, `update_event`, `delete_event`

---

## Tool Count by Version

| Version | Total Tools | New Tools |
|---------|-------------|-----------|
| 0.5.0   | 20          | +2 (delete_events_batch, find_duplicate_events) |
| 0.4.0   | 18          | +2 (copy_event, move_events_batch) |
| 0.3.0   | 16          | +4 (search_events, list_events_quick, create_events_batch, check_conflicts) |
| 0.2.0   | 12          | +7 (5 reminder tools, 2 calendar tools) |
| 0.1.0   | 5           | Initial release |
