import Foundation
import MCP
import XCTest
@testable import CheICalMCP

private actor CompletionFake: ReminderCompletionSource {
    var calls = 0
    let fail: Bool
    init(fail: Bool = false) { self.fail = fail }
    func completeReminder(identifier: String, completed: Bool) async throws -> ReminderCompletionResult {
        calls += 1
        if fail { throw ToolError.invalidParameter("simulated save failure") }
        let before = ReminderCompletionSnapshot(id: identifier, title: "Repeat", calendarID: "list", sourceID: "source", isCompleted: false, hasRecurrence: true, due: nil, rules: nil)
        return ReminderCompletionResult(before: before, afterSave: before, requestedCompleted: completed, nextOccurrence: completed ? .unknown(reason: "not_observed") : .notApplicable)
    }
}

final class ReminderCompletionHandlerTests: XCTestCase {
    func testSuccessfulCompletionIsIndependentOfIncompleteObject() async throws {
        let fake = CompletionFake()
        let server = try await CheICalMCPServer(reminderCompletionSource: fake)
        let raw = try await server.executeToolCall(name: "complete_reminder", arguments: ["reminder_id": .string("r")])
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
        XCTAssertEqual(json["action"] as? String, "completed")
        XCTAssertEqual(json["is_completed"] as? Bool, false)
        XCTAssertEqual(json["has_recurrence"] as? Bool, true)
        let operation = try XCTUnwrap(json["operation"] as? [String: Any])
        XCTAssertEqual(operation["status"] as? String, "succeeded")
        XCTAssertEqual(operation["type"] as? String, "complete")
        let next = try XCTUnwrap(json["next_occurrence"] as? [String: Any])
        XCTAssertEqual(next["status"] as? String, "unknown")
        let calls = await fake.calls
        XCTAssertEqual(calls, 1)
    }

    func testReopenReportsRequestedActionWithoutChangingLegacyAction() async throws {
        let server = try await CheICalMCPServer(reminderCompletionSource: CompletionFake())
        let raw = try await server.executeToolCall(name: "complete_reminder", arguments: ["reminder_id": .string("r"), "completed": .bool(false)])
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
        let operation = try XCTUnwrap(json["operation"] as? [String: Any])
        XCTAssertEqual(operation["type"] as? String, "reopen")
        XCTAssertEqual(operation["requested_completed"] as? Bool, false)
        XCTAssertEqual(json["action"] as? String, "completed")
    }

}
