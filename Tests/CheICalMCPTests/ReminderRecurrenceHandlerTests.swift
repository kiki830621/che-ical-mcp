import Foundation
import MCP
import XCTest
@testable import CheICalMCP

private actor ReminderReadFake: ReminderReadSource {
    let values: [ReminderReadSnapshot]
    init(_ values: [ReminderReadSnapshot]) { self.values = values }
    func listReminderSnapshots(completed: Bool?, calendarName: String?, calendarSource: String?) async throws -> [ReminderReadSnapshot] { values }
    func searchReminderSnapshots(keywords: [String], matchMode: String, calendarName: String?, calendarSource: String?, completed: Bool?) async throws -> [ReminderReadSnapshot] { values }
}

final class ReminderRecurrenceHandlerTests: XCTestCase {
    private func records() -> [ReminderReadSnapshot] {
        [ReminderReadSnapshot(id: "one", title: "Once", hasRecurrence: false),
         ReminderReadSnapshot(id: "repeat", title: "Repeat", hasRecurrence: true)]
    }

    func testListPreservesPreLimitCountAndAddsMetadata() async throws {
        let server = try await CheICalMCPServer(reminderReadSource: ReminderReadFake(records()))
        let raw = try await server.executeToolCall(name: "list_reminders", arguments: ["limit": .int(1), "sort": .string("title")])
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
        XCTAssertEqual(json["reminder_count"] as? Int, 2)
        let items = try XCTUnwrap(json["reminders"] as? [[String: Any]])
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0]["has_recurrence"] as? Bool, false)
        XCTAssertEqual((items[0]["recurrence_rules"] as? [Any])?.count, 0)
        XCTAssertTrue(items[0]["due"] is NSNull)
        XCTAssertNotNil(json["metadata"])
        XCTAssertEqual(items[0]["is_completed"] as? Bool, false)
    }

    func testSearchUsesSameMetadataWithoutAddingListOnlyFields() async throws {
        let server = try await CheICalMCPServer(reminderReadSource: ReminderReadFake(records()))
        let raw = try await server.executeToolCall(name: "search_reminders", arguments: ["keyword": .string("anything")])
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
        let items = try XCTUnwrap(json["reminders"] as? [[String: Any]])
        XCTAssertEqual(json["reminder_count"] as? Int, 2)
        XCTAssertEqual(items[1]["has_recurrence"] as? Bool, true)
        XCTAssertTrue(items[1]["recurrence_rules"] is NSNull)
        XCTAssertNil(items[1]["creation_date"])
        XCTAssertNil(items[1]["is_overdue"])
        XCTAssertEqual(json["match_mode"] as? String, "any")
    }
}
