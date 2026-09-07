import EventKit
import XCTest
@testable import CheICalMCP

/// Completion undo records are value-only; no EventKitManager instance or TCC.
final class ReminderCompletionUndoTests: XCTestCase {
    private func snapshot(title: String = "Daily reminder", completed: Bool = false) -> ReminderCompletionSnapshot {
        ReminderCompletionSnapshot(
            id: "recurring-194", title: title, calendarID: "calendar",
            sourceID: "source", isCompleted: completed, hasRecurrence: true,
            due: nil, rules: []
        )
    }

    func testLegacyCompletionConstructorAndDescriptionRemainAvailable() {
        let operation = UndoOperation.completeReminder(id: "once", wasCompleted: false, title: "Once")
        XCTAssertEqual(operation.description, "Completed reminder: Once")
    }

    func testHistoryDescriptionDistinguishesCompletionAndReopen() {
        let before = snapshot()
        XCTAssertEqual(
            UndoOperation.completeRecurringReminder(before: before, requestedCompleted: true).description,
            "Completed recurring reminder: Daily reminder")
        XCTAssertEqual(
            UndoOperation.completeRecurringReminder(before: before, requestedCompleted: false).description,
            "Reopened recurring reminder: Daily reminder")
    }

    func testHistoryDescriptionSanitizesUserControlledTitle() {
        let title = "Reminder\nForged log\r\t\u{001B}[31m"
        let operation = UndoOperation.completeRecurringReminder(before: snapshot(title: title), requestedCompleted: true)
        XCTAssertEqual(operation.description,
                       "Completed recurring reminder: \(EventKitErrorSanitizer.sanitizeForInterpolation(title))")
        XCTAssertFalse(operation.description.contains("\n"))
        XCTAssertFalse(operation.description.contains("\u{001B}"))
    }

    func testRecordPreservesRequestedStateForIdempotentCompletion() {
        let before = snapshot(completed: true)
        let record = UndoRecord(.completeRecurringReminder(before: before, requestedCompleted: true))
        guard case .completeRecurringReminder(let saved, let requested) = record.operation else {
            return XCTFail("Expected recurring completion record")
        }
        XCTAssertEqual(saved, before)
        XCTAssertTrue(requested)
    }

    func testDiscardFailedUndoDropsTheRecordAndKeepsOlderEntriesReachable() async {
        // Verify round 1, row 1: a permanently un-undoable record re-appended by
        // restoreFailedUndo blocks every older entry forever. Discarding it must
        // leave the older entry on top and must not resurrect it on the redo stack.
        let manager = CalendarUndoManager()
        await manager.record(.completeReminder(id: "older", wasCompleted: false, title: "Older"))
        await manager.record(.completeRecurringReminder(before: snapshot(), requestedCompleted: true))
        guard let popped = await manager.popUndo() else { return XCTFail("expected a record") }
        await manager.discardFailedUndo(popped)
        let descriptions = await manager.history().map(\.description)
        XCTAssertEqual(descriptions, ["Completed reminder: Older"])
        let canRedo = await manager.canRedo
        XCTAssertFalse(canRedo)
        guard case .completeReminder(let id, _, _, _)? = await manager.popUndo()?.operation else {
            return XCTFail("the older record must be the next undo target")
        }
        XCTAssertEqual(id, "older")
    }

    func testUndoFailureDispositionDiscardsOnlyUnrecoverableErrors() {
        XCTAssertEqual(UndoFailureDisposition.of(UnrecoverableUndoError(message: "gone")), .discard)
        XCTAssertEqual(UndoFailureDisposition.of(ToolError.invalidParameter("transient")), .restore)
        XCTAssertEqual(UndoFailureDisposition.of(EventKitError.reminderNotFound(identifier: "x")), .restore)
        XCTAssertEqual(UnrecoverableUndoError(message: "gone").errorDescription, "gone")
    }

    func testCompletionRecordFallsBackToLegacyWhenTheSnapshotIsNotIdentifiable() {
        // A guarded record that can never match again (no comparable due, no known
        // rules) would be discarded on its first undo with a misleading reason; the
        // legacy identifier-keyed record still restores such an unchanged item.
        let daily = ReminderRecurrenceRuleValue(from: EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil))
        let identifiable = ReminderCompletionSnapshot(
            id: "r", title: "t", calendarID: "c", sourceID: "s", isCompleted: false, hasRecurrence: true,
            due: ReminderDueValue(components: DateComponents(year: 2026, month: 9, day: 5)), rules: [daily])
        guard case .completeRecurringReminder = UndoOperation.forCompletion(before: identifiable, requestedCompleted: true, savedTitle: "t") else {
            return XCTFail("identifiable recurring snapshot must get the guarded record")
        }
        guard case .completeReminder(let id, let wasCompleted, _, let title) = UndoOperation.forCompletion(before: snapshot(), requestedCompleted: true, savedTitle: "Saved") else {
            return XCTFail("non-identifiable recurring snapshot must fall back to the legacy record")
        }
        XCTAssertEqual(id, "recurring-194"); XCTAssertFalse(wasCompleted); XCTAssertEqual(title, "Saved")
        let oneOff = ReminderCompletionSnapshot(id: "o", title: "t", calendarID: "c", sourceID: "s", isCompleted: true, hasRecurrence: false, due: nil, rules: [])
        guard case .completeReminder(_, let was, _, _) = UndoOperation.forCompletion(before: oneOff, requestedCompleted: false, savedTitle: "t") else {
            return XCTFail("one-off reminder must use the legacy record")
        }
        XCTAssertTrue(was)
    }

    func testUnrecoverableUndoErrorMessageSurvivesResponseSanitization() {
        // The whole point of the permanent-failure path is the explicit message; an
        // untrusted error type is flattened to `error_unknown` on the wire.
        let sanitized = EventKitErrorSanitizer.sanitizeForResponse(UnrecoverableUndoError(message: "entry discarded; reopen explicitly"))
        XCTAssertEqual(sanitized.code, "entry discarded; reopen explicitly")
    }

    func testDiscardFailedUndoOnlyDropsTheRecordItWasHanded() async {
        // A contract slip (discard called for a record that is not the one just
        // popped) must not destroy an unrelated entry.
        let manager = CalendarUndoManager()
        await manager.record(.completeReminder(id: "a", wasCompleted: false, title: "A"))
        await manager.record(.completeReminder(id: "b", wasCompleted: false, title: "B"))
        guard let poppedB = await manager.popUndo() else { return XCTFail("expected b") }
        let unrelated = UndoRecord(.completeReminder(id: "zzz", wasCompleted: false, title: "Z"))
        await manager.discardFailedUndo(unrelated)
        let canRedo = await manager.canRedo
        XCTAssertTrue(canRedo, "b must still be on the redo stack — the unrelated record was not the popped one")
        await manager.discardFailedUndo(poppedB)
        let canRedoAfter = await manager.canRedo
        XCTAssertFalse(canRedoAfter)
    }

    // MARK: - #196 the completion instant is part of the record

    private static let recordedCompletion = Date(timeIntervalSince1970: 1_756_900_000)

    private func completedOneOff() -> ReminderCompletionSnapshot {
        ReminderCompletionSnapshot(
            id: "one-off", title: "Once", calendarID: "calendar", sourceID: "source",
            isCompleted: true, hasRecurrence: false, due: nil, rules: [],
            completionDate: Self.recordedCompletion)
    }

    func testSnapshotCarriesTheRecordedCompletionDate() {
        XCTAssertEqual(completedOneOff().completionDate, Self.recordedCompletion)
        XCTAssertNil(snapshot().completionDate, "an incomplete snapshot records no completion instant")
    }

    func testForCompletionThreadsTheCompletionDateIntoTheLegacyRecord() {
        guard case .completeReminder(_, let wasCompleted, let recorded, _) =
                UndoOperation.forCompletion(before: completedOneOff(), requestedCompleted: false, savedTitle: "Once") else {
            return XCTFail("one-off items use the legacy record")
        }
        XCTAssertTrue(wasCompleted)
        XCTAssertEqual(recorded, Self.recordedCompletion)
    }

    func testForCompletionKeepsTheCompletionDateOnTheRecurringRecord() {
        let daily = ReminderRecurrenceRuleValue(from: EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil))
        let due = ReminderDueValue(components: DateComponents(year: 2026, month: 9, day: 6))
        let before = ReminderCompletionSnapshot(
            id: "recurring-196", title: "Daily", calendarID: "calendar", sourceID: "source",
            isCompleted: true, hasRecurrence: true, due: due, rules: [daily],
            completionDate: Self.recordedCompletion)
        guard case .completeRecurringReminder(let recorded, _) =
                UndoOperation.forCompletion(before: before, requestedCompleted: false, savedTitle: "Daily") else {
            return XCTFail("identifiable recurring items use the guarded record")
        }
        XCTAssertEqual(recorded.completionDate, Self.recordedCompletion)
        // Completion state is not occurrence identity: the same occurrence without
        // a completion instant is a different value but the same occurrence.
        let reopened = ReminderCompletionSnapshot(
            id: "recurring-196", title: "Daily", calendarID: "calendar", sourceID: "source",
            isCompleted: false, hasRecurrence: true, due: due, rules: [daily])
        XCTAssertNotEqual(before, reopened)
        XCTAssertTrue(before.matchesOccurrence(reopened))
    }
}
