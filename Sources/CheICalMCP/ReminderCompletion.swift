import EventKit
import Foundation

/// Values captured inside EventKitManager's actor, before an EKReminder can roll over.
struct ReminderCompletionSnapshot: Equatable, Sendable {
    let id: String
    let title: String
    let calendarID: String
    let sourceID: String
    let isCompleted: Bool
    let hasRecurrence: Bool
    let due: ReminderDueValue?
    let rules: [ReminderRecurrenceRuleValue]?

    init(id: String, title: String, calendarID: String, sourceID: String,
         isCompleted: Bool, hasRecurrence: Bool, due: ReminderDueValue?,
         rules: [ReminderRecurrenceRuleValue]?) {
        self.id = id
        self.title = title
        self.calendarID = calendarID
        self.sourceID = sourceID
        self.isCompleted = isCompleted
        self.hasRecurrence = hasRecurrence
        self.due = due
        self.rules = rules
    }

    init(from reminder: EKReminder) {
        self.init(id: reminder.calendarItemIdentifier, title: reminder.title ?? "",
                  calendarID: reminder.calendar?.calendarIdentifier ?? "",
                  sourceID: reminder.calendar?.source?.sourceIdentifier ?? "",
                  isCompleted: reminder.isCompleted, hasRecurrence: reminder.hasRecurrenceRules,
                  due: ReminderDueValue(components: reminder.dueDateComponents),
                  rules: reminder.recurrenceRules?.map { ReminderRecurrenceRuleValue(from: $0) })
    }
}

/// An observation, never a recurrence calculation or an inferred series end.
struct ReminderNextOccurrence: Equatable, Sendable {
    let status: String
    let reason: String?
    let reminder: ReminderCompletionSnapshot?

    private init(status: String, reason: String? = nil, reminder: ReminderCompletionSnapshot? = nil) {
        self.status = status
        self.reason = reason
        self.reminder = reminder
    }

    static let notApplicable = Self(status: "not_applicable")

    static func unknown(reason: String) -> Self {
        Self(status: "unknown", reason: reason)
    }

    static func evaluate(before: ReminderCompletionSnapshot,
                         observed: ReminderCompletionSnapshot?, requestedCompleted: Bool) -> Self {
        guard requestedCompleted, before.hasRecurrence, !before.isCompleted else {
            return .notApplicable
        }
        guard let observed else { return .unknown(reason: "observation_unavailable") }
        guard !before.id.isEmpty, !before.calendarID.isEmpty, !before.sourceID.isEmpty,
              before.id == observed.id, before.calendarID == observed.calendarID,
              before.sourceID == observed.sourceID else {
            return .unknown(reason: "identity_changed")
        }
        guard observed.hasRecurrence, let rules = before.rules, !rules.isEmpty,
              rules.allSatisfy({ $0.frequency != "unknown" }),
              rules == observed.rules else { return .unknown(reason: "recurrence_unverified") }
        guard !observed.isCompleted else { return .unknown(reason: "successor_not_observed") }
        guard let originalDue = before.due, let observedDue = observed.due,
              originalDue.hasSamePrecisionAndTimeZone(as: observedDue),
              let originalDate = originalDue.chronologicalDate,
              let observedDate = observedDue.chronologicalDate else {
            return .unknown(reason: "due_not_comparable")
        }
        guard observedDate > originalDate else { return .unknown(reason: "due_not_advanced") }
        return Self(status: "confirmed", reminder: observed)
    }

    var dictionary: [String: Any] {
        var value: [String: Any] = ["status": status, "reminder": NSNull()]
        if let reason { value["reason"] = reason }
        if let reminder {
            value["reminder"] = [
                "id": reminder.id, "title": reminder.title,
                "is_completed": reminder.isCompleted,
                "due": reminder.due.map { $0.dictionary as Any } ?? NSNull()
            ] as [String: Any]
        }
        return value
    }
}

struct ReminderCompletionResult: Sendable {
    let before: ReminderCompletionSnapshot
    let afterSave: ReminderCompletionSnapshot
    let requestedCompleted: Bool
    let nextOccurrence: ReminderNextOccurrence

    /// Instant when the due carries a timezone; otherwise the wall-clock date/time.
    private static func dueDescription(_ due: ReminderDueValue?) -> String? {
        guard let due else { return nil }
        let wire = due.dictionary
        if let instant = wire["date_time"] as? String { return instant }
        let parts = [wire["date"] as? String, wire["time"] as? String].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    var dictionary: [String: Any] {
        let message: String
        if !requestedCompleted {
            message = "The request to reopen this reminder was saved successfully."
        } else if before.isCompleted {
            message = "This reminder was already completed; the requested state was saved successfully."
        } else if before.hasRecurrence {
            if nextOccurrence.status == "confirmed",
               let dueText = Self.dueDescription(nextOccurrence.reminder?.due) {
                // #194 asks for "completed; next occurrence <date>".
                message = "This occurrence was completed successfully. Next occurrence: \(dueText) (observed, still incomplete)."
            } else if nextOccurrence.status == "confirmed" {
                message = "This occurrence was completed successfully. The observed next occurrence remains incomplete."
            } else {
                message = "This occurrence was completed successfully. The next occurrence could not be confirmed."
            }
        } else {
            message = "This reminder was completed successfully."
        }
        return [
            // Retain legacy semantics. operation is authoritative for the write outcome.
            "action": "completed",
            "id": before.id,
            "title": afterSave.title,
            "is_completed": afterSave.isCompleted,
            "has_recurrence": before.hasRecurrence,
            "operation": [
                "type": requestedCompleted ? "complete" : "reopen",
                "status": "succeeded",
                "requested_completed": requestedCompleted,
                "target": [
                    "id": before.id,
                    "due": before.due.map { $0.dictionary as Any } ?? NSNull(),
                    "was_completed": before.isCompleted
                ] as [String: Any]
            ] as [String: Any],
            "next_occurrence": nextOccurrence.dictionary,
            "message": message
        ]
    }
}

/// A feature-specific seam; do not widen the cleanup protocol for completion.
protocol ReminderCompletionSource {
    func completeReminder(identifier: String, completed: Bool) async throws -> ReminderCompletionResult
}
