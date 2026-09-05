import XCTest
@testable import CheICalMCP

/// Completion undo records are value-only; no EventKitManager instance or TCC.
final class ReminderCompletionUndoTests: XCTestCase {
    private func snapshot(title: String = "Daily reminder", completed: Bool = false) -> ReminderCompletionSnapshot {
        ReminderCompletionSnapshot(
            id: "recurring-194", title: title, calendarID: "calendar",
            sourceID: "source", isCompleted: completed, hasRecurrence: true,
            due: nil, rules: []
        )
    }

    func testHistoryDescriptionDistinguishesCompletionAndReopen() {
        let before = snapshot()
        XCTAssertEqual(
            UndoOperation.completeRecurringReminder(before: before, requestedCompleted: true).description,
            "Completed recurring reminder: Daily reminder"
        )
        XCTAssertEqual(
            UndoOperation.completeRecurringReminder(before: before, requestedCompleted: false).description,
            "Reopened recurring reminder: Daily reminder"
        )
    }

    func testHistoryDescriptionSanitizesUserControlledTitle() {
        let title = "Reminder\nForged log\r\t\u{001B}[31m"
        let operation = UndoOperation.completeRecurringReminder(before: snapshot(title: title), requestedCompleted: true)
        XCTAssertEqual(operation.description,
                       "Completed recurring reminder: \(EventKitErrorSanitizer.sanitizeForInterpolation(title))")
        XCTAssertFalse(operation.description.contains("\n"))
        XCTAssertFalse(operation.description.contains("\r"))
        XCTAssertFalse(operation.description.contains("\u{001B}"))
    }

    func testRecordPreservesRequestedStateForIdempotentCompletion() {
        // Redo must retain the explicit requested state; inverting the old state
        // would incorrectly reopen an already-completed reminder.
        let before = snapshot(completed: true)
        let record = UndoRecord(.completeRecurringReminder(before: before, requestedCompleted: true))
        guard case .completeRecurringReminder(let saved, let requested) = record.operation else {
            return XCTFail("Expected recurring completion record")
        }
        XCTAssertEqual(saved, before)
        XCTAssertTrue(requested)
        XCTAssertTrue(saved.isCompleted)
    }

    func testLegacyCompletionConstructorAndDescriptionRemainAvailable() {
        let operation = UndoOperation.completeReminder(id: "once", wasCompleted: false, title: "Once")
        XCTAssertEqual(operation.description, "Completed reminder: Once")
    }
}
