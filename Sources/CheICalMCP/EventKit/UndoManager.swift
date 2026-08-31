import EventKit
import Foundation

// MARK: - Snapshots

/// #191 — VALUE snapshot of an EKRecurrenceRule. The previous design stored the
/// raw EKRecurrenceRule object; after the original event was deleted that
/// reference went stale, and re-attaching it in applySnapshot made the save
/// fail (EKCADErrorDomain 1010, #186 on-device). Rebuilding a fresh rule from
/// plain values closes that class structurally.
struct RecurrenceRuleSnapshot {
    struct DayOfWeek {
        let day: Int        // EKWeekday rawValue
        let weekNumber: Int
    }
    let frequency: EKRecurrenceFrequency
    let interval: Int
    let daysOfTheWeek: [DayOfWeek]?
    let daysOfTheMonth: [Int]?
    let monthsOfTheYear: [Int]?
    let weeksOfTheYear: [Int]?
    let daysOfTheYear: [Int]?
    let setPositions: [Int]?
    let endDate: Date?
    let occurrenceCount: Int?

    init(from rule: EKRecurrenceRule) {
        self.frequency = rule.frequency
        self.interval = rule.interval
        self.daysOfTheWeek = rule.daysOfTheWeek?.map { DayOfWeek(day: $0.dayOfTheWeek.rawValue, weekNumber: $0.weekNumber) }
        self.daysOfTheMonth = rule.daysOfTheMonth?.map(\.intValue)
        self.monthsOfTheYear = rule.monthsOfTheYear?.map(\.intValue)
        self.weeksOfTheYear = rule.weeksOfTheYear?.map(\.intValue)
        self.daysOfTheYear = rule.daysOfTheYear?.map(\.intValue)
        self.setPositions = rule.setPositions?.map(\.intValue)
        self.endDate = rule.recurrenceEnd?.endDate
        // EKRecurrenceEnd.occurrenceCount is 0 when the end is date-based
        let count = rule.recurrenceEnd?.occurrenceCount ?? 0
        self.occurrenceCount = count > 0 ? count : nil
    }

    func rebuild() -> EKRecurrenceRule {
        var end: EKRecurrenceEnd?
        if let date = endDate {
            end = EKRecurrenceEnd(end: date)
        } else if let count = occurrenceCount {
            end = EKRecurrenceEnd(occurrenceCount: count)
        }
        return EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: interval,
            daysOfTheWeek: daysOfTheWeek?.compactMap { d in
                EKWeekday(rawValue: d.day).map { EKRecurrenceDayOfWeek($0, weekNumber: d.weekNumber) }
            },
            daysOfTheMonth: daysOfTheMonth?.map(NSNumber.init),
            monthsOfTheYear: monthsOfTheYear?.map(NSNumber.init),
            weeksOfTheYear: weeksOfTheYear?.map(NSNumber.init),
            daysOfTheYear: daysOfTheYear?.map(NSNumber.init),
            setPositions: setPositions?.map(NSNumber.init),
            end: end
        )
    }
}

/// Snapshot of an EKEvent's properties for undo/redo restoration.
struct EventSnapshot {
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarTitle: String
    let calendarSource: String?
    let notes: String?
    let location: String?
    let url: URL?
    let isAllDay: Bool
    let alarmOffsets: [TimeInterval]?
    let structuredLocationTitle: String?
    let structuredLocationLat: Double?
    let structuredLocationLon: Double?
    let structuredLocationRadius: Double?
    // #191 — recurrence rules stored as VALUE snapshots (never raw objects)
    let recurrenceRules: [RecurrenceRuleSnapshot]?
    let timeZone: TimeZone?

    init(from event: EKEvent) {
        self.title = event.title ?? ""
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.calendarTitle = event.calendar.title
        self.calendarSource = event.calendar.source?.title
        self.notes = event.notes
        self.location = event.location
        self.url = event.url
        self.isAllDay = event.isAllDay
        self.alarmOffsets = event.alarms?.map { $0.relativeOffset }
        self.structuredLocationTitle = event.structuredLocation?.title
        self.structuredLocationLat = event.structuredLocation?.geoLocation?.coordinate.latitude
        self.structuredLocationLon = event.structuredLocation?.geoLocation?.coordinate.longitude
        self.structuredLocationRadius = event.structuredLocation?.radius
        self.recurrenceRules = event.recurrenceRules?.map(RecurrenceRuleSnapshot.init)
        self.timeZone = event.timeZone
    }
}

/// Snapshot of an EKReminder's properties for undo/redo restoration.
struct ReminderSnapshot {
    let title: String
    let calendarTitle: String
    let calendarSource: String?
    let notes: String?
    let isCompleted: Bool
    let priority: Int
    let dueDateComponents: DateComponents?
    let alarmOffsets: [TimeInterval]?

    init(from reminder: EKReminder) {
        self.title = reminder.title ?? ""
        self.calendarTitle = reminder.calendar.title
        self.calendarSource = reminder.calendar.source?.title
        self.notes = reminder.notes
        self.isCompleted = reminder.isCompleted
        self.priority = reminder.priority
        self.dueDateComponents = reminder.dueDateComponents
        self.alarmOffsets = reminder.alarms?.map { $0.relativeOffset }
    }
}

// MARK: - Operations

/// A recorded mutation operation that can be undone/redone.
enum UndoOperation {
    case createEvent(id: String, title: String)
    case deleteEvent(snapshot: EventSnapshot)
    case updateEvent(id: String, oldSnapshot: EventSnapshot)
    case createReminder(id: String, title: String)
    case deleteReminder(snapshot: ReminderSnapshot)
    case updateReminder(id: String, oldSnapshot: ReminderSnapshot)
    case completeReminder(id: String, wasCompleted: Bool, title: String)
    case batch([UndoOperation])

    /// Human-readable description of this operation. **Surfaces verbatim
    /// through the `undo_history` MCP tool's response field**, so any
    /// user-controlled title here flows through the same wire path as
    /// `executeUndo`/`executeRedo` arms — and shares the same CWE-117
    /// log-injection surface. Each title interpolation must go through
    /// `EventKitErrorSanitizer.sanitizeForInterpolation` (#74 verify DA1).
    var description: String {
        switch self {
        case .createEvent(_, let title):
            return "Created event: \(EventKitErrorSanitizer.sanitizeForInterpolation(title))"
        case .deleteEvent(let snapshot):
            return "Deleted event: \(EventKitErrorSanitizer.sanitizeForInterpolation(snapshot.title))"
        case .updateEvent(_, let old):
            return "Updated event: \(EventKitErrorSanitizer.sanitizeForInterpolation(old.title))"
        case .createReminder(_, let title):
            return "Created reminder: \(EventKitErrorSanitizer.sanitizeForInterpolation(title))"
        case .deleteReminder(let snapshot):
            return "Deleted reminder: \(EventKitErrorSanitizer.sanitizeForInterpolation(snapshot.title))"
        case .updateReminder(_, let old):
            return "Updated reminder: \(EventKitErrorSanitizer.sanitizeForInterpolation(old.title))"
        case .completeReminder(_, _, let title):
            return "Completed reminder: \(EventKitErrorSanitizer.sanitizeForInterpolation(title))"
        case .batch(let ops):
            return "Batch (\(ops.count) operations)"
        }
    }
}

/// Timestamped record of an operation.
struct UndoRecord {
    let operation: UndoOperation
    let timestamp: Date

    init(_ operation: UndoOperation) {
        self.operation = operation
        self.timestamp = Date()
    }
}

// MARK: - UndoManager

/// In-memory undo/redo stack for calendar and reminder operations.
/// History is lost on server restart.
actor CalendarUndoManager {
    static let shared = CalendarUndoManager()

    private var undoStack: [UndoRecord] = []
    private var redoStack: [UndoRecord] = []
    private let maxStackSize = 50

    private init() {}

    /// Record a mutation. Clears the redo stack.
    func record(_ operation: UndoOperation) {
        undoStack.append(UndoRecord(operation))
        if undoStack.count > maxStackSize {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
    }

    /// Pop the most recent operation for undoing.
    func popUndo() -> UndoRecord? {
        guard let record = undoStack.popLast() else { return nil }
        redoStack.append(record)
        return record
    }

    /// Pop the most recent undone operation for redoing.
    /// #191 — a FAILED executeUndo must not consume the entry. Contract: call
    /// ONLY immediately after the corresponding popUndo threw during execution —
    /// popUndo moved the record to the redo stack, so drop that copy and
    /// re-append the record to the undo stack.
    func restoreFailedUndo(_ record: UndoRecord) {
        if !redoStack.isEmpty { redoStack.removeLast() }
        undoStack.append(record)
    }

    /// #191 — symmetric restore for a failed executeRedo (same call contract).
    func restoreFailedRedo(_ record: UndoRecord) {
        if !undoStack.isEmpty { undoStack.removeLast() }
        redoStack.append(record)
    }

    func popRedo() -> UndoRecord? {
        guard let record = redoStack.popLast() else { return nil }
        undoStack.append(record)
        return record
    }

    /// Get undo history (newest first).
    func history() -> [(index: Int, description: String, timestamp: Date)] {
        return undoStack.enumerated().reversed().map { (index, record) in
            (index: index, description: record.operation.description, timestamp: record.timestamp)
        }
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var undoCount: Int { undoStack.count }
    var redoCount: Int { redoStack.count }
}
