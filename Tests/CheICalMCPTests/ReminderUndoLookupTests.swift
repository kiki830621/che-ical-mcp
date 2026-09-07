import XCTest
@testable import CheICalMCP

/// #206 — pure resolver; the closures stand in for the store (closure seam, #182).
/// The manager wires `lookup` to a real store fetch and `refresh` to
/// `refreshSourcesIfNecessary()`; only the classification is pinned here.
final class ReminderUndoLookupTests: XCTestCase {
    private struct Item: Equatable { let id: String }

    func testFoundOnFirstLookupDoesNotRefresh() async throws {
        var refreshes = 0
        let item = try await ReminderUndoLookup.resolve(id: "a", lookup: { Item(id: $0) }, refresh: { refreshes += 1 })
        XCTAssertEqual(item, Item(id: "a"))
        XCTAssertEqual(refreshes, 0)
    }

    func testMissOnceThenFoundAfterRefreshIsTransient() async throws {
        var refreshes = 0; var calls = 0
        let item = try await ReminderUndoLookup.resolve(id: "a",
                                                        lookup: { id -> Item? in calls += 1; return calls == 1 ? nil : Item(id: id) },
                                                        refresh: { refreshes += 1 })
        XCTAssertEqual(item, Item(id: "a"))
        XCTAssertEqual(refreshes, 1)
        XCTAssertEqual(calls, 2)
    }

    func testStillMissingAfterRefreshThrowsNotFoundOnce() async {
        var refreshes = 0
        do {
            _ = try await ReminderUndoLookup.resolve(id: "gone", lookup: { _ -> Item? in nil }, refresh: { refreshes += 1 })
            XCTFail("expected NotFound")
        } catch let missing as ReminderUndoLookup.NotFound {
            XCTAssertEqual(missing.id, "gone")
        } catch {
            XCTFail("unexpected \(error)")
        }
        XCTAssertEqual(refreshes, 1, "exactly one refresh before giving up")
    }

    func testLookupErrorsPropagateUnchangedAndStayTransient() async {
        struct StoreDown: Error {}
        do {
            _ = try await ReminderUndoLookup.resolve(id: "a", lookup: { _ -> Item? in throw StoreDown() }, refresh: {})
            XCTFail("expected StoreDown")
        } catch {
            XCTAssertTrue(error is StoreDown)
            XCTAssertEqual(UndoFailureDisposition.of(error), .restore)
        }
    }

    func testPermanentErrorIsDiscardedAndNamesTheEntryWithSanitizedTitle() {
        let title = "Groceries\nForged log\u{001B}[31m"
        let error = ReminderUndoLookup.permanentError(for: ReminderUndoLookup.NotFound(id: "abc-123"), title: title, verb: "undo")
        XCTAssertEqual(UndoFailureDisposition.of(error), .discard)
        let text = "\(error.message)"
        XCTAssertTrue(text.contains(EventKitErrorSanitizer.sanitizeForInterpolation(title)), text)
        XCTAssertTrue(text.contains("abc-123"), text)
        XCTAssertFalse(text.contains("\n") || text.contains("\u{001B}"), text)
        // Honest about what a miss can mean — never asserts deletion as fact.
        XCTAssertTrue(text.contains("deleted") && text.contains("account"), text)
    }
}
