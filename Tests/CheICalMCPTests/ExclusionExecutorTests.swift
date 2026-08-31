import XCTest
@testable import CheICalMCP

/// Pure-unit tests for the two-pass exclusion sequencing core (#182).
///
/// The executor is the atomicity seam of `excluded_occurrence_dates`: EventKit
/// itself cannot run under CI, so the ordering contract (resolve ALL before
/// removing ANY; rollback on every failure path; rollback failure carries the
/// already-applied list) is pinned here against closures.
final class ExclusionExecutorTests: XCTestCase {

    private let d1 = Date(timeIntervalSince1970: 1_756_000_000)
    private let d2 = Date(timeIntervalSince1970: 1_756_086_400)
    private let d3 = Date(timeIntervalSince1970: 1_756_172_800)

    private struct StubOccurrence: Equatable { let day: Date }
    private enum StubError: Error { case removeBoom, rollbackBoom }

    func testHappyPathResolvesAllBeforeRemovingAny() throws {
        var log: [String] = []
        let applied = try ExclusionExecutor.run(
            dates: [d1, d2],
            resolve: { date in log.append("resolve"); return StubOccurrence(day: date) },
            remove: { _ in log.append("remove") },
            rollback: { XCTFail("rollback must not run on the happy path") }
        )
        XCTAssertEqual(applied, [d1, d2])
        XCTAssertEqual(log, ["resolve", "resolve", "remove", "remove"],
                       "pass 1 (resolve) must fully precede pass 2 (remove)")
    }

    func testEmptyDatesIsNoOp() throws {
        let applied = try ExclusionExecutor.run(
            dates: [],
            resolve: { (_: Date) -> StubOccurrence? in XCTFail("no resolve expected"); return nil },
            remove: { _ in XCTFail("no remove expected") },
            rollback: { XCTFail("no rollback expected") }
        )
        XCTAssertEqual(applied, [])
    }

    func testResolveMissRollsBackBeforeAnyRemove() {
        var removes = 0
        var rollbacks = 0
        XCTAssertThrowsError(try ExclusionExecutor.run(
            dates: [d1, d2, d3],
            resolve: { date in date == self.d2 ? nil : StubOccurrence(day: date) },
            remove: { _ in removes += 1 },
            rollback: { rollbacks += 1 }
        )) { error in
            guard case ExclusionExecutionError.noOccurrence(let date) = error else {
                return XCTFail("expected .noOccurrence, got \(error)")
            }
            XCTAssertEqual(date, self.d2)
        }
        XCTAssertEqual(removes, 0, "a resolve miss must abort before any occurrence is removed")
        XCTAssertEqual(rollbacks, 1)
    }

    func testRemoveFailureRollsBack() {
        var rollbacks = 0
        XCTAssertThrowsError(try ExclusionExecutor.run(
            dates: [d1, d2],
            resolve: { StubOccurrence(day: $0) },
            remove: { occ in if occ.day == self.d2 { throw StubError.removeBoom } },
            rollback: { rollbacks += 1 }
        )) { error in
            guard case ExclusionExecutionError.removeFailed(let date) = error else {
                return XCTFail("expected .removeFailed, got \(error)")
            }
            XCTAssertEqual(date, self.d2)
        }
        XCTAssertEqual(rollbacks, 1)
    }

    func testRollbackFailureAfterRemoveFailureCarriesAppliedDates() {
        XCTAssertThrowsError(try ExclusionExecutor.run(
            dates: [d1, d2],
            resolve: { StubOccurrence(day: $0) },
            remove: { occ in if occ.day == self.d2 { throw StubError.removeBoom } },
            rollback: { throw StubError.rollbackBoom }
        )) { error in
            guard case ExclusionExecutionError.rollbackFailed(let applied) = error else {
                return XCTFail("expected .rollbackFailed, got \(error)")
            }
            XCTAssertEqual(applied, [self.d1],
                           "rollback failure must report exactly the exclusions already applied")
        }
    }

    func testRollbackFailureAfterResolveMissCarriesEmptyApplied() {
        XCTAssertThrowsError(try ExclusionExecutor.run(
            dates: [d1],
            resolve: { (_: Date) -> StubOccurrence? in nil },
            remove: { _ in XCTFail("no remove expected") },
            rollback: { throw StubError.rollbackBoom }
        )) { error in
            guard case ExclusionExecutionError.rollbackFailed(let applied) = error else {
                return XCTFail("expected .rollbackFailed, got \(error)")
            }
            XCTAssertEqual(applied, [])
        }
    }
}
