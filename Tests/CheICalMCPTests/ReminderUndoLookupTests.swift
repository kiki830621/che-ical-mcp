import XCTest
@testable import CheICalMCP

/// #206 — pure resolver; the closures stand in for the store (closure seam, #182).
final class ReminderUndoLookupTests: XCTestCase {
    private struct Item: Equatable { let id: String }

    func testFoundOnFirstLookupDoesNotRefresh() throws {
        var refreshes = 0
        let item = try ReminderUndoLookup.resolve(id: "a", what: "reminder",
                                                  lookup: { Item(id: $0) }, refresh: { refreshes += 1 })
        XCTAssertEqual(item, Item(id: "a"))
        XCTAssertEqual(refreshes, 0)
    }

    func testMissOnceThenFoundAfterRefreshIsTransient() throws {
        var refreshes = 0; var calls = 0
        let item = try ReminderUndoLookup.resolve(id: "a", what: "reminder",
                                                  lookup: { id -> Item? in calls += 1; return calls == 1 ? nil : Item(id: id) },
                                                  refresh: { refreshes += 1 })
        XCTAssertEqual(item, Item(id: "a"))
        XCTAssertEqual(refreshes, 1)
        XCTAssertEqual(calls, 2)
    }

    func testStillMissingAfterRefreshIsPermanentAndDiscarded() {
        var refreshes = 0
        XCTAssertThrowsError(try ReminderUndoLookup.resolve(id: "gone", what: "reminder",
                                                           lookup: { _ -> Item? in nil }, refresh: { refreshes += 1 })) { error in
            XCTAssertTrue(error is UnrecoverableUndoError, "\(error)")
            XCTAssertEqual(UndoFailureDisposition.of(error), .discard)
            XCTAssertTrue("\(error)".contains("deleted"), "\(error)")
        }
        XCTAssertEqual(refreshes, 1, "exactly one forced refresh before declaring the item gone")
    }

    func testLookupErrorsPropagateUnchangedAndStayTransient() {
        struct StoreDown: Error {}
        XCTAssertThrowsError(try ReminderUndoLookup.resolve(id: "a", what: "reminder",
                                                           lookup: { _ -> Item? in throw StoreDown() }, refresh: {})) { error in
            XCTAssertTrue(error is StoreDown)
            XCTAssertEqual(UndoFailureDisposition.of(error), .restore)
        }
    }
}
