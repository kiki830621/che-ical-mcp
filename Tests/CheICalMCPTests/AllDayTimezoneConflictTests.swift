import XCTest
import MCP
@testable import CheICalMCP

/// #190 — all_day + timezone must be rejected, not silently degraded to a timed
/// event. All cases fail at the handler guard BEFORE any EventKit call (CI-safe).
final class AllDayTimezoneConflictTests: XCTestCase {

    private func errorText(_ result: CallTool.Result) -> String {
        guard case let .text(text, _, _)? = result.content.first else { return "" }
        return text
    }

    func testCreateEventRejectsAllDayWithTimezone() async throws {
        let server = try await CheICalMCPServer()
        let result = await server.handleToolCallForTesting(
            name: "create_event",
            arguments: [
                "title": .string("t"),
                "start_time": .string("2026-09-21"),
                "end_time": .string("2026-09-22"),
                "all_day": .bool(true),
                "timezone": .string("America/Los_Angeles"),
                "calendar_name": .string("Work")
            ]
        )
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(errorText(result).contains("all-day") || errorText(result).contains("all_day"),
                      "got: \(errorText(result))")
    }

    func testBatchItemRejectsAllDayWithTimezone() async throws {
        let server = try await CheICalMCPServer()
        let result = await server.handleToolCallForTesting(
            name: "create_events_batch",
            arguments: [
                "events": .array([.object([
                    "title": .string("t"),
                    "start_time": .string("2026-09-21"),
                    "end_time": .string("2026-09-22"),
                    "all_day": .bool(true),
                    "timezone": .string("America/Los_Angeles"),
                    "calendar_name": .string("Work")
                ])])
            ]
        )
        // batch 是 per-item partial failure：整體回 success envelope，該 item success:false
        let text = errorText(result)
        XCTAssertTrue(text.contains("\"failed\" : 1") || text.contains("\"failed\": 1"),
                      "item must fail, got: \(text)")
        XCTAssertTrue(text.contains("all-day") || text.contains("all_day"),
                      "item error must name the conflict, got: \(text)")
    }

    func testUpdateEventRejectsAllDayWithTimezone() async throws {
        let server = try await CheICalMCPServer()
        let result = await server.handleToolCallForTesting(
            name: "update_event",
            arguments: [
                "event_id": .string("x"),
                "all_day": .bool(true),
                "timezone": .string("Asia/Tokyo")
            ]
        )
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(errorText(result).contains("all-day") || errorText(result).contains("all_day"))
    }

    /// all_day without timezone stays legal (the #186 control group) — must not
    /// hit the new guard (CI fails later at the EventKit access gate instead).
    func testAllDayWithoutTimezoneNotBlocked() async throws {
        let server = try await CheICalMCPServer()
        let result = await server.handleToolCallForTesting(
            name: "create_event",
            arguments: [
                "title": .string("t"),
                "start_time": .string("2026-09-21"),
                "end_time": .string("2026-09-22"),
                "all_day": .bool(true),
                "calendar_name": .string("Work")
            ]
        )
        XCTAssertFalse(errorText(result).contains("floating"),
                       "pure all-day must not trip the conflict guard, got: \(errorText(result))")
    }
}
