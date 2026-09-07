import XCTest
@testable import CheICalMCP

/// Completion undo records are value-only; no EventKitManager instance or TCC.
final class ReminderCompletionUndoTests: XCTestCase {
    func testLegacyCompletionConstructorAndDescriptionRemainAvailable() {
        let operation = UndoOperation.completeReminder(id: "once", wasCompleted: false, title: "Once")
        XCTAssertEqual(operation.description, "Completed reminder: Once")
    }
}
