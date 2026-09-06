- [x] [P] Implement recurrence/due value serializers and their unit tests in ReminderRecurrence.swift and ReminderRecurrenceTests.swift.
- [x] [P] Implement immutable completion response types, pure successor decision and their unit tests in ReminderCompletion.swift and ReminderCompletionTests.swift.
- [x] Integrate read metadata, completion manager/source and handler/dispatch tests.
- [-] Guard recurring undo/redo against occurrence identity drift — split into a separate PR after verify round 1 (report rows 1, 8, 9, 18).
- [x] Update README examples and change notes; inspect diff and macOS CI results.

macOS CI on `35ca8e7` built and ran 564 tests with 0 failures (the Lord Howe half-hour DST fold assertion was fixed by the alternate-offset round-trip guard). Verify round 1 on PR #195 then drove: a single synchronous post-save observation (no polling, no observation token), `frequency_raw_value` on the wire, the observed next-occurrence date in the completion message, and the undo guard + strict-boolean input split into separate PRs. On-device (iCloud, daily rule, 2026-09-07): synchronous observation returned `confirmed`; the same ID advanced in place and a separate completed record appeared under a new ID.
