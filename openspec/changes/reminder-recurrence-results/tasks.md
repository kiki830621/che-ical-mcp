- [x] [P] Implement recurrence/due value serializers and their unit tests in ReminderRecurrence.swift and ReminderRecurrenceTests.swift.
- [x] [P] Implement immutable completion response types, pure successor decision and their unit tests in ReminderCompletion.swift and ReminderCompletionTests.swift.
- [x] Integrate read metadata, completion manager/source and handler/dispatch tests.
- [-] Guard recurring undo/redo against occurrence identity drift — split into PR #200 after review (rows 1, 8, 9, 18 of the round-1 report).
- [x] Update README examples and change notes; inspect diff and macOS CI results.

macOS CI on the review head `44b0e6a` built and ran 559 tests with 0 failures (run 34066416502; the earlier Lord Howe half-hour DST fold assertion was fixed by the alternate-offset round-trip guard). Review of PR #195 drove: a single synchronous post-save observation (no polling, no observation token), `frequency_raw_value` on the wire, the observed next-occurrence date in the completion message (reminder-local wall clock), `observed` in every completion response, `null` rules for recurring items with empty rules, and the undo guard (PR #200) + strict-boolean input (PR #201) split out. On-device (iCloud, daily rule, 2026-09-07): synchronous observation returned `confirmed`; the same ID advanced in place and a separate completed record appeared under a new ID.
