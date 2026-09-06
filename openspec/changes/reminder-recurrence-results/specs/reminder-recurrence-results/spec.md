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

The completion result SHALL contain next_occurrence with confirmed, unknown or not_applicable status. confirmed SHALL require an observed, same-identity incomplete reminder with a valid later due date and matching recurrence/calendar. The observation SHALL be taken once, synchronously, from the saved object before any suspension point; the handler SHALL NOT poll or force a refresh. Missing, ambiguous or unchanged observations SHALL be unknown. A failed observation SHALL NOT repeat the write or report the successful write as failed.

#### Scenario: No successor can be identified
- WHEN completion saves successfully but the known ID cannot identify a successor
- THEN next_occurrence.status is unknown and operation.status remains succeeded.
