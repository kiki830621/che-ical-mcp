## ADDED Requirements

### Requirement: Read recurrence metadata without changing legacy fields

The list and search reminder handlers SHALL emit has_recurrence, recurrence_rules and due. Rules SHALL retain ordinal weekdays, all public integer selectors and termination constraints. Existing event output and reminder envelopes SHALL remain unchanged.

#### Scenario: Last Monday of each month
- WHEN a rule uses Monday with weekNumber -1
- THEN the output retains both the weekday and its negative ordinal.

#### Scenario: Floating or date-only due date
- WHEN the due components do not specify a timezone or time
- THEN due.date_time is null and available wall-clock components are retained.

### Requirement: Separate write outcome from observed reminder state

A successful save SHALL return operation.status succeeded even when the returned reminder is incomplete. The handler SHALL preserve legacy action and is_completed semantics. Reopening SHALL be identified by operation.type reopen.

#### Scenario: Recurring reminder advances on save
- WHEN a save succeeds and its object advances to an incomplete occurrence
- THEN the response reports the completed operation independently of that object's state.

### Requirement: Report only observed successors

The completion result SHALL contain next_occurrence with confirmed, unknown or not_applicable status. confirmed SHALL require an observed, same-identity incomplete reminder with a valid later due date and matching recurrence/calendar. Missing, ambiguous, concurrent or unchanged observations SHALL be unknown. A failed observation SHALL NOT repeat the write or report the successful write as failed.

#### Scenario: No successor can be identified
- WHEN completion saves successfully but the known ID cannot identify a successor
- THEN next_occurrence.status is unknown and operation.status remains succeeded.

### Requirement: Protect recurring undo targets

Undo and redo SHALL reject a recurring completion record when the current reminder no longer matches the recorded occurrence identity. A failed undo SHALL retain its history entry.

#### Scenario: Original ID now refers to a later due date
- WHEN undo resolves the same ID with different due components
- THEN it refuses to mutate that next occurrence.
