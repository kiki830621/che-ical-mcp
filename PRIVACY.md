# Privacy Policy - che-ical-mcp

## Overview

che-ical-mcp is a local MCP (Model Context Protocol) server that provides calendar and reminder management capabilities through macOS EventKit. This document explains how your data is handled.

## Data Access

This MCP server accesses the following data on your Mac:

- **Calendar Events**: Read, create, update, delete events in Calendar.app
- **Reminders**: Read, create, update, delete items in Reminders.app
- **Calendar Metadata**: Names, colors, and source information for calendars

## Data Storage

**No data is stored** outside of macOS EventKit.

- All calendar and reminder data remains in your native Apple apps
- No data is written to external files, databases, or caches
- No data is transmitted to external servers or cloud services
- All operations are performed locally on your Mac

## Data Transmission

**No data is transmitted** to external services.

- che-ical-mcp operates entirely offline
- All communication happens locally via MCP protocol (stdin/stdout)
- No network connections are made by this server
- No analytics, telemetry, or usage tracking

## Required Permissions

To function, che-ical-mcp requires the following macOS permissions:

### Calendar Access
- **Purpose**: Read and modify calendar events
- **Permission**: Full Access to Calendars
- **Grant via**: System Settings > Privacy & Security > Calendars

### Reminders Access (Optional)
- **Purpose**: Read and modify reminders
- **Permission**: Full Access to Reminders
- **Grant via**: System Settings > Privacy & Security > Reminders

## How to Grant Permissions

1. The first time you use a calendar or reminder tool, macOS will prompt for permission
2. Alternatively, grant permissions manually:
   - Open **System Settings**
   - Navigate to **Privacy & Security**
   - Select **Calendars** (and/or **Reminders**)
   - Enable access for the MCP server binary or Terminal/iTerm

## How to Revoke Access

If you wish to revoke access:

1. Open **System Settings**
2. Navigate to **Privacy & Security**
3. Select **Calendars** (or **Reminders**)
4. Disable access for the MCP server

Alternatively, you can delete the MCP server binary from your system.

## Third-Party Services

This server does **not** connect to any third-party services:

- No cloud sync services
- No API calls to external servers
- No integration with non-local services
- No data sharing with third parties

## Open Source

che-ical-mcp is open source software licensed under the MIT License. You can review the source code to verify these privacy practices:

- All code is available for inspection
- No hidden functionality
- No obfuscated network calls

## Updates to This Policy

This privacy policy may be updated as the software evolves. Any changes will be documented in the project's CHANGELOG.

## Contact

For questions or concerns about privacy, please open an issue on the project's GitHub repository.

---

*Last updated: 2026-01-14*
*Version: 0.5.0*
