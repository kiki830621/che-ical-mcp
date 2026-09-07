import Foundation
import MCP
import XCTest
@testable import CheICalMCP

/// #203 — `list_reminder_tags` must read through the `ReminderReadSource` seam
/// like `list_reminders` / `search_reminders`, so no raw `EKReminder` escapes the
/// manager actor. The fake records the `completed` filter the handler asks for.
private actor RecordingReminderReadFake: ReminderReadSource {
    let values: [ReminderReadSnapshot]
    private(set) var completedFilters: [Bool?] = []
    init(_ values: [ReminderReadSnapshot]) { self.values = values }
    func listReminderSnapshots(completed: Bool?, calendarName: String?, calendarSource: String?) async throws -> [ReminderReadSnapshot] {
        completedFilters.append(completed); return values
    }
    func searchReminderSnapshots(keywords: [String], matchMode: String, calendarName: String?, calendarSource: String?, completed: Bool?) async throws -> [ReminderReadSnapshot] { values }
}

final class ListReminderTagsHandlerTests: XCTestCase {
    private func records() -> [ReminderReadSnapshot] {
        // Tags live on a trailing line made only of #hashtags (extractTags); an
        // inline "#" in prose is not a tag, so "d" contributes nothing.
        [ReminderReadSnapshot(id: "a", title: "A", notes: "Buy milk\n#home #errand"),
         ReminderReadSnapshot(id: "b", title: "B", notes: "Ship release\n#work"),
         ReminderReadSnapshot(id: "c", title: "C", notes: "Call mom\n#home", isCompleted: true),
         ReminderReadSnapshot(id: "d", title: "D", notes: "Ticket #42 is not a tag")]
    }

    func testTagsAreCountedFromSnapshotNotesAndSortedByCountThenName() async throws {
        let fake = RecordingReminderReadFake(records())
        let server = try await CheICalMCPServer(reminderReadSource: fake)
        let raw = try await server.executeToolCall(name: "list_reminder_tags", arguments: [:])
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
        XCTAssertEqual(json["total_reminders_scanned"] as? Int, 4)
        XCTAssertEqual(json["total_tags"] as? Int, 3)
        let tags = try XCTUnwrap(json["tags"] as? [[String: Any]])
        XCTAssertEqual(tags.map { $0["tag"] as? String }, ["home", "errand", "work"])
        XCTAssertEqual(tags.map { $0["count"] as? Int }, [2, 1, 1])
    }

    func testIncludeCompletedMapsToTheSeamFilter() async throws {
        let fake = RecordingReminderReadFake(records())
        let server = try await CheICalMCPServer(reminderReadSource: fake)
        _ = try await server.executeToolCall(name: "list_reminder_tags", arguments: [:])
        _ = try await server.executeToolCall(name: "list_reminder_tags", arguments: ["include_completed": .bool(true)])
        let filters = await fake.completedFilters
        XCTAssertEqual(filters.count, 2)
        XCTAssertEqual(filters[0], false, "default excludes completed reminders")
        XCTAssertNil(filters[1], "include_completed: true asks the seam for every reminder")
    }
}
