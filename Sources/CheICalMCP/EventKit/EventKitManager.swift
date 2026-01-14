import EventKit
import Foundation

/// EventKit wrapper for Calendar and Reminders operations
actor EventKitManager {
    private let eventStore = EKEventStore()
    private var hasCalendarAccess = false
    private var hasReminderAccess = false

    static let shared = EventKitManager()

    private init() {}

    // MARK: - Access Request

    func requestCalendarAccess() async throws {
        if hasCalendarAccess { return }

        if #available(macOS 14.0, *) {
            let granted = try await eventStore.requestFullAccessToEvents()
            hasCalendarAccess = granted
            if !granted {
                throw EventKitError.accessDenied(type: "Calendar")
            }
        } else {
            let granted = try await eventStore.requestAccess(to: .event)
            hasCalendarAccess = granted
            if !granted {
                throw EventKitError.accessDenied(type: "Calendar")
            }
        }
    }

    func requestReminderAccess() async throws {
        if hasReminderAccess { return }

        if #available(macOS 14.0, *) {
            let granted = try await eventStore.requestFullAccessToReminders()
            hasReminderAccess = granted
            if !granted {
                throw EventKitError.accessDenied(type: "Reminders")
            }
        } else {
            let granted = try await eventStore.requestAccess(to: .reminder)
            hasReminderAccess = granted
            if !granted {
                throw EventKitError.accessDenied(type: "Reminders")
            }
        }
    }

    // MARK: - Calendars

    func listCalendars(for entityType: EKEntityType? = nil) async throws -> [EKCalendar] {
        if entityType == .event || entityType == nil {
            try await requestCalendarAccess()
        }
        if entityType == .reminder || entityType == nil {
            try await requestReminderAccess()
        }

        if let type = entityType {
            return eventStore.calendars(for: type)
        } else {
            let eventCalendars = eventStore.calendars(for: .event)
            let reminderCalendars = eventStore.calendars(for: .reminder)
            return eventCalendars + reminderCalendars
        }
    }

    func createCalendar(title: String, entityType: EKEntityType, color: String? = nil) async throws -> EKCalendar {
        if entityType == .event {
            try await requestCalendarAccess()
        } else {
            try await requestReminderAccess()
        }

        let calendar = EKCalendar(for: entityType, eventStore: eventStore)
        calendar.title = title

        // Set source (use default source)
        if entityType == .event {
            calendar.source = eventStore.defaultCalendarForNewEvents?.source
        } else {
            calendar.source = eventStore.defaultCalendarForNewReminders()?.source
        }

        // Set color if provided
        if let colorHex = color {
            calendar.cgColor = parseColor(colorHex)
        }

        try eventStore.saveCalendar(calendar, commit: true)
        return calendar
    }

    func deleteCalendar(identifier: String) async throws {
        try await requestCalendarAccess()
        try await requestReminderAccess()

        guard let calendar = eventStore.calendar(withIdentifier: identifier) else {
            throw EventKitError.calendarNotFound(identifier: identifier)
        }

        try eventStore.removeCalendar(calendar, commit: true)
    }

    // MARK: - Events

    func listEvents(startDate: Date, endDate: Date, calendarName: String? = nil) async throws -> [EKEvent] {
        try await requestCalendarAccess()

        var calendars: [EKCalendar]?
        if let name = calendarName {
            let allCalendars = eventStore.calendars(for: .event)
            calendars = allCalendars.filter { $0.title == name }
            if calendars?.isEmpty == true {
                throw EventKitError.calendarNotFound(identifier: name)
            }
        }

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        return eventStore.events(matching: predicate)
    }

    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        notes: String? = nil,
        location: String? = nil,
        url: String? = nil,
        calendarName: String? = nil,
        isAllDay: Bool = false,
        alarmOffsets: [Int]? = nil,
        recurrenceRule: RecurrenceRuleInput? = nil
    ) async throws -> EKEvent {
        try await requestCalendarAccess()

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.notes = notes
        event.location = location
        event.isAllDay = isAllDay

        if let urlString = url, let eventURL = URL(string: urlString) {
            event.url = eventURL
        }

        // Set calendar
        if let name = calendarName {
            let calendars = eventStore.calendars(for: .event).filter { $0.title == name }
            if let calendar = calendars.first {
                event.calendar = calendar
            } else {
                throw EventKitError.calendarNotFound(identifier: name)
            }
        } else {
            event.calendar = eventStore.defaultCalendarForNewEvents
        }

        // Add alarms
        if let offsets = alarmOffsets {
            for offset in offsets {
                let alarm = EKAlarm(relativeOffset: TimeInterval(-offset * 60))
                event.addAlarm(alarm)
            }
        }

        // Add recurrence rule
        if let rule = recurrenceRule {
            event.recurrenceRules = [createRecurrenceRule(from: rule)]
        }

        try eventStore.save(event, span: .thisEvent)
        return event
    }

    func updateEvent(
        identifier: String,
        title: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        notes: String? = nil,
        location: String? = nil,
        url: String? = nil,
        calendarName: String? = nil,
        isAllDay: Bool? = nil,
        alarmOffsets: [Int]? = nil,
        recurrenceRule: RecurrenceRuleInput? = nil
    ) async throws -> EKEvent {
        try await requestCalendarAccess()

        guard let event = eventStore.event(withIdentifier: identifier) else {
            throw EventKitError.eventNotFound(identifier: identifier)
        }

        if let t = title { event.title = t }
        if let s = startDate { event.startDate = s }
        if let e = endDate { event.endDate = e }
        if let n = notes { event.notes = n }
        if let l = location { event.location = l }
        if let a = isAllDay { event.isAllDay = a }

        if let urlString = url, let eventURL = URL(string: urlString) {
            event.url = eventURL
        }

        if let name = calendarName {
            let calendars = eventStore.calendars(for: .event).filter { $0.title == name }
            if let calendar = calendars.first {
                event.calendar = calendar
            }
        }

        // Update alarms
        if let offsets = alarmOffsets {
            // Remove existing alarms
            if let existingAlarms = event.alarms {
                for alarm in existingAlarms {
                    event.removeAlarm(alarm)
                }
            }
            // Add new alarms
            for offset in offsets {
                let alarm = EKAlarm(relativeOffset: TimeInterval(-offset * 60))
                event.addAlarm(alarm)
            }
        }

        // Update recurrence rule
        if let rule = recurrenceRule {
            event.recurrenceRules = [createRecurrenceRule(from: rule)]
        }

        try eventStore.save(event, span: .thisEvent)
        return event
    }

    func deleteEvent(identifier: String, span: EKSpan = .thisEvent) async throws {
        try await requestCalendarAccess()

        guard let event = eventStore.event(withIdentifier: identifier) else {
            throw EventKitError.eventNotFound(identifier: identifier)
        }

        try eventStore.remove(event, span: span)
    }

    // MARK: - Search and Conflict Detection

    /// Search events by keyword in title, notes, or location
    func searchEvents(
        keyword: String,
        startDate: Date? = nil,
        endDate: Date? = nil,
        calendarName: String? = nil
    ) async throws -> [EKEvent] {
        try await requestCalendarAccess()

        // Default to a wide date range if not specified
        let searchStart = startDate ?? Date.distantPast
        let searchEnd = endDate ?? Date.distantFuture

        var calendars: [EKCalendar]?
        if let name = calendarName {
            let allCalendars = eventStore.calendars(for: .event)
            calendars = allCalendars.filter { $0.title == name }
            if calendars?.isEmpty == true {
                throw EventKitError.calendarNotFound(identifier: name)
            }
        }

        let predicate = eventStore.predicateForEvents(withStart: searchStart, end: searchEnd, calendars: calendars)
        let allEvents = eventStore.events(matching: predicate)

        // Filter by keyword (case-insensitive)
        let lowercasedKeyword = keyword.lowercased()
        return allEvents.filter { event in
            if let title = event.title?.lowercased(), title.contains(lowercasedKeyword) {
                return true
            }
            if let notes = event.notes?.lowercased(), notes.contains(lowercasedKeyword) {
                return true
            }
            if let location = event.location?.lowercased(), location.contains(lowercasedKeyword) {
                return true
            }
            return false
        }
    }

    /// Check for events that overlap with the given time range
    func checkConflicts(
        startDate: Date,
        endDate: Date,
        calendarName: String? = nil,
        excludeEventId: String? = nil
    ) async throws -> [EKEvent] {
        try await requestCalendarAccess()

        var calendars: [EKCalendar]?
        if let name = calendarName {
            let allCalendars = eventStore.calendars(for: .event)
            calendars = allCalendars.filter { $0.title == name }
            if calendars?.isEmpty == true {
                throw EventKitError.calendarNotFound(identifier: name)
            }
        }

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        let events = eventStore.events(matching: predicate)

        // Filter out excluded event and check for actual overlap
        return events.filter { event in
            // Exclude the specified event (useful when checking before updating)
            if let excludeId = excludeEventId, event.eventIdentifier == excludeId {
                return false
            }
            // Check for time overlap (event must actually overlap with the range)
            return event.startDate < endDate && event.endDate > startDate
        }
    }

    // MARK: - Reminders

    func listReminders(completed: Bool? = nil, calendarName: String? = nil) async throws -> [EKReminder] {
        try await requestReminderAccess()

        var calendars: [EKCalendar]?
        if let name = calendarName {
            let allCalendars = eventStore.calendars(for: .reminder)
            calendars = allCalendars.filter { $0.title == name }
            if calendars?.isEmpty == true {
                throw EventKitError.calendarNotFound(identifier: name)
            }
        }

        let predicate: NSPredicate
        if let isCompleted = completed {
            if isCompleted {
                predicate = eventStore.predicateForCompletedReminders(
                    withCompletionDateStarting: nil,
                    ending: nil,
                    calendars: calendars
                )
            } else {
                predicate = eventStore.predicateForIncompleteReminders(
                    withDueDateStarting: nil,
                    ending: nil,
                    calendars: calendars
                )
            }
        } else {
            predicate = eventStore.predicateForReminders(in: calendars)
        }

        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                if let reminders = reminders {
                    continuation.resume(returning: reminders)
                } else {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    func createReminder(
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        priority: Int = 0,
        calendarName: String? = nil,
        alarmOffsets: [Int]? = nil,
        recurrenceRule: RecurrenceRuleInput? = nil
    ) async throws -> EKReminder {
        try await requestReminderAccess()

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = notes
        reminder.priority = priority

        if let due = dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: due
            )
        }

        // Set calendar
        if let name = calendarName {
            let calendars = eventStore.calendars(for: .reminder).filter { $0.title == name }
            if let calendar = calendars.first {
                reminder.calendar = calendar
            } else {
                throw EventKitError.calendarNotFound(identifier: name)
            }
        } else {
            reminder.calendar = eventStore.defaultCalendarForNewReminders()
        }

        // Add alarms
        if let offsets = alarmOffsets {
            for offset in offsets {
                let alarm = EKAlarm(relativeOffset: TimeInterval(-offset * 60))
                reminder.addAlarm(alarm)
            }
        }

        // Add recurrence rule
        if let rule = recurrenceRule {
            reminder.recurrenceRules = [createRecurrenceRule(from: rule)]
        }

        try eventStore.save(reminder, commit: true)
        return reminder
    }

    func updateReminder(
        identifier: String,
        title: String? = nil,
        notes: String? = nil,
        dueDate: Date? = nil,
        priority: Int? = nil,
        calendarName: String? = nil,
        alarmOffsets: [Int]? = nil
    ) async throws -> EKReminder {
        try await requestReminderAccess()

        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
            throw EventKitError.reminderNotFound(identifier: identifier)
        }

        if let t = title { reminder.title = t }
        if let n = notes { reminder.notes = n }
        if let p = priority { reminder.priority = p }

        if let due = dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: due
            )
        }

        if let name = calendarName {
            let calendars = eventStore.calendars(for: .reminder).filter { $0.title == name }
            if let calendar = calendars.first {
                reminder.calendar = calendar
            }
        }

        // Update alarms
        if let offsets = alarmOffsets {
            if let existingAlarms = reminder.alarms {
                for alarm in existingAlarms {
                    reminder.removeAlarm(alarm)
                }
            }
            for offset in offsets {
                let alarm = EKAlarm(relativeOffset: TimeInterval(-offset * 60))
                reminder.addAlarm(alarm)
            }
        }

        try eventStore.save(reminder, commit: true)
        return reminder
    }

    func completeReminder(identifier: String, completed: Bool = true) async throws -> EKReminder {
        try await requestReminderAccess()

        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
            throw EventKitError.reminderNotFound(identifier: identifier)
        }

        reminder.isCompleted = completed
        if completed {
            reminder.completionDate = Date()
        } else {
            reminder.completionDate = nil
        }

        try eventStore.save(reminder, commit: true)
        return reminder
    }

    func deleteReminder(identifier: String) async throws {
        try await requestReminderAccess()

        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
            throw EventKitError.reminderNotFound(identifier: identifier)
        }

        try eventStore.remove(reminder, commit: true)
    }

    // MARK: - Helpers

    private func createRecurrenceRule(from input: RecurrenceRuleInput) -> EKRecurrenceRule {
        let frequency: EKRecurrenceFrequency
        switch input.frequency {
        case .daily: frequency = .daily
        case .weekly: frequency = .weekly
        case .monthly: frequency = .monthly
        case .yearly: frequency = .yearly
        }

        var daysOfWeek: [EKRecurrenceDayOfWeek]?
        if let days = input.daysOfWeek {
            daysOfWeek = days.map { EKRecurrenceDayOfWeek(EKWeekday(rawValue: $0)!) }
        }

        var end: EKRecurrenceEnd?
        if let endDate = input.endDate {
            end = EKRecurrenceEnd(end: endDate)
        } else if let count = input.occurrenceCount {
            end = EKRecurrenceEnd(occurrenceCount: count)
        }

        return EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: input.interval,
            daysOfTheWeek: daysOfWeek,
            daysOfTheMonth: input.daysOfMonth?.map { NSNumber(value: $0) },
            monthsOfTheYear: nil,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: end
        )
    }

    private func parseColor(_ hex: String) -> CGColor {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        return CGColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}

// MARK: - Input Types

struct RecurrenceRuleInput {
    enum Frequency {
        case daily, weekly, monthly, yearly
    }

    let frequency: Frequency
    let interval: Int
    let endDate: Date?
    let occurrenceCount: Int?
    let daysOfWeek: [Int]?
    let daysOfMonth: [Int]?
}

// MARK: - Errors

enum EventKitError: LocalizedError {
    case accessDenied(type: String)
    case calendarNotFound(identifier: String)
    case eventNotFound(identifier: String)
    case reminderNotFound(identifier: String)

    var errorDescription: String? {
        switch self {
        case .accessDenied(let type):
            return "\(type) access denied. Please grant permission in System Settings > Privacy & Security > \(type)"
        case .calendarNotFound(let id):
            return "Calendar not found: \(id)"
        case .eventNotFound(let id):
            return "Event not found: \(id)"
        case .reminderNotFound(let id):
            return "Reminder not found: \(id)"
        }
    }
}
