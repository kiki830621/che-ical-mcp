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
}
