# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
