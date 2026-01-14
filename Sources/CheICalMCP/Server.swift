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
            name: "che-ical-mcp",
            version: "0.2.0",
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
                ])
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
                ])
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
                ])
            ),

            // Event Tools
            Tool(
                name: "list_events",
                description: "List calendar events in a date range. Use ISO8601 format for dates.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "start_date": .object([
                            "type": .string("string"),
                            "description": .string("Start date in ISO8601 format (YYYY-MM-DDTHH:MM:SS)")
                        ]),
                        "end_date": .object([
                            "type": .string("string"),
                            "description": .string("End date in ISO8601 format (YYYY-MM-DDTHH:MM:SS)")
                        ]),
                        "calendar_name": .object([
                            "type": .string("string"),
                            "description": .string("Optional calendar name to filter by")
                        ])
                    ]),
                    "required": .array([.string("start_date"), .string("end_date")])
                ])
            ),
            Tool(
                name: "create_event",
                description: "Create a new calendar event with optional reminders and recurrence.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "title": .object(["type": .string("string"), "description": .string("Event title")]),
                        "start_time": .object(["type": .string("string"), "description": .string("Start time in ISO8601 format")]),
                        "end_time": .object(["type": .string("string"), "description": .string("End time in ISO8601 format")]),
                        "notes": .object(["type": .string("string"), "description": .string("Optional event notes")]),
                        "location": .object(["type": .string("string"), "description": .string("Optional event location")]),
                        "url": .object(["type": .string("string"), "description": .string("Optional event URL")]),
                        "calendar_name": .object(["type": .string("string"), "description": .string("Optional calendar name")]),
                        "all_day": .object(["type": .string("boolean"), "description": .string("Whether this is an all-day event")]),
                        "alarms_minutes_offsets": .object([
                            "type": .string("array"),
                            "items": .object(["type": .string("integer")]),
                            "description": .string("List of minutes before the event to trigger reminders")
                        ])
                    ]),
                    "required": .array([.string("title"), .string("start_time"), .string("end_time")])
                ])
            ),
            Tool(
                name: "update_event",
                description: "Update an existing calendar event.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "event_id": .object(["type": .string("string"), "description": .string("The event identifier")]),
                        "title": .object(["type": .string("string"), "description": .string("New title")]),
                        "start_time": .object(["type": .string("string"), "description": .string("New start time")]),
                        "end_time": .object(["type": .string("string"), "description": .string("New end time")]),
                        "notes": .object(["type": .string("string"), "description": .string("New notes")]),
                        "location": .object(["type": .string("string"), "description": .string("New location")])
                    ]),
                    "required": .array([.string("event_id")])
                ])
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
                ])
            ),

            // Reminder Tools
            Tool(
                name: "list_reminders",
                description: "List reminders from the Reminders app.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "completed": .object(["type": .string("boolean"), "description": .string("Filter: true=completed, false=incomplete, omit=all")]),
                        "calendar_name": .object(["type": .string("string"), "description": .string("Optional reminder list name")])
                    ])
                ])
            ),
            Tool(
                name: "create_reminder",
                description: "Create a new reminder.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "title": .object(["type": .string("string"), "description": .string("Reminder title")]),
                        "notes": .object(["type": .string("string"), "description": .string("Optional notes")]),
                        "due_date": .object(["type": .string("string"), "description": .string("Optional due date in ISO8601 format")]),
                        "priority": .object(["type": .string("integer"), "description": .string("Priority: 0=none, 1=high, 5=medium, 9=low")]),
                        "calendar_name": .object(["type": .string("string"), "description": .string("Optional reminder list name")])
                    ]),
                    "required": .array([.string("title")])
                ])
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
                        "priority": .object(["type": .string("integer"), "description": .string("New priority")])
                    ]),
                    "required": .array([.string("reminder_id")])
                ])
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
                ])
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
                ])
            ),

            // New Feature Tools

            // Feature 2: Search Events
            Tool(
                name: "search_events",
                description: "Search events by keyword in title, notes, or location.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "keyword": .object(["type": .string("string"), "description": .string("Search keyword (case-insensitive)")]),
                        "start_date": .object(["type": .string("string"), "description": .string("Optional start date in ISO8601 format")]),
                        "end_date": .object(["type": .string("string"), "description": .string("Optional end date in ISO8601 format")]),
                        "calendar_name": .object(["type": .string("string"), "description": .string("Optional calendar name to filter by")])
                    ]),
                    "required": .array([.string("keyword")])
                ])
            ),

            // Feature 3: Quick Time Range
            Tool(
                name: "list_events_quick",
                description: "List events with quick time range shortcuts.",
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
                        "calendar_name": .object(["type": .string("string"), "description": .string("Optional calendar name to filter by")])
                    ]),
                    "required": .array([.string("range")])
                ])
            ),

            // Feature 4: Batch Create Events
            Tool(
                name: "create_events_batch",
                description: "Create multiple events at once. Returns results for each event.",
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
                                    "calendar_name": .object(["type": .string("string")]),
                                    "all_day": .object(["type": .string("boolean")])
                                ]),
                                "required": .array([.string("title"), .string("start_time"), .string("end_time")])
                            ])
                        ])
                    ]),
                    "required": .array([.string("events")])
                ])
            ),

            // Feature 5: Conflict Check
            Tool(
                name: "check_conflicts",
                description: "Check for overlapping events in a time range.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "start_time": .object(["type": .string("string"), "description": .string("Start time to check in ISO8601 format")]),
                        "end_time": .object(["type": .string("string"), "description": .string("End time to check in ISO8601 format")]),
                        "calendar_name": .object(["type": .string("string"), "description": .string("Optional calendar name to filter by")]),
                        "exclude_event_id": .object(["type": .string("string"), "description": .string("Optional event ID to exclude from check (useful for updates)")])
                    ]),
                    "required": .array([.string("start_time"), .string("end_time")])
                ])
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

        let events = try await eventKitManager.listEvents(
            startDate: startDate,
            endDate: endDate,
            calendarName: calendarName
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

        let reminders = try await eventKitManager.listReminders(
            completed: completed,
            calendarName: calendarName
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

        let reminder = try await eventKitManager.createReminder(
            title: title,
            notes: notes,
            dueDate: dueDate,
            priority: priority,
            calendarName: calendarName
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

        let reminder = try await eventKitManager.updateReminder(
            identifier: reminderId,
            title: title,
            notes: notes,
            dueDate: dueDate,
            priority: priority,
            calendarName: calendarName
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

    /// Feature 2: Search events by keyword
    private func handleSearchEvents(arguments: [String: Value]) async throws -> String {
        guard let keyword = arguments["keyword"]?.stringValue else {
            throw ToolError.invalidParameter("keyword is required")
        }

        let startDate = arguments["start_date"]?.stringValue.flatMap { dateFormatter.date(from: $0) }
        let endDate = arguments["end_date"]?.stringValue.flatMap { dateFormatter.date(from: $0) }
        let calendarName = arguments["calendar_name"]?.stringValue

        let events = try await eventKitManager.searchEvents(
            keyword: keyword,
            startDate: startDate,
            endDate: endDate,
            calendarName: calendarName
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
        return formatJSON(result)
    }

    /// Feature 3: List events with quick time range
    private func handleListEventsQuick(arguments: [String: Value]) async throws -> String {
        guard let range = arguments["range"]?.stringValue else {
            throw ToolError.invalidParameter("range is required")
        }

        let (startDate, endDate) = getDateRange(for: range)
        let calendarName = arguments["calendar_name"]?.stringValue

        let events = try await eventKitManager.listEvents(
            startDate: startDate,
            endDate: endDate,
            calendarName: calendarName
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
        let response: [String: Any] = [
            "range": range,
            "start_date": dateFormatter.string(from: startDate),
            "start_date_local": localDateFormatter.string(from: startDate),
            "end_date": dateFormatter.string(from: endDate),
            "end_date_local": localDateFormatter.string(from: endDate),
            "timezone": TimeZone.current.identifier,
            "events": result
        ]
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
        let excludeEventId = arguments["exclude_event_id"]?.stringValue

        let conflicts = try await eventKitManager.checkConflicts(
            startDate: startDate,
            endDate: endDate,
            calendarName: calendarName,
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

    // MARK: - Helpers

    /// Get date range for quick time shortcuts
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
            let thisWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            let nextWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: thisWeekStart)!
            return (nextWeekStart, calendar.date(byAdding: .day, value: 7, to: nextWeekStart)!)
        case "this_month":
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            return (monthStart, calendar.date(byAdding: .month, value: 1, to: monthStart)!)
        case "next_7_days":
            return (startOfToday, calendar.date(byAdding: .day, value: 7, to: startOfToday)!)
        case "next_30_days":
            return (startOfToday, calendar.date(byAdding: .day, value: 30, to: startOfToday)!)
        default:
            // Default to today
            return (startOfToday, calendar.date(byAdding: .day, value: 1, to: startOfToday)!)
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
