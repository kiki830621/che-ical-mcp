import XCTest
@testable import CheICalMCP

/// Pure-unit tests for `EventKitManager.validateExclusionWindow` (#182 verify
/// round-1 fixes, findings #5/#6). Static + EventKit-free — runs on CI.
final class ExclusionWindowValidationTests: XCTestCase {

    private let tz = TimeZone(identifier: "America/Toronto")!

    private func date(_ s: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.timeZone = tz
        return f.date(from: s)!
    }

    private func rule(endDate: Date? = nil, count: Int? = nil, frequency: RecurrenceRuleInput.Frequency = .daily, interval: Int = 1) -> RecurrenceRuleInput {
        RecurrenceRuleInput(frequency: frequency, interval: interval, endDate: endDate,
                            occurrenceCount: count, daysOfWeek: nil, daysOfMonth: nil,
                            excludedOccurrenceDates: nil)
    }

    /// Finding #5 — excluding the first occurrence day is rejected.
    func testFirstOccurrenceExclusionRejected() {
        XCTAssertThrowsError(try EventKitManager.validateExclusionWindow(
            excluded: [date("2026-09-01T00:00:00")],
            startDate: date("2026-09-01T09:00:00"),
            rule: rule(endDate: date("2026-09-30T00:00:00")),
            timezone: tz
        )) { error in
            guard case EventKitError.exclusionFirstOccurrence = error else {
                return XCTFail("expected .exclusionFirstOccurrence, got \(error)")
            }
        }
    }

    /// Finding #6 — exclusion count >= occurrence_count empties the series.
    func testExclusionSetCoveringWholeSeriesRejected() {
        XCTAssertThrowsError(try EventKitManager.validateExclusionWindow(
            excluded: [date("2026-09-02T00:00:00"), date("2026-09-03T00:00:00")],
            startDate: date("2026-09-01T09:00:00"),
            rule: rule(count: 2),
            timezone: tz
        )) { error in
            guard case EventKitError.exclusionRemovesAllOccurrences(let e, let c) = error else {
                return XCTFail("expected .exclusionRemovesAllOccurrences, got \(error)")
            }
            XCTAssertEqual(e, 2); XCTAssertEqual(c, 2)
        }
    }

    /// Finding #6 — a date past the occurrence_count-derived bound is rejected pre-save.
    func testDateBeyondCountWindowRejected() {
        // daily count=5 starting 2026-09-01 → last possible day 2026-09-05
        XCTAssertThrowsError(try EventKitManager.validateExclusionWindow(
            excluded: [date("2026-09-20T00:00:00")],
            startDate: date("2026-09-01T09:00:00"),
            rule: rule(count: 5),
            timezone: tz
        )) { error in
            guard case EventKitError.exclusionOutOfWindow = error else {
                return XCTFail("expected .exclusionOutOfWindow, got \(error)")
            }
        }
    }

    /// Weekly count bound is deliberately loose (interval*7): in-bound passes.
    func testWeeklyCountWindowLooseBoundAccepts() throws {
        // weekly count=4 from 2026-09-01 → bound = start + 21d = 2026-09-22
        try EventKitManager.validateExclusionWindow(
            excluded: [date("2026-09-15T00:00:00")],
            startDate: date("2026-09-01T09:00:00"),
            rule: rule(count: 4, frequency: .weekly),
            timezone: tz
        )
    }

    /// end_date bound still enforced (pre-fix behavior retained).
    func testDateAfterEndDateRejected() {
        XCTAssertThrowsError(try EventKitManager.validateExclusionWindow(
            excluded: [date("2026-10-15T00:00:00")],
            startDate: date("2026-09-01T09:00:00"),
            rule: rule(endDate: date("2026-09-30T00:00:00")),
            timezone: tz
        )) { error in
            guard case EventKitError.exclusionOutOfWindow = error else {
                return XCTFail("expected .exclusionOutOfWindow, got \(error)")
            }
        }
    }

    /// Valid mid-series exclusion passes all gates.
    func testValidMidSeriesExclusionAccepted() throws {
        try EventKitManager.validateExclusionWindow(
            excluded: [date("2026-09-07T00:00:00"), date("2026-09-14T00:00:00")],
            startDate: date("2026-09-01T09:00:00"),
            rule: rule(endDate: date("2026-09-30T00:00:00")),
            timezone: tz
        )
    }
}
