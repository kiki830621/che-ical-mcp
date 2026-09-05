- [x] [P] Implement recurrence/due value serializers and their unit tests in ReminderRecurrence.swift and ReminderRecurrenceTests.swift.
- [x] [P] Implement immutable completion response types, pure successor decision and their unit tests in ReminderCompletion.swift and ReminderCompletionTests.swift.
- [x] Integrate read metadata, completion manager/source and handler/dispatch tests.
- [x] Guard recurring undo/redo against occurrence identity drift and test the guard.
- [x] Update README examples and change notes; inspect diff and macOS CI results.

Initial macOS CI built successfully and ran 564 tests; one Lord Howe half-hour DST fold assertion failed. Added an alternate-offset round-trip guard; follow-up macOS CI validation is pending.
