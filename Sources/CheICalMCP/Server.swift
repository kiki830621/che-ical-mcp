import EventKit
import Foundation
import MCP

/// MCP Server for EventKit integration
class CheICalMCPServer {
    private let server: Server
    private let transport: StdioTransport
    private let eventKitManager = EventKitManager.shared
    private let dateFormatter: ISO8601DateFormatter

    /// Local time formatter for user-friendly display
    private let localDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.timeZone = TimeZone.current
        return f
    }()

    /// All available tools
    private let tools: [Tool]

    init() async throws {
        dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]

        // Define all tools
        tools = Self.defineTools()

        // Create server with tools capability
        server = Server(
            name: AppVersion.name,
            version: AppVersion.current,
            capabilities: .init(tools: .init())
        )

        transport = StdioTransport()

        // Register handlers
        await registerHandlers()
    }

    func run() async throws {
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }

    // MARK: - Tool Definitions

    private static func defineTools() -> [Tool] {
        [
            // Calendar Tools
            Tool(
                name: "list_calendars",
                description: "List all available calendars. Returns both event calendars and reminder lists.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "type": .object([
                            "type": .string("string"),
                            "description": .string("Filter by type: 'event' or 'reminder'. If not provided, returns all calendars.")
                        ])
                    ])
                ]),
                annotations: .init(readOnlyHint: true, openWorldHint: false)
            ),
            Tool(
                name: "create_calendar",
                description: "Create a new calendar or reminder list.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "title": .object([
                            "type": .string("string"),
                            "description": .string("The name of the calendar")
                        ]),
                        "type": .object([
                            "type": .string("string"),
                            "description": .string("Type of calendar: 'event' or 'reminder'")
                        ]),
                        "color": .object([
                            "type": .string("string"),
                            "description": .string("Optional hex color code (e.g., '#FF5733')")
                        ])
                    ]),
                    "required": .array([.string("title"), .string("type")])
                ]),
                annotations: .init(readOnlyHint: false, destructiveHint: false, openWorldHint: false)
            ),
            Tool(
                name: "delete_calendar",
                description: "Delete a calendar by its identifier.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "id": .object([
                            "type": .string("string"),
                            "description": .string("The calendar identifier")
                        ])
                    ]),
                    "required": .array([.string("id")])
                ]),
                annotations: .init(readOnlyHint: false, destructiveHint: true, openWorldHint: false)
            ),

            // Event Tools
            Tool(
                name: "list_events",
                description: "List calendar events in a date range. Use ISO8601 format with timezone (e.g., 2026-01-30T00:00:00+08:00).",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "start_date": .object([
                            "type": .string("string"),
                            "description": .string("Start date in ISO8601 format with timezone (e.g., 2026-01-30T00:00:00+08:00)")
                        ]),
                        "end_date": .object([
                            "type": .string("string"),
                            "description": .string("End date in ISO8601 format with timezone (e.g., 2026-01-30T23:59:59+08:00)")
                        ]),
                        "calendar_name": .object([
                            "type": .string("string"),
                            "description": .string("Optional calendar name to filter by")
                        ]),
                        "calendar_source": .object([
                            "type": .string("string"),
                            "description": .string("Calendar source name (e.g., 'iCloud', 'Google', 'Exchange'). Required when multiple calendars share the same name.")
                        ])
                    ]),
                    "required": .array([.string("start_date"), .string("end_date")])
                ]),
                annotations: .init(readOnlyHint: true, openWorldHint: false)
            ),
            Tool(
                name: "create_event",
                description: "Create a new calendar event with optional reminders and recurrence.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "title": .object(["type": .string("string"), "description": .string("Event title")]),
                        "start_time": .object(["type": .string("string"), "description": .string("Start time in ISO8601 format with timezone (e.g., 2026-01-30T14:00:00+08:00)")]),
                        "end_time": .object(["type": .string("string"), "description": .string("End time in ISO8601 format with timezone (e.g., 2026-01-30T15:00:00+08:00)")]),
                        "notes": .object(["type": .string("string"), "description": .string("Optional event notes")]),
                        "location": .object(["type": .string("string"), "description": .string("Optional event location")]),
                        "url": .object(["type": .string("string"), "description": .string("Optional event URL")]),
                        "calendar_name": .object(["type": .string("string"), "description": .string("Target calendar name (use list_calendars to see available options)")]),
                        "calendar_source": .object(["type": .string("string"), "description": .string("Calendar source (e.g., 'iCloud', 'Google'). Required when multiple calendars share the same name.")]),
                        "all_day": .object(["type": .string("boolean"), "description": .string("Whether this is an all-day event")]),
                        "alarms_minutes_offsets": .object([
                            "type": .string("array"),
                            "items": .object(["type": .string("integer")]),
                            "description": .string("List of minutes before the event to trigger reminders")
                        ])
                    ]),
                    "required": .array([.string("title"), .string("start_time"), .string("end_time"), .string("calendar_name")])
                ]),
                annotations: .init(readOnlyHint: false, destructiveHint: false, openWorldHint: false)
            ),
            Tool(
                name: "update_event",
                description: "Update an existing calendar event. When changing the event date, providing only start_time will automatically preserve the original duration.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "event_id": .object(["type": .string("string"), "description": .string("The event identifier")]),
                        "title": .object(["type": .string("string"), "description": .string("New title")]),
                        "start_time": .object(["type": .string("string"), "description": .string("New start time in ISO8601 format (e.g., 2026-01-31T14:00:00+08:00). If only start_time is provided, the event duration is preserved automatically.")]),
                        "end_time": .object(["type": .string("string"), "description": .string("New end time in ISO8601 format (e.g., 2026-01-31T15:00:00+08:00). Provide this if you want to change the event duration.")]),
                        "notes": .object(["type": .string("string"), "description": .string("New notes")]),
                        "location": .object(["type": .string("string"), "description": .string("New location")]),
                        "all_day": .object(["type": .string("boolean"), "description": .string("Set to true for all-day events, false for timed events")]),
                        "calendar_name": .object(["type": .string("string"), "description": .string("Move event to a different calendar")]),
                        "calendar_source": .object(["type": .string("string"), "description": .string("Calendar source (e.g., 'iCloud', 'Google'). Required when multiple calendars share the same name.")])
                    ]),
                    "required": .array([.string("event_id")])
                ]),
                annotations: .init(readOnlyHint: false, destructiveHint: false, openWorldHint: false)
            ),
            Tool(
                name: "delete_event",
                description: "Delete a calendar event.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "event_id": .object(["type": .string("string"), "description": .string("The event identifier")]),
                        "span": .object(["type": .string("string"), "description": .string("For recurring events: 'this' or 'future'")])
                    ]),
                    "required": .array([.string("event_id")])
                ]),
                annotations: .init(readOnlyHint: false, destructiveHint: true, openWorldHint: false)
            ),

            // Reminder Tools
            Tool(
                name: "list_reminders",
                description: "List reminders from the Reminders app.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "completed": .object(["type": .string("boolean"), "description": .string("Filter: true=completed, false=incomplete, omit=all")]),
                        "calendar_name": .object(["type": .string("string"), "description": .string("Optional reminder list name")]),
                        "calendar_source": .object(["type": .string("string"), "description": .string("Calendar source (e.g., 'iCloud', 'Google'). Required when multiple lists share the same name.")])
                    ])
                ]),
                annotations: .init(readOnlyHint: true, openWorldHint: false)
            ),
            Tool(
                name: "create_reminder",
                description: "Create a new reminder.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "title": .object(["type": .string("string"), "description": .string("Reminder title")]),
                        "notes": .object(["type": .string("string"), "description": .string("Optional notes")]),
                        "due_date": .object(["type": .string("string"), "description": .string("Optional due date in ISO8601 format with timezone (e.g., 2026-01-30T17:00:00+08:00)")]),
                        "priority": .object(["type": .string("integer"), "description": .string("Priority: 0=none, 1=high, 5=medium, 9=low")]),
                        "calendar_name": .object(["type": .string("string"), "description": .string("Target reminder list name (use list_calendars with type='reminder' to see available options)")]),
                        "calendar_source": .object(["type": .string("string"), "description": .string("Calendar source (e.g., 'iCloud', 'Google'). Required when multiple lists share the same name.")])
                    ]),
                    "required": .array([.string("title"), .string("calendar_name")])
                ]),
                annotations: .init(readOnlyHint: false, destructiveHint: false, openWorldHint: false)
            ),
            Tool(
                name: "update_reminder",
                description: "Update an existing reminder.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "reminder_id": .object(["type": .string("string"), "description": .string("The reminder identifier")]),
                        "title": .object(["type": .string("string"), "description": .string("New title")]),
                        "notes": .object(["type": .string("string"), "description": .string("New notes")]),
                        "due_date": .object(["type": .string("string"), "description": .string("New due date")]),
                        "priority": .object(["type": .string("integer"), "description": .string("New priority")]),
                        "calendar_name": .object(["type": .string("string"), "description": .string("Move reminder to a different list")]),
                        "calendar_source": .object(["type": .string("string"), "description": .string("Calendar source (e.g., 'iCloud', 'Google'). Required when multiple lists share the same name.")])
                    ]),
                    "required": .array([.string("reminder_id")])
                ]),
                annotations: .init(readOnlyHint: false, destructiveHint: false, openWorldHint: false)
            ),
            Tool(
                name: "complete_reminder",
                description: "Mark a reminder as completed or incomplete.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "reminder_id": .object(["type": .string("string"), "description": .string("The reminder identifier")]),
                        "completed": .object(["type": .string("boolean"), "description": .string("true=completed, false=incomplete")])
                    ]),
                    "required": .array([.string("reminder_id")])
                ]),
                annotations: .init(readOnlyHint: false, destructiveHint: false, openWorldHint: false)
            ),
            Tool(
                name: "delete_reminder",
                description: "Delete a reminder.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "reminder_id": .object(["type": .string("string"), "description": .string("The reminder identifier")])
                    ]),
                    "required": .array([.string("reminder_id")])
                ]),
                annotations: .init(readOnlyHint: false, destructiveHint: true, openWorldHint: false)
            ),

            // New Feature Tools

            // Feature 2: Search Events (enhanced with multi-keyword support)
            Tool(
                name: "search_events",
                description: "Search events by keyword(s) in title, notes, or location. Supports single keyword or multiple keywords with AND/OR matching. Without date range, searches all events (may be slow for large calendars).",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "keyword": .object(["type": .string("string"), "description": .string("Single search keyword (case-insensitive). Use this OR keywords, not both.")]),
                        "keywords": .object([
                            "type": .string("array"),
                            "items": .object(["type": .string("string")]),
                            "description": .string("Multiple search keywords (use with match_mode). Example: [\"meeting\", \"project\"]")
                        ]),
                        "match_mode": .object([
                            "type": .string("string"),
                            "enum": .array([.string("any"), .string("all")]),
                            "description": .string("'any' = OR (matches if ANY keyword found, default), 'all' = AND (matches only if ALL keywords found)")
                        ]),
                        "start_date": .object(["type": .string("string"), "description": .string("Optional start date in ISO8601 format with timezone (e.g., 2026-01-01T00:00:00+08:00)")]),
                        "end_date": .object(["type": .string("string"), "description": .string("Optional end date in ISO8601 format with timezone (e.g., 2026-12-31T23:59:59+08:00)")]),
                        "calendar_name": .object(["type": .string("string"), "description": .string("Optional calendar name to filter by")]),
                        "calendar_source": .object(["type": .string("string"), "description": .string("Calendar source (e.g., 'iCloud', 'Google'). Required when multiple calendars share the same name.")])
                    ])
                ]),
                annotations: .init(readOnlyHint: true, openWorldHint: false)
            ),

            // Feature 3: Quick Time Range
            Tool(
                name: "list_events_quick",
                description: "List events with quick time range shortcuts. Supports international week definitions.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "range": .object([
                            "type": .string("string"),
                            "enum": .array([
                                .string("today"), .string("tomorrow"),
                                .string("this_week"), .string("next_week"),
                                .string("this_month"), .string("next_7_days"), .string("next_30_days")
                            ]),
                            "description": .string("Quick time range shortcut")
                        ]),
                        "week_starts_on": .object([
                            "type": .string("string"),
                            "enum": .array([
                                .string("system"), .string("monday"), .string("sunday"), .string("saturday")
                            ]),
                            "description": .string("First day of week for this_week/next_week calculations. 'system' uses locale settings (default), 'monday' for ISO 8601/Europe/Asia, 'sunday' for US/Japan, 'saturday' for Middle East.")
                        ]),
                        "calendar_name": .object(["type": .string("string"), "description": .string("Optional calendar name to filter by")]),
                        "calendar_source": .object(["type": .string("string"), "description": .string("Calendar source (e.g., 'iCloud', 'Google'). Required when multiple calendars share the same name.")])
                    ]),
                    "required": .array([.string("range")])
                ]),
                annotations: .init(readOnlyHint: true, openWorldHint: false)
            ),

            // Feature 4: Batch Create Events
            Tool(
                name: "create_events_batch",
                description: "PREFERRED: Create multiple events in a single call. Use this instead of calling create_event multiple times - it's faster and more reliable. Returns detailed results for each event.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "events": .object([
                            "type": .string("array"),
                            "description": .string("Array of event objects to create"),
                            "items": .object([
                                "type": .string("object"),
                                "properties": .object([
                                    "title": .object(["type": .string("string")]),
                                    "start_time": .object(["type": .string("string")]),
                                    "end_time": .object(["type": .string("string")]),
                                    "notes": .object(["type": .string("string")]),
                                    "location": .object(["type": .string("string")]),
                                    "calendar_name": .object(["type": .string("string"), "description": .string("Target calendar name (required)")]),
                                    "calendar_source": .object(["type": .string("string"), "description": .string("Calendar source (e.g., 'iCloud', 'Google')")]),
                                    "all_day": .object(["type": .string("boolean")])
                                ]),
                                "required": .array([.string("title"), .string("start_time"), .string("end_time"), .string("calendar_name")])
                            ])
                        ])
                    ]),
                    "required": .array([.string("events")])
                ]),
                annotations: .init(readOnlyHint: false, destructiveHint: false, openWorldHint: false)
            ),

            // Feature 5: Conflict Check
            Tool(
                name: "check_conflicts",
                description: "Check for overlapping events in a time range.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "start_time": .object(["type": .string("string"), "description": .string("Start time to check in ISO8601 format with timezone (e.g., 2026-01-30T14:00:00+08:00)")]),
                        "end_time": .object(["type": .string("string"), "description": .string("End time to check in ISO8601 format with timezone (e.g., 2026-01-30T15:00:00+08:00)")]),
                        "calendar_name": .object(["type": .string("string"), "description": .string("Optional calendar name to filter by")]),
                        "calendar_source": .object(["type": .string("string"), "description": .string("Calendar source (e.g., 'iCloud', 'Google'). Required when multiple calendars share the same name.")]),
                        "exclude_event_id": .object(["type": .string("string"), "description": .string("Optional event ID to exclude from check (useful for updates)")])
                    ]),
                    "required": .array([.string("start_time"), .string("end_time")])
                ]),
                annotations: .init(readOnlyHint: true, openWorldHint: false)
            ),

            // Feature 6: Copy Event
            Tool(
                name: "copy_event",
                description: "Copy an event to another calendar. The original event is preserved.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "event_id": .object(["type": .string("string"), "description": .string("The event identifier to copy")]),
                        "target_calendar": .object(["type": .string("string"), "description": .string("Target calendar name to copy to")]),
                        "target_calendar_source": .object(["type": .string("string"), "description": .string("Target calendar source (e.g., 'iCloud', 'Google'). Required when multiple calendars share the same name.")]),
                        "delete_original": .object(["type": .string("boolean"), "description": .string("If true, delete the original event after copying (effectively a move)")])
                    ]),
                    "required": .array([.string("event_id"), .string("target_calendar")])
                ]),
                annotations: .init(readOnlyHint: false, destructiveHint: false, openWorldHint: false)
            ),

            // Feature 7: Move Events Batch
            Tool(
                name: "move_events_batch",
                description: "PREFERRED: Move multiple events to another calendar in a single call. Use this instead of calling copy_event with delete_original multiple times - it's faster and more reliable. Returns detailed success/failure for each event.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "event_ids": .object([
                            "type": .string("array"),
                            "items": .object(["type": .string("string")]),
                            "description": .string("Array of event IDs to move")
                        ]),
                        "target_calendar": .object(["type": .string("string"), "description": .string("Target calendar name to move events to")]),
                        "target_calendar_source": .object(["type": .string("string"), "description": .string("Target calendar source (e.g., 'iCloud', 'Google'). Required when multiple calendars share the same name.")])
                    ]),
                    "required": .array([.string("event_ids"), .string("target_calendar")])
                ]),
                annotations: .init(readOnlyHint: false, destructiveHint: false, openWorldHint: false)
            ),

            // Feature 8: Delete Events Batch
            Tool(
                name: "delete_events_batch",
                description: "PREFERRED: Delete multiple events in a single call. Use this instead of calling delete_event multiple times - it's faster and more reliable. Returns detailed success/failure counts.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "event_ids": .object([
                            "type": .string("array"),
                            "items": .object(["type": .string("string")]),
                            "description": .string("Array of event identifiers to delete")
                        ]),
                        "span": .object([
                            "type": .string("string"),
                            "enum": .array([.string("this"), .string("future")]),
                            "description": .string("For recurring events: 'this' (default) deletes only this occurrence, 'future' deletes this and all future occurrences")
                        ])
                    ]),
                    "required": .array([.string("event_ids")])
                ]),
                annotations: .init(readOnlyHint: false, destructiveHint: true, openWorldHint: false)
            ),

            // Feature 9: Find Duplicate Events
            Tool(
                name: "find_duplicate_events",
                description: "Find duplicate events across calendars. Useful before merging calendars to avoid duplicates. Matches by title (case-insensitive) and time (with configurable tolerance).",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "calendar_names": .object([
                            "type": .string("array"),
                            "items": .object(["type": .string("string")]),
                            "description": .string("Calendar names to check for duplicates. If empty or omitted, checks ALL calendars.")
                        ]),
                        "start_date": .object([
                            "type": .string("string"),
                            "description": .string("Start date in ISO8601 format with timezone (e.g., 2026-01-01T00:00:00+08:00)")
                        ]),
                        "end_date": .object([
                            "type": .string("string"),
                            "description": .string("End date in ISO8601 format with timezone (e.g., 2026-12-31T23:59:59+08:00)")
                        ]),
                        "tolerance_minutes": .object([
                            "type": .string("integer"),
                            "description": .string("Time tolerance in minutes for matching (default: 5). Events within this time difference are considered duplicates.")
                        ])
                    ]),
                    "required": .array([.string("start_date"), .string("end_date")])
                ]),
                annotations: .init(readOnlyHint: true, openWorldHint: false)
            ),
        ]
    }

    // MARK: - Handler Registration

    private func registerHandlers() async {
        // List Tools handler
        await server.withMethodHandler(ListTools.self) { [tools] _ in
            ListTools.Result(tools: tools)
        }

        // Call Tool handler
        await server.withMethodHandler(CallTool.self) { [weak self] params in
            guard let self = self else {
                return CallTool.Result(content: [.text("Server unavailable")], isError: true)
            }
            return await self.handleToolCall(name: params.name, arguments: params.arguments ?? [:])
        }
    }

    // MARK: - Tool Call Handler

    private func handleToolCall(name: String, arguments: [String: Value]) async -> CallTool.Result {
        do {
            let result = try await executeToolCall(name: name, arguments: arguments)
            return CallTool.Result(content: [.text(result)])
        } catch {
            return CallTool.Result(content: [.text("Error: \(error.localizedDescription)")], isError: true)
        }
    }

    private func executeToolCall(name: String, arguments: [String: Value]) async throws -> String {
        switch name {
        // Calendar Tools
        case "list_calendars":
            return try await handleListCalendars(arguments: arguments)
        case "create_calendar":
            return try await handleCreateCalendar(arguments: arguments)
        case "delete_calendar":
            return try await handleDeleteCalendar(arguments: arguments)

        // Event Tools
        case "list_events":
            return try await handleListEvents(arguments: arguments)
        case "create_event":
            return try await handleCreateEvent(arguments: arguments)
        case "update_event":
            return try await handleUpdateEvent(arguments: arguments)
        case "delete_event":
            return try await handleDeleteEvent(arguments: arguments)

        // Reminder Tools
        case "list_reminders":
            return try await handleListReminders(arguments: arguments)
        case "create_reminder":
            return try await handleCreateReminder(arguments: arguments)
        case "update_reminder":
            return try await handleUpdateReminder(arguments: arguments)
        case "complete_reminder":
            return try await handleCompleteReminder(arguments: arguments)
        case "delete_reminder":
            return try await handleDeleteReminder(arguments: arguments)

        // New Feature Tools
        case "search_events":
            return try await handleSearchEvents(arguments: arguments)
        case "list_events_quick":
            return try await handleListEventsQuick(arguments: arguments)
        case "create_events_batch":
            return try await handleCreateEventsBatch(arguments: arguments)
        case "check_conflicts":
            return try await handleCheckConflicts(arguments: arguments)
        case "copy_event":
            return try await handleCopyEvent(arguments: arguments)
        case "move_events_batch":
            return try await handleMoveEventsBatch(arguments: arguments)
        case "delete_events_batch":
            return try await handleDeleteEventsBatch(arguments: arguments)
        case "find_duplicate_events":
            return try await handleFindDuplicateEvents(arguments: arguments)

        default:
            throw ToolError.unknownTool(name)
        }
    }

    // MARK: - Calendar Handlers

    private func handleListCalendars(arguments: [String: Value]) async throws -> String {
        var entityType: EKEntityType?
        if let typeStr = arguments["type"]?.stringValue {
            entityType = typeStr == "event" ? .event : typeStr == "reminder" ? .reminder : nil
        }

        let calendars = try await eventKitManager.listCalendars(for: entityType)
        let result = calendars.map { calendar -> [String: Any] in
            [
                "id": calendar.calendarIdentifier,
                "title": calendar.title,
                "type": calendar.type.rawValue,
                "allowsContentModifications": calendar.allowsContentModifications,
                "isSubscribed": calendar.isSubscribed,
                "source": calendar.source.title
            ]
        }
        return formatJSON(result)
    }

    private func handleCreateCalendar(arguments: [String: Value]) async throws -> String {
        guard let title = arguments["title"]?.stringValue else {
            throw ToolError.invalidParameter("title is required")
        }
        guard let typeStr = arguments["type"]?.stringValue else {
            throw ToolError.invalidParameter("type is required")
        }

        let entityType: EKEntityType = typeStr == "reminder" ? .reminder : .event
        let color = arguments["color"]?.stringValue

        let calendar = try await eventKitManager.createCalendar(
            title: title,
            entityType: entityType,
            color: color
        )

        return "Created calendar: \(calendar.title) (ID: \(calendar.calendarIdentifier))"
    }

    private func handleDeleteCalendar(arguments: [String: Value]) async throws -> String {
        guard let id = arguments["id"]?.stringValue else {
            throw ToolError.invalidParameter("id is required")
        }
        try await eventKitManager.deleteCalendar(identifier: id)
        return "Calendar deleted successfully"
    }

    // MARK: - Event Handlers

    private func handleListEvents(arguments: [String: Value]) async throws -> String {
        guard let startStr = arguments["start_date"]?.stringValue,
              let startDate = dateFormatter.date(from: startStr)
        else {
            throw ToolError.invalidParameter("start_date must be a valid ISO8601 date")
        }
        guard let endStr = arguments["end_date"]?.stringValue,
              let endDate = dateFormatter.date(from: endStr)
        else {
            throw ToolError.invalidParameter("end_date must be a valid ISO8601 date")
        }

        let calendarName = arguments["calendar_name"]?.stringValue
        let calendarSource = arguments["calendar_source"]?.stringValue

        let events = try await eventKitManager.listEvents(
            startDate: startDate,
            endDate: endDate,
            calendarName: calendarName,
            calendarSource: calendarSource
        )

        let result = events.map { event -> [String: Any] in
            var dict: [String: Any] = [
                "id": event.eventIdentifier ?? "",
                "title": event.title ?? "",
                "start_date": dateFormatter.string(from: event.startDate),
                "start_date_local": localDateFormatter.string(from: event.startDate),
                "end_date": dateFormatter.string(from: event.endDate),
                "end_date_local": localDateFormatter.string(from: event.endDate),
                "timezone": TimeZone.current.identifier,
                "is_all_day": event.isAllDay,
                "calendar": event.calendar.title
            ]
            if let notes = event.notes { dict["notes"] = notes }
            if let location = event.location { dict["location"] = location }
            if let url = event.url { dict["url"] = url.absoluteString }
            if event.hasRecurrenceRules { dict["is_recurring"] = true }
            return dict
        }
        return formatJSON(result)
    }

    private func handleCreateEvent(arguments: [String: Value]) async throws -> String {
        guard let title = arguments["title"]?.stringValue else {
            throw ToolError.invalidParameter("title is required")
        }
        guard let startStr = arguments["start_time"]?.stringValue,
              let startDate = dateFormatter.date(from: startStr)
        else {
            throw ToolError.invalidParameter("start_time must be a valid ISO8601 date")
        }
        guard let endStr = arguments["end_time"]?.stringValue,
              let endDate = dateFormatter.date(from: endStr)
        else {
            throw ToolError.invalidParameter("end_time must be a valid ISO8601 date")
        }

        let notes = arguments["notes"]?.stringValue
        let location = arguments["location"]?.stringValue
        let url = arguments["url"]?.stringValue
        let calendarName = arguments["calendar_name"]?.stringValue
        let calendarSource = arguments["calendar_source"]?.stringValue
        let isAllDay = arguments["all_day"]?.boolValue ?? false

        var alarmOffsets: [Int]?
        if let alarmsArray = arguments["alarms_minutes_offsets"]?.arrayValue {
            alarmOffsets = alarmsArray.compactMap { $0.intValue }
        }

        let event = try await eventKitManager.createEvent(
            title: title,
            startDate: startDate,
            endDate: endDate,
            notes: notes,
            location: location,
            url: url,
            calendarName: calendarName,
            calendarSource: calendarSource,
            isAllDay: isAllDay,
            alarmOffsets: alarmOffsets
        )

        return "Created event: \(event.title ?? title) (ID: \(event.eventIdentifier ?? "unknown"))"
    }

    private func handleUpdateEvent(arguments: [String: Value]) async throws -> String {
        guard let eventId = arguments["event_id"]?.stringValue else {
            throw ToolError.invalidParameter("event_id is required")
        }

        let title = arguments["title"]?.stringValue
        let startDate = arguments["start_time"]?.stringValue.flatMap { dateFormatter.date(from: $0) }
        let endDate = arguments["end_time"]?.stringValue.flatMap { dateFormatter.date(from: $0) }
        let notes = arguments["notes"]?.stringValue
        let location = arguments["location"]?.stringValue
        let url = arguments["url"]?.stringValue
        let calendarName = arguments["calendar_name"]?.stringValue
        let calendarSource = arguments["calendar_source"]?.stringValue
        let isAllDay = arguments["all_day"]?.boolValue

        let event = try await eventKitManager.updateEvent(
            identifier: eventId,
            title: title,
            startDate: startDate,
            endDate: endDate,
            notes: notes,
            location: location,
            url: url,
            calendarName: calendarName,
            calendarSource: calendarSource,
            isAllDay: isAllDay
        )

        return "Updated event: \(event.title ?? "")"
    }

    private func handleDeleteEvent(arguments: [String: Value]) async throws -> String {
        guard let eventId = arguments["event_id"]?.stringValue else {
            throw ToolError.invalidParameter("event_id is required")
        }

        let spanStr = arguments["span"]?.stringValue ?? "this"
        let span: EKSpan = spanStr == "future" ? .futureEvents : .thisEvent

        try await eventKitManager.deleteEvent(identifier: eventId, span: span)
        return "Event deleted successfully"
    }

    // MARK: - Reminder Handlers

    private func handleListReminders(arguments: [String: Value]) async throws -> String {
        let completed = arguments["completed"]?.boolValue
        let calendarName = arguments["calendar_name"]?.stringValue
        let calendarSource = arguments["calendar_source"]?.stringValue

        let reminders = try await eventKitManager.listReminders(
            completed: completed,
            calendarName: calendarName,
            calendarSource: calendarSource
        )

        let result = reminders.map { reminder -> [String: Any] in
            var dict: [String: Any] = [
                "id": reminder.calendarItemIdentifier,
                "title": reminder.title ?? "",
                "is_completed": reminder.isCompleted,
                "priority": reminder.priority,
                "calendar": reminder.calendar.title,
                "timezone": TimeZone.current.identifier
            ]
            if let notes = reminder.notes { dict["notes"] = notes }
            if let dueDate = reminder.dueDateComponents?.date {
                dict["due_date"] = dateFormatter.string(from: dueDate)
                dict["due_date_local"] = localDateFormatter.string(from: dueDate)
            }
            if let completionDate = reminder.completionDate {
                dict["completion_date"] = dateFormatter.string(from: completionDate)
                dict["completion_date_local"] = localDateFormatter.string(from: completionDate)
            }
            return dict
        }
        return formatJSON(result)
    }

    private func handleCreateReminder(arguments: [String: Value]) async throws -> String {
        guard let title = arguments["title"]?.stringValue else {
            throw ToolError.invalidParameter("title is required")
        }

        let notes = arguments["notes"]?.stringValue
        let dueDate = arguments["due_date"]?.stringValue.flatMap { dateFormatter.date(from: $0) }
        let priority = arguments["priority"]?.intValue ?? 0
        let calendarName = arguments["calendar_name"]?.stringValue
        let calendarSource = arguments["calendar_source"]?.stringValue

        let reminder = try await eventKitManager.createReminder(
            title: title,
            notes: notes,
            dueDate: dueDate,
            priority: priority,
            calendarName: calendarName,
            calendarSource: calendarSource
        )

        return "Created reminder: \(reminder.title ?? title) (ID: \(reminder.calendarItemIdentifier))"
    }

    private func handleUpdateReminder(arguments: [String: Value]) async throws -> String {
        guard let reminderId = arguments["reminder_id"]?.stringValue else {
            throw ToolError.invalidParameter("reminder_id is required")
        }

        let title = arguments["title"]?.stringValue
        let notes = arguments["notes"]?.stringValue
        let dueDate = arguments["due_date"]?.stringValue.flatMap { dateFormatter.date(from: $0) }
        let priority = arguments["priority"]?.intValue
        let calendarName = arguments["calendar_name"]?.stringValue
        let calendarSource = arguments["calendar_source"]?.stringValue

        let reminder = try await eventKitManager.updateReminder(
            identifier: reminderId,
            title: title,
            notes: notes,
            dueDate: dueDate,
            priority: priority,
            calendarName: calendarName,
            calendarSource: calendarSource
        )

        return "Updated reminder: \(reminder.title ?? "")"
    }

    private func handleCompleteReminder(arguments: [String: Value]) async throws -> String {
        guard let reminderId = arguments["reminder_id"]?.stringValue else {
            throw ToolError.invalidParameter("reminder_id is required")
        }

        let completed = arguments["completed"]?.boolValue ?? true

        let reminder = try await eventKitManager.completeReminder(
            identifier: reminderId,
            completed: completed
        )

        let status = reminder.isCompleted ? "completed" : "incomplete"
        return "Reminder marked as \(status): \(reminder.title ?? "")"
    }

    private func handleDeleteReminder(arguments: [String: Value]) async throws -> String {
        guard let reminderId = arguments["reminder_id"]?.stringValue else {
            throw ToolError.invalidParameter("reminder_id is required")
        }

        try await eventKitManager.deleteReminder(identifier: reminderId)
        return "Reminder deleted successfully"
    }

    // MARK: - New Feature Handlers

    /// Feature 2: Search events by keyword(s)
    private func handleSearchEvents(arguments: [String: Value]) async throws -> String {
        // Support both single keyword and multiple keywords
        var keywords: [String] = []

        if let keywordsArray = arguments["keywords"]?.arrayValue {
            keywords = keywordsArray.compactMap { $0.stringValue }
        } else if let keyword = arguments["keyword"]?.stringValue {
            keywords = [keyword]
        }

        if keywords.isEmpty {
            throw ToolError.invalidParameter("Either 'keyword' or 'keywords' is required")
        }

        let matchMode = arguments["match_mode"]?.stringValue ?? "any"
        let startDate = arguments["start_date"]?.stringValue.flatMap { dateFormatter.date(from: $0) }
        let endDate = arguments["end_date"]?.stringValue.flatMap { dateFormatter.date(from: $0) }
        let calendarName = arguments["calendar_name"]?.stringValue
        let calendarSource = arguments["calendar_source"]?.stringValue

        let events = try await eventKitManager.searchEvents(
            keywords: keywords,
            matchMode: matchMode,
            startDate: startDate,
            endDate: endDate,
            calendarName: calendarName,
            calendarSource: calendarSource
        )

        let result = events.map { event -> [String: Any] in
            var dict: [String: Any] = [
                "id": event.eventIdentifier ?? "",
                "title": event.title ?? "",
                "start_date": dateFormatter.string(from: event.startDate),
                "start_date_local": localDateFormatter.string(from: event.startDate),
                "end_date": dateFormatter.string(from: event.endDate),
                "end_date_local": localDateFormatter.string(from: event.endDate),
                "timezone": TimeZone.current.identifier,
                "is_all_day": event.isAllDay,
                "calendar": event.calendar.title
            ]
            if let notes = event.notes { dict["notes"] = notes }
            if let location = event.location { dict["location"] = location }
            if let url = event.url { dict["url"] = url.absoluteString }
            return dict
        }

        let response: [String: Any] = [
            "keywords": keywords,
            "match_mode": matchMode,
            "result_count": events.count,
            "events": result
        ]
        return formatJSON(response)
    }

    /// Feature 3: List events with quick time range
    private func handleListEventsQuick(arguments: [String: Value]) async throws -> String {
        guard let range = arguments["range"]?.stringValue else {
            throw ToolError.invalidParameter("range is required")
        }

        let weekStartsOn = arguments["week_starts_on"]?.stringValue ?? "system"
        let (startDate, endDate, effectiveWeekStart) = getDateRange(for: range, weekStartsOn: weekStartsOn)
        let calendarName = arguments["calendar_name"]?.stringValue
        let calendarSource = arguments["calendar_source"]?.stringValue

        let events = try await eventKitManager.listEvents(
            startDate: startDate,
            endDate: endDate,
            calendarName: calendarName,
            calendarSource: calendarSource
        )

        let result = events.map { event -> [String: Any] in
            var dict: [String: Any] = [
                "id": event.eventIdentifier ?? "",
                "title": event.title ?? "",
                "start_date": dateFormatter.string(from: event.startDate),
                "start_date_local": localDateFormatter.string(from: event.startDate),
                "end_date": dateFormatter.string(from: event.endDate),
                "end_date_local": localDateFormatter.string(from: event.endDate),
                "timezone": TimeZone.current.identifier,
                "is_all_day": event.isAllDay,
                "calendar": event.calendar.title
            ]
            if let notes = event.notes { dict["notes"] = notes }
            if let location = event.location { dict["location"] = location }
            if let url = event.url { dict["url"] = url.absoluteString }
            if event.hasRecurrenceRules { dict["is_recurring"] = true }
            return dict
        }

        // Include the computed date range in response
        var response: [String: Any] = [
            "range": range,
            "start_date": dateFormatter.string(from: startDate),
            "start_date_local": localDateFormatter.string(from: startDate),
            "end_date": dateFormatter.string(from: endDate),
            "end_date_local": localDateFormatter.string(from: endDate),
            "timezone": TimeZone.current.identifier,
            "events": result
        ]
        // Include week_starts_on info for this_week/next_week ranges
        if range == "this_week" || range == "next_week" {
            response["week_starts_on"] = effectiveWeekStart
        }
        return formatJSON(response)
    }

    /// Feature 4: Create multiple events at once
    private func handleCreateEventsBatch(arguments: [String: Value]) async throws -> String {
        guard let eventsArray = arguments["events"]?.arrayValue else {
            throw ToolError.invalidParameter("events array is required")
        }

        var results: [[String: Any]] = []

        for (index, eventValue) in eventsArray.enumerated() {
            guard let eventDict = eventValue.objectValue else {
                results.append(["index": index, "success": false, "error": "Invalid event format"])
                continue
            }

            guard let title = eventDict["title"]?.stringValue else {
                results.append(["index": index, "success": false, "error": "title is required"])
                continue
            }
            guard let startStr = eventDict["start_time"]?.stringValue,
                  let startDate = dateFormatter.date(from: startStr) else {
                results.append(["index": index, "success": false, "error": "start_time must be a valid ISO8601 date"])
                continue
            }
            guard let endStr = eventDict["end_time"]?.stringValue,
                  let endDate = dateFormatter.date(from: endStr) else {
                results.append(["index": index, "success": false, "error": "end_time must be a valid ISO8601 date"])
                continue
            }

            do {
                let event = try await eventKitManager.createEvent(
                    title: title,
                    startDate: startDate,
                    endDate: endDate,
                    notes: eventDict["notes"]?.stringValue,
                    location: eventDict["location"]?.stringValue,
                    url: nil,
                    calendarName: eventDict["calendar_name"]?.stringValue,
                    calendarSource: eventDict["calendar_source"]?.stringValue,
                    isAllDay: eventDict["all_day"]?.boolValue ?? false,
                    alarmOffsets: nil,
                    recurrenceRule: nil
                )
                results.append([
                    "index": index,
                    "success": true,
                    "event_id": event.eventIdentifier ?? "",
                    "title": event.title ?? title
                ])
            } catch {
                results.append([
                    "index": index,
                    "success": false,
                    "error": error.localizedDescription
                ])
            }
        }

        let successCount = results.filter { ($0["success"] as? Bool) == true }.count
        let response: [String: Any] = [
            "total": eventsArray.count,
            "succeeded": successCount,
            "failed": eventsArray.count - successCount,
            "results": results
        ]
        return formatJSON(response)
    }

    /// Feature 5: Check for conflicting events
    private func handleCheckConflicts(arguments: [String: Value]) async throws -> String {
        guard let startStr = arguments["start_time"]?.stringValue,
              let startDate = dateFormatter.date(from: startStr)
        else {
            throw ToolError.invalidParameter("start_time must be a valid ISO8601 date")
        }
        guard let endStr = arguments["end_time"]?.stringValue,
              let endDate = dateFormatter.date(from: endStr)
        else {
            throw ToolError.invalidParameter("end_time must be a valid ISO8601 date")
        }

        let calendarName = arguments["calendar_name"]?.stringValue
        let calendarSource = arguments["calendar_source"]?.stringValue
        let excludeEventId = arguments["exclude_event_id"]?.stringValue

        let conflicts = try await eventKitManager.checkConflicts(
            startDate: startDate,
            endDate: endDate,
            calendarName: calendarName,
            calendarSource: calendarSource,
            excludeEventId: excludeEventId
        )

        let result = conflicts.map { event -> [String: Any] in
            var dict: [String: Any] = [
                "id": event.eventIdentifier ?? "",
                "title": event.title ?? "",
                "start_date": dateFormatter.string(from: event.startDate),
                "start_date_local": localDateFormatter.string(from: event.startDate),
                "end_date": dateFormatter.string(from: event.endDate),
                "end_date_local": localDateFormatter.string(from: event.endDate),
                "timezone": TimeZone.current.identifier,
                "calendar": event.calendar.title
            ]
            if let location = event.location { dict["location"] = location }
            return dict
        }

        let response: [String: Any] = [
            "has_conflicts": !conflicts.isEmpty,
            "conflict_count": conflicts.count,
            "check_range": [
                "start": dateFormatter.string(from: startDate),
                "start_local": localDateFormatter.string(from: startDate),
                "end": dateFormatter.string(from: endDate),
                "end_local": localDateFormatter.string(from: endDate)
            ],
            "conflicts": result
        ]
        return formatJSON(response)
    }

    /// Feature 6: Copy event to another calendar
    private func handleCopyEvent(arguments: [String: Value]) async throws -> String {
        guard let eventId = arguments["event_id"]?.stringValue else {
            throw ToolError.invalidParameter("event_id is required")
        }
        guard let targetCalendar = arguments["target_calendar"]?.stringValue else {
            throw ToolError.invalidParameter("target_calendar is required")
        }

        let targetCalendarSource = arguments["target_calendar_source"]?.stringValue
        let deleteOriginal = arguments["delete_original"]?.boolValue ?? false

        let newEvent = try await eventKitManager.copyEvent(
            identifier: eventId,
            toCalendarName: targetCalendar,
            toCalendarSource: targetCalendarSource,
            deleteOriginal: deleteOriginal
        )

        let action = deleteOriginal ? "Moved" : "Copied"
        return "\(action) event '\(newEvent.title ?? "")' to calendar '\(targetCalendar)' (New ID: \(newEvent.eventIdentifier ?? "unknown"))"
    }

    /// Feature 7: Move multiple events to another calendar
    private func handleMoveEventsBatch(arguments: [String: Value]) async throws -> String {
        guard let eventIds = arguments["event_ids"]?.arrayValue else {
            throw ToolError.invalidParameter("event_ids array is required")
        }
        guard let targetCalendar = arguments["target_calendar"]?.stringValue else {
            throw ToolError.invalidParameter("target_calendar is required")
        }

        let targetCalendarSource = arguments["target_calendar_source"]?.stringValue
        let ids = eventIds.compactMap { $0.stringValue }
        if ids.isEmpty {
            throw ToolError.invalidParameter("event_ids must contain at least one event ID")
        }

        var results: [[String: Any]] = []

        for eventId in ids {
            do {
                let event = try await eventKitManager.copyEvent(
                    identifier: eventId,
                    toCalendarName: targetCalendar,
                    toCalendarSource: targetCalendarSource,
                    deleteOriginal: true  // Move = copy + delete original
                )
                results.append([
                    "event_id": eventId,
                    "success": true,
                    "new_event_id": event.eventIdentifier ?? "",
                    "title": event.title ?? ""
                ])
            } catch {
                results.append([
                    "event_id": eventId,
                    "success": false,
                    "error": error.localizedDescription
                ])
            }
        }

        let successCount = results.filter { ($0["success"] as? Bool) == true }.count
        let response: [String: Any] = [
            "total": ids.count,
            "succeeded": successCount,
            "failed": ids.count - successCount,
            "target_calendar": targetCalendar,
            "results": results
        ]
        return formatJSON(response)
    }

    /// Feature 8: Delete multiple events at once
    private func handleDeleteEventsBatch(arguments: [String: Value]) async throws -> String {
        guard let eventIdsArray = arguments["event_ids"]?.arrayValue else {
            throw ToolError.invalidParameter("event_ids array is required")
        }

        let eventIds = eventIdsArray.compactMap { $0.stringValue }
        if eventIds.isEmpty {
            throw ToolError.invalidParameter("event_ids must contain at least one event ID")
        }

        let spanStr = arguments["span"]?.stringValue ?? "this"
        let span: EKSpan = spanStr == "future" ? .futureEvents : .thisEvent

        let result = try await eventKitManager.deleteEventsBatch(
            identifiers: eventIds,
            span: span
        )

        var response: [String: Any] = [
            "total": eventIds.count,
            "succeeded": result.successCount,
            "failed": result.failedCount,
            "span": spanStr
        ]

        if !result.failures.isEmpty {
            response["failures"] = result.failures.map { failure -> [String: String] in
                ["event_id": failure.identifier, "error": failure.error]
            }
        }

        return formatJSON(response)
    }

    /// Feature 9: Find duplicate events across calendars
    private func handleFindDuplicateEvents(arguments: [String: Value]) async throws -> String {
        guard let startStr = arguments["start_date"]?.stringValue,
              let startDate = dateFormatter.date(from: startStr)
        else {
            throw ToolError.invalidParameter("start_date must be a valid ISO8601 date")
        }
        guard let endStr = arguments["end_date"]?.stringValue,
              let endDate = dateFormatter.date(from: endStr)
        else {
            throw ToolError.invalidParameter("end_date must be a valid ISO8601 date")
        }

        var calendarNames: [String]?
        if let namesArray = arguments["calendar_names"]?.arrayValue {
            calendarNames = namesArray.compactMap { $0.stringValue }
            if calendarNames?.isEmpty == true {
                calendarNames = nil
            }
        }

        let toleranceMinutes = arguments["tolerance_minutes"]?.intValue ?? 5

        let duplicates = try await eventKitManager.findDuplicateEvents(
            calendarNames: calendarNames,
            startDate: startDate,
            endDate: endDate,
            toleranceMinutes: toleranceMinutes
        )

        let result = duplicates.map { pair -> [String: Any] in
            [
                "event1": [
                    "id": pair.event1Id,
                    "title": pair.event1Title,
                    "calendar": pair.event1Calendar,
                    "start_date": dateFormatter.string(from: pair.event1StartDate),
                    "start_date_local": localDateFormatter.string(from: pair.event1StartDate)
                ],
                "event2": [
                    "id": pair.event2Id,
                    "title": pair.event2Title,
                    "calendar": pair.event2Calendar,
                    "start_date": dateFormatter.string(from: pair.event2StartDate),
                    "start_date_local": localDateFormatter.string(from: pair.event2StartDate)
                ],
                "time_difference_seconds": pair.timeDifferenceSeconds
            ]
        }

        let response: [String: Any] = [
            "search_range": [
                "start": dateFormatter.string(from: startDate),
                "start_local": localDateFormatter.string(from: startDate),
                "end": dateFormatter.string(from: endDate),
                "end_local": localDateFormatter.string(from: endDate)
            ],
            "calendars_checked": calendarNames ?? ["all calendars"],
            "tolerance_minutes": toleranceMinutes,
            "duplicate_count": duplicates.count,
            "duplicates": result
        ]
        return formatJSON(response)
    }

    // MARK: - Helpers

    /// Get date range for quick time shortcuts
    /// - Parameters:
    ///   - shortcut: The time range shortcut (today, this_week, etc.)
    ///   - weekStartsOn: First day of week setting ("system", "monday", "sunday", "saturday")
    /// - Returns: Tuple of (start date, end date, effective week start day name)
    private func getDateRange(for shortcut: String, weekStartsOn: String = "system") -> (start: Date, end: Date, effectiveWeekStart: String) {
        var calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        // Determine effective first weekday
        let effectiveWeekStart: String
        switch weekStartsOn {
        case "monday":
            calendar.firstWeekday = 2
            effectiveWeekStart = "monday"
        case "sunday":
            calendar.firstWeekday = 1
            effectiveWeekStart = "sunday"
        case "saturday":
            calendar.firstWeekday = 7
            effectiveWeekStart = "saturday"
        default: // "system"
            // Keep system default (Calendar.current.firstWeekday)
            switch calendar.firstWeekday {
            case 1: effectiveWeekStart = "sunday"
            case 2: effectiveWeekStart = "monday"
            case 7: effectiveWeekStart = "saturday"
            default: effectiveWeekStart = "day_\(calendar.firstWeekday)"
            }
        }

        switch shortcut {
        case "today":
            return (startOfToday, calendar.date(byAdding: .day, value: 1, to: startOfToday)!, effectiveWeekStart)
        case "tomorrow":
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
            return (tomorrow, calendar.date(byAdding: .day, value: 1, to: tomorrow)!, effectiveWeekStart)
        case "this_week":
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            return (weekStart, calendar.date(byAdding: .day, value: 7, to: weekStart)!, effectiveWeekStart)
        case "next_week":
            let thisWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            let nextWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: thisWeekStart)!
            return (nextWeekStart, calendar.date(byAdding: .day, value: 7, to: nextWeekStart)!, effectiveWeekStart)
        case "this_month":
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            return (monthStart, calendar.date(byAdding: .month, value: 1, to: monthStart)!, effectiveWeekStart)
        case "next_7_days":
            return (startOfToday, calendar.date(byAdding: .day, value: 7, to: startOfToday)!, effectiveWeekStart)
        case "next_30_days":
            return (startOfToday, calendar.date(byAdding: .day, value: 30, to: startOfToday)!, effectiveWeekStart)
        default:
            // Default to today
            return (startOfToday, calendar.date(byAdding: .day, value: 1, to: startOfToday)!, effectiveWeekStart)
        }
    }

    private func formatJSON(_ value: Any) -> String {
        do {
            let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
            return String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            return "[]"
        }
    }
}

// MARK: - Tool Error

enum ToolError: LocalizedError {
    case invalidParameter(_ message: String)
    case unknownTool(_ name: String)

    var errorDescription: String? {
        switch self {
        case .invalidParameter(let message):
            return "Invalid parameter: \(message)"
        case .unknownTool(let name):
            return "Unknown tool: \(name)"
        }
    }
}
