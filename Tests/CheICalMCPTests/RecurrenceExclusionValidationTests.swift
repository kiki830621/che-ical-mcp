import XCTest
import MCP
@testable import CheICalMCP

/// Validation-layer tests for `excluded_occurrence_dates` (#182).
///
/// Every case here fails inside `parseRecurrenceRule` — BEFORE any
/// `EventKitManager` call — so these run on CI without TCC access
/// (same guarantee style as `CleanupHandlerTests.testF1GuardFiresBeforeListReminders`).
final class RecurrenceExclusionValidationTests: XCTestCase {

    private func callCreateEvent(recurrenceExtra: [String: Value]) async throws -> CallTool.Result {
        let server = try await CheICalMCPServer()
        var recurrence: [String: Value] = [
            "frequency": .string("daily"),
            "end_date": .string("2026-09-30")
        ]
        recurrence.merge(recurrenceExtra) { _, new in new }
        return await server.handleToolCallForTesting(
            name: "create_event",
            arguments: [
                "title": .string("Training"),
                "start_time": .string("2026-09-01T09:00:00"),
                "end_time": .string("2026-09-01T10:00:00"),
                "timezone": .string("America/Toronto"),
                "calendar_name": .string("Work"),
                "recurrence": .object(recurrence)
            ]
        )
    }

    private func errorText(_ result: CallTool.Result) -> String {
        guard case let .text(text, _, _)? = result.content.first else { return "" }
        return text
    }

    // MARK: caller gating

    func testUpdateEventRejectsExcludedDates() async throws {
        let server = try await CheICalMCPServer()
        let result = await server.handleToolCallForTesting(
            name: "update_event",
            arguments: [
                "event_id": .string("some-id"),
                "recurrence": .object([
                    "frequency": .string("daily"),
                    "excluded_occurrence_dates": .array([.string("2026-09-07")])
                ])
            ]
        )
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(errorText(result).contains("excluded_occurrence_dates"),
                      "rejection must name the unsupported field, got: \(errorText(result))")
    }

    func testCreateReminderRejectsExcludedDates() async throws {
        let server = try await CheICalMCPServer()
        let result = await server.handleToolCallForTesting(
            name: "create_reminder",
            arguments: [
                "title": .string("r"),
                "recurrence": .object([
                    "frequency": .string("daily"),
                    "excluded_occurrence_dates": .array([.string("2026-09-07")])
                ])
            ]
        )
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(errorText(result).contains("excluded_occurrence_dates"))
    }

    // MARK: type validation

    func testNonArrayRejected() async throws {
        let result = try await callCreateEvent(recurrenceExtra: [
            "excluded_occurrence_dates": .string("2026-09-07")
        ])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(errorText(result).contains("array"))
    }

    func testNonStringElementRejectedWithIndex() async throws {
        let result = try await callCreateEvent(recurrenceExtra: [
            "excluded_occurrence_dates": .array([.string("2026-09-07"), .int(20260914)])
        ])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(errorText(result).contains("[1]"),
                      "error must carry the offending index, got: \(errorText(result))")
    }

    // MARK: duplicates and cap

    func testDuplicateDatesRejected() async throws {
        let result = try await callCreateEvent(recurrenceExtra: [
            "excluded_occurrence_dates": .array([.string("2026-09-07"), .string("2026-09-07")])
        ])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(errorText(result).contains("duplicate"),
                      "got: \(errorText(result))")
    }

    func testCapAt100Rejected() async throws {
        let dates: [Value] = (1...101).map { .string(String(format: "2027-%02d-%02d", ($0 % 12) + 1, ($0 % 28) + 1)) }
        let result = try await callCreateEvent(recurrenceExtra: [
            "excluded_occurrence_dates": .array(dates)
        ])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(errorText(result).contains("100"))
    }
}

// MARK: - Verify round 1 fixes (#182 findings 3/4/5/6/9)

extension RecurrenceExclusionValidationTests {

    /// Finding #3 — top-level misplacement must be rejected, not silently dropped.
    func testTopLevelExcludedDatesRejectedOnCreateEvent() async throws {
        let server = try await CheICalMCPServer()
        let result = await server.handleToolCallForTesting(
            name: "create_event",
            arguments: [
                "title": .string("t"),
                "start_time": .string("2026-09-01T09:00:00"),
                "end_time": .string("2026-09-01T10:00:00"),
                "excluded_occurrence_dates": .array([.string("2026-09-07")])
            ]
        )
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(errorText(result).contains("top-level"),
                      "got: \(errorText(result))")
    }

    /// Finding #3 — same guard on update_event's top level.
    func testTopLevelExcludedDatesRejectedOnUpdateEvent() async throws {
        let server = try await CheICalMCPServer()
        let result = await server.handleToolCallForTesting(
            name: "update_event",
            arguments: [
                "event_id": .string("x"),
                "excluded_occurrence_dates": .array([.string("2026-09-07")])
            ]
        )
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(errorText(result).contains("excluded_occurrence_dates"))
    }

    /// Finding #4 — JSON-number end_date must throw, not silently drop the window bound.
    func testNumericEndDateRejected() async throws {
        let server = try await CheICalMCPServer()
        let result = await server.handleToolCallForTesting(
            name: "create_event",
            arguments: [
                "title": .string("t"),
                "start_time": .string("2026-09-01T09:00:00"),
                "end_time": .string("2026-09-01T10:00:00"),
                "calendar_name": .string("Work"),
                "recurrence": .object([
                    "frequency": .string("daily"),
                    "end_date": .int(20260930)
                ])
            ]
        )
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(errorText(result).contains("end_date"))
    }

    /// Finding #9 — stringly-typed occurrence_count must throw (symmetry with interval).
    func testStringOccurrenceCountRejected() async throws {
        let server = try await CheICalMCPServer()
        let result = await server.handleToolCallForTesting(
            name: "create_event",
            arguments: [
                "title": .string("t"),
                "start_time": .string("2026-09-01T09:00:00"),
                "end_time": .string("2026-09-01T10:00:00"),
                "calendar_name": .string("Work"),
                "recurrence": .object([
                    "frequency": .string("daily"),
                    "occurrence_count": .string("5")
                ])
            ]
        )
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(errorText(result).contains("occurrence_count"))
    }
}
