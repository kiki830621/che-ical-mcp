# Reminder recurrence and completion results (#194)

`list_reminders` and `search_reminders` now return these additive fields:

| Field | Meaning |
| --- | --- |
| `has_recurrence` | Whether the observed reminder currently carries recurrence rules. This does not promise another occurrence exists. |
| `recurrence_rules` | All public EventKit rules; `[]` for non-recurring items, `null` when a recurring item's rules are unavailable. |
| `due` | `date`, `time`, `timezone`, `calendar_identifier`, `date_time`; null when no complete calendar date is available. |

Rule objects include `frequency`, `interval`, `calendar_identifier`, `first_day_of_week`, `days_of_week`, `days_of_week_details` (objects with `day` and `week_number`), `days_of_month`, `months_of_year`, `weeks_of_year`, `days_of_year`, `set_positions`, `end_date`, and `occurrence_count`. Unspecified selectors are null. `frequency_raw_value` is included for an unknown future frequency. Weekdays use 1=Sunday through 7=Saturday; a negative ordinal is preserved. `occurrence_count` is the rule's limit, not remaining occurrences. This read format is richer than the existing recurrence input format; it is not a promise of lossless write-back.

`due.date_time` is an ISO 8601 UTC instant only for a valid, unambiguous date with explicit time and timezone. Date-only reminders retain the date and null time/instant. Floating reminders retain wall-clock values with null timezone/instant. DST gaps and folds do not invent an instant. Legacy `due_date`, `_local`, count, sorting and filtering behavior remain unchanged.

## Completing and reopening

Read `operation.status`, not legacy `is_completed`, to determine whether the write succeeded. EventKit may advance a repeating item to an incomplete occurrence after saving completion. The write and the observed state are different facts.

```json
{
  "action": "completed",
  "id": "reminder-123",
  "title": "Read",
  "is_completed": false,
  "has_recurrence": true,
  "operation": {
    "type": "complete",
    "status": "succeeded",
    "requested_completed": true,
    "target": {"id": "reminder-123", "due": null, "was_completed": false}
  },
  "next_occurrence": {
    "status": "unknown",
    "reason": "due_not_comparable",
    "reminder": null
  },
  "message": "This occurrence was completed successfully. The next occurrence could not be confirmed."
}
```

The example is illustrative. `has_recurrence` and `operation.target` capture the item **before** mutation. `is_completed` and `title` retain the saved object's values. `completed=false` produces `operation.type="reopen"` and `next_occurrence.status="not_applicable"`; legacy `action="completed"` is intentionally preserved for existing clients. A non-boolean `completed` currently falls back to the legacy default (`true`); rejecting it is a breaking change tracked in a separate PR.

| Next status | Contract |
| --- | --- |
| `confirmed` | The same ID/list/source was observed as incomplete with unchanged known recurrence rules and a strictly later comparable due date. `reminder` contains the observed item, including `id` and `due`, and `message` reads `Next occurrence: <date or instant>`. |
| `unknown` | The ID changed/disappeared, rules/due cannot be compared, or the record has not advanced. `reminder` is null and `reason` explains why. |
| `not_applicable` | Non-recurring item, reopening, or an already-completed target. `reminder` is null. |

The resolver observes the saved object exactly once, synchronously, before the handler suspends: EventKit advances a recurring reminder in place during `save`, so that read already reflects the successor. It does not poll, force cloud sync, call `reset`, or use title/external-ID guesses — a later read of the cached store could only reflect what another writer did, so it would misattribute a concurrent edit as this call's successor. The observation is local to this process's cached store; an edit made concurrently by Reminders.app or another device is not visible to it. It deliberately does not emit `none`: absence alone cannot prove a recurring series ended. Different-ID successors and sources without reliable observable identity remain `unknown`. A confirmed result is a best-effort local observation, not a cross-device transactional guarantee. A next occurrence can still be overdue.

**An unknown next occurrence is not a failed completion. Do not repeat the write.** Only save failures use the MCP error path. Existing ID-only writes do not guarantee exactly-once behavior on client/transport retries; an ID may already refer to a later occurrence.

Undo of a completion uses the existing single-reminder record: it reverts `is_completed` on whatever the ID resolves to now, which for an advanced recurring reminder is the next occurrence. An occurrence-identity-guarded undo for recurring completions is tracked in a separate PR.

The MCP response remains JSON in text content; this change does not migrate to MCP `structuredContent`. Clients rejecting unknown fields must update their decoders. Clients that read only the old `is_completed` field must migrate to `operation` to distinguish successful completion from successor state.

## Verification

Unit tests cover recurrence/date serialization, DST and the successor decision. Injected handler/dispatch tests cover the actual JSON envelope, count semantics and reopening. macOS CI compiles and runs the suite. Live iCloud/local/Exchange rollover and identifier behavior need a signed, authorized macOS session and are not proven by fake tests. Verify the running binary version before those checks; use the same MCP session for undo/redo.

References: [issue #194](https://github.com/PsychQuant/che-ical-mcp/issues/194), [Apple recurrence guide](https://developer.apple.com/documentation/eventkit/creating-a-recurring-event), [Apple due components](https://developer.apple.com/documentation/eventkit/ekreminder/duedatecomponents).
