## ADDED Requirements

### Requirement: Correction selection by sender identity and parsable time

When a source is a message thread, the skill SHALL determine the authoritative event time by walking the thread from the newest message backwards and selecting the first message that satisfies BOTH of the following: (a) its sender matches the sender of the original notice, and (b) its body contains a parsable date-time. The skill SHALL NOT select by recency alone, and SHALL NOT rely on a keyword list such as "correction" or "rescheduled".

When no message satisfies both conditions, the skill SHALL NOT infer a time. It SHALL present the candidate messages and ask the operator to choose.

#### Scenario: A later reply without a time does not override the organizer's correction

- **WHEN** a thread contains, in chronological order: (1) an organizer notice for Aug 12 14:00, (2) a non-organizer message proposing "shall we push it later" with no specific time, (3) an organizer message stating a new time of Aug 13 15:30, and (4) an attendee reply "noted, thank you"
- **THEN** the skill selects message (3) as authoritative
- **AND** the resulting event starts Aug 13 15:30

##### Example: Backward walk over the four messages

| Step | Message | Sender matches original? | Contains parsable time? | Selected |
|---|---|---|---|---|
| 1 | (4) attendee reply | no | no | no |
| 2 | (3) organizer new time | yes | yes | **yes — stop** |

Messages (1) and (2) are never examined; the walk stops at the first message satisfying both conditions.

#### Scenario: Neither condition is satisfiable, so the operator decides

- **WHEN** the only message containing a parsable time was sent from an address that differs from the original notice sender
- **THEN** the skill does not create or update an event from an inferred time
- **AND** it lists the candidate messages with their senders and times, and asks the operator which is authoritative

### Requirement: Re-archiving a corrected source updates the existing event

The skill SHALL record a source identifier in the event notes when the source provides one. Before creating an event, the skill SHALL search for an existing event carrying the same source identifier. When found, the skill SHALL update that event rather than create a second one. When not found, the skill SHALL create a new event.

When the source provides no stable identifier, the skill SHALL fall back to the existing create-time idempotency behavior and SHALL state in its report that corrections to this source cannot be tracked.

#### Scenario: A rescheduled meeting updates rather than duplicates

- **WHEN** an event was archived from a source and later the same source is re-archived with a corrected time on a different day
- **THEN** the skill locates the existing event by its recorded source identifier
- **AND** updates that event's start and end times
- **AND** the calendar contains exactly one event for this source

##### Example: Why start-time matching is insufficient

The create-time idempotency key is (title, start time within 30 seconds, calendar). After a reschedule from Aug 12 14:00 to Aug 13 15:30, the start time no longer matches, so that key treats the corrected event as new — leaving the superseded event in place. Matching on the source identifier is unaffected by the time change.

#### Scenario: A source without an identifier is archived

- **WHEN** the source is a verbal account or a screenshot with no message identifier
- **THEN** the skill creates the event using existing create-time behavior
- **AND** its report states that later corrections to this source will not be detected

### Requirement: Estimated field values are labelled in the event notes

When any event field is not stated by the source and the skill supplies a value, the skill SHALL write an estimate line into the event notes stating the estimated value, the basis for the estimate, and that the source did not state it. This labelling SHALL NOT be optional or configurable.

When every field is taken from the source, the skill SHALL omit the estimate line entirely rather than emit an empty or placeholder line.

#### Scenario: An unstated end time is estimated and labelled

- **WHEN** a notice states a meeting on Aug 13 at 15:30 in room 2008 with no end time, and the two most recent events of the same kind on the target calendar each lasted two hours
- **THEN** the created event runs 15:30 to 17:30
- **AND** the notes contain an estimate line naming the estimated end time, the basis (duration of prior events of the same kind on this calendar), and that the source did not state it

##### Example: Notes content for this event

```
來源：<sender> <date>「<subject>」
推估：結束時間 17:30（沿用同行事曆前次同類活動時長；通知未載明）
```

#### Scenario: A fully specified source produces no estimate line

- **WHEN** the source states both start and end times, the location, and the title
- **THEN** the notes contain the source line
- **AND** the notes contain no estimate line

### Requirement: Archived events carry a source citation

The skill SHALL write a source line into the event notes identifying the sender, the date, and the subject or title of the source, so that the basis for the event can be recovered later without access to the conversation in which it was archived.

#### Scenario: The source of an event is recoverable months later

- **WHEN** an operator opens an archived event in Calendar
- **THEN** the notes state which message the event came from, who sent it, and when

### Requirement: Same-day deadlines are surfaced after archiving

After creating or updating an event, the skill SHALL check the calendar and reminder stores for other deadlines falling on the same day and SHALL list any found in its report.

The skill SHALL confine this check to calendar events and reminders. It SHALL NOT claim coverage of deadlines held in other systems.

#### Scenario: A report submission deadline on the meeting day is surfaced

- **WHEN** an event is archived for Aug 11 and a reminder with a due date of Aug 11 already exists
- **THEN** the skill's report lists that reminder alongside the archiving result

### Requirement: Project-level configuration and archive state

The skill SHALL honor an optional `.claude/.ical/config.yaml` (human-authored YAML; v1 field: `default_calendar`) and SHALL maintain `.claude/.ical/state/archives.json`, a machine-queried map from source identifier to the archived event (`event_id`, `calendar`, `archived_at`). Missing files are not errors: an absent config falls back to derivation-then-ask for calendar choice; an absent state file makes the index lookup a miss, falling back to the notes search, and is created on the next successful archive. A malformed file SHALL be reported in the run's output and treated as absent — never silently swallowed.

#### Scenario: The config names a default calendar

- **GIVEN** `.claude/.ical/config.yaml` contains `default_calendar: "行政"`
- **WHEN** a source is archived
- **THEN** the event is created in 行政 without a calendar question

#### Scenario: No config file exists

- **GIVEN** the project has no `.claude/.ical/` directory
- **WHEN** a source is archived
- **THEN** calendar choice falls back to derivation (prior filings of the same kind), then to asking — and no error is raised

#### Scenario: The state index already maps this source

- **GIVEN** `state/archives.json` maps the mail's Message-ID to an event
- **WHEN** the corrected source is re-archived
- **THEN** the mapped event is updated directly, without searching event notes

#### Scenario: A malformed config is reported, not swallowed

- **GIVEN** `config.yaml` fails to parse
- **WHEN** a source is archived
- **THEN** the report carries an explicit warning and behavior proceeds as if the file were absent
