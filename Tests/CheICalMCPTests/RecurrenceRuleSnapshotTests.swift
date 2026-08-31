import XCTest
import EventKit
@testable import CheICalMCP

/// #191 — value-snapshot roundtrip for EKRecurrenceRule (pure objects, no TCC;
/// CI-safe) + undo-stack failure-restore semantics.
final class RecurrenceRuleSnapshotTests: XCTestCase {

    func testDailyWithEndDateRoundtrip() {
        let end = Date(timeIntervalSince1970: 1_760_000_000)
        let rule = EKRecurrenceRule(recurrenceWith: .daily, interval: 2,
                                    end: EKRecurrenceEnd(end: end))
        let rebuilt = RecurrenceRuleSnapshot(from: rule).rebuild()
        XCTAssertEqual(rebuilt.frequency, .daily)
        XCTAssertEqual(rebuilt.interval, 2)
        XCTAssertEqual(rebuilt.recurrenceEnd?.endDate, end)
        XCTAssertNil(rebuilt.recurrenceEnd?.occurrenceCount == 0 ? nil : rebuilt.recurrenceEnd?.occurrenceCount)
    }

    func testWeeklyWithDaysAndCountRoundtrip() {
        let days = [EKRecurrenceDayOfWeek(.monday), EKRecurrenceDayOfWeek(.friday)]
        let rule = EKRecurrenceRule(recurrenceWith: .weekly, interval: 1,
                                    daysOfTheWeek: days, daysOfTheMonth: nil,
                                    monthsOfTheYear: nil, weeksOfTheYear: nil,
                                    daysOfTheYear: nil, setPositions: nil,
                                    end: EKRecurrenceEnd(occurrenceCount: 5))
        let rebuilt = RecurrenceRuleSnapshot(from: rule).rebuild()
        XCTAssertEqual(rebuilt.frequency, .weekly)
        XCTAssertEqual(rebuilt.daysOfTheWeek?.map(\.dayOfTheWeek), [.monday, .friday])
        XCTAssertEqual(rebuilt.recurrenceEnd?.occurrenceCount, 5)
    }

    func testMonthlyWithDaysOfMonthNoEndRoundtrip() {
        let rule = EKRecurrenceRule(recurrenceWith: .monthly, interval: 3,
                                    daysOfTheWeek: nil, daysOfTheMonth: [1, 15, 31],
                                    monthsOfTheYear: nil, weeksOfTheYear: nil,
                                    daysOfTheYear: nil, setPositions: nil, end: nil)
        let rebuilt = RecurrenceRuleSnapshot(from: rule).rebuild()
        XCTAssertEqual(rebuilt.frequency, .monthly)
        XCTAssertEqual(rebuilt.interval, 3)
        XCTAssertEqual(rebuilt.daysOfTheMonth, [1, 15, 31])
        XCTAssertNil(rebuilt.recurrenceEnd)
    }

    func testYearlyWithSetPositionsRoundtrip() {
        let rule = EKRecurrenceRule(recurrenceWith: .yearly, interval: 1,
                                    daysOfTheWeek: [EKRecurrenceDayOfWeek(.sunday, weekNumber: 2)],
                                    daysOfTheMonth: nil, monthsOfTheYear: [6],
                                    weeksOfTheYear: nil, daysOfTheYear: nil,
                                    setPositions: [1, -1], end: nil)
        let rebuilt = RecurrenceRuleSnapshot(from: rule).rebuild()
        XCTAssertEqual(rebuilt.monthsOfTheYear, [6])
        XCTAssertEqual(rebuilt.setPositions, [1, -1])
        XCTAssertEqual(rebuilt.daysOfTheWeek?.first?.weekNumber, 2)
    }

    /// The rebuilt rule must be a fresh object — never the original reference
    /// (the stale-reference class behind the on-device 1010).
    func testRebuildProducesFreshObject() {
        let rule = EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        let rebuilt = RecurrenceRuleSnapshot(from: rule).rebuild()
        XCTAssertFalse(rule === rebuilt)
    }
}

/// #191 — a failed undo/redo must NOT consume the entry.
final class UndoFailureRestoreTests: XCTestCase {

    func testRestoreFailedUndoPutsRecordBack() async {
        let mgr = CalendarUndoManager.shared
        await mgr.record(.createEvent(id: "restore-probe-191", title: "t"))
        guard let record = await mgr.popUndo() else { return XCTFail("expected a record") }
        // simulate executeUndo failure → restore
        await mgr.restoreFailedUndo(record)
        guard let again = await mgr.popUndo() else { return XCTFail("record must be back on the undo stack") }
        if case .createEvent(let id, _) = again.operation {
            XCTAssertEqual(id, "restore-probe-191")
        } else {
            XCTFail("wrong record restored")
        }
        // cleanup: drop the probe from the redo stack
        _ = await mgr.popRedo()
    }
}
