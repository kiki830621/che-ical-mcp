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

    func testLegacyCompletionConstructorAndDescriptionRemainAvailable() {
        let operation = UndoOperation.completeReminder(id: "once", wasCompleted: false, title: "Once")
        XCTAssertEqual(operation.description, "Completed reminder: Once")
    }

    func testHistoryDescriptionDistinguishesCompletionAndReopen() {
        let before = snapshot()
        XCTAssertEqual(
            UndoOperation.completeRecurringReminder(before: before, requestedCompleted: true).description,
            "Completed recurring reminder: Daily reminder")
        XCTAssertEqual(
            UndoOperation.completeRecurringReminder(before: before, requestedCompleted: false).description,
            "Reopened recurring reminder: Daily reminder")
    }

    func testHistoryDescriptionSanitizesUserControlledTitle() {
        let title = "Reminder\nForged log\r\t\u{001B}[31m"
        let operation = UndoOperation.completeRecurringReminder(before: snapshot(title: title), requestedCompleted: true)
        XCTAssertEqual(operation.description,
                       "Completed recurring reminder: \(EventKitErrorSanitizer.sanitizeForInterpolation(title))")
        XCTAssertFalse(operation.description.contains("\n"))
        XCTAssertFalse(operation.description.contains("\u{001B}"))
    }

    func testRecordPreservesRequestedStateForIdempotentCompletion() {
        let before = snapshot(completed: true)
        let record = UndoRecord(.completeRecurringReminder(before: before, requestedCompleted: true))
        guard case .completeRecurringReminder(let saved, let requested) = record.operation else {
            return XCTFail("Expected recurring completion record")
        }
        XCTAssertEqual(saved, before)
        XCTAssertTrue(requested)
    }

    func testDiscardFailedUndoDropsTheRecordAndKeepsOlderEntriesReachable() async {
        // Verify round 1, row 1: a permanently un-undoable record re-appended by
        // restoreFailedUndo blocks every older entry forever. Discarding it must
        // leave the older entry on top and must not resurrect it on the redo stack.
        let manager = CalendarUndoManager()
        await manager.record(.completeReminder(id: "older", wasCompleted: false, title: "Older"))
        await manager.record(.completeRecurringReminder(before: snapshot(), requestedCompleted: true))
        guard let popped = await manager.popUndo() else { return XCTFail("expected a record") }
        await manager.discardFailedUndo(popped)
        let descriptions = await manager.history().map(\.description)
        XCTAssertEqual(descriptions, ["Completed reminder: Older"])
        let canRedo = await manager.canRedo
        XCTAssertFalse(canRedo)
        guard case .completeReminder(let id, _, _)? = await manager.popUndo()?.operation else {
            return XCTFail("the older record must be the next undo target")
        }
        XCTAssertEqual(id, "older")
    }

    func testUndoFailureDispositionDiscardsOnlyUnrecoverableErrors() {
        XCTAssertEqual(UndoFailureDisposition.of(UnrecoverableUndoError(message: "gone")), .discard)
        XCTAssertEqual(UndoFailureDisposition.of(ToolError.invalidParameter("transient")), .restore)
        XCTAssertEqual(UndoFailureDisposition.of(EventKitError.reminderNotFound(identifier: "x")), .restore)
        XCTAssertEqual(UnrecoverableUndoError(message: "gone").errorDescription, "gone")
    }
}
