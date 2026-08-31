import Foundation

/// Failure modes of the two-pass exclusion sequence (#182).
/// Neutral on purpose — `EventKitManager` maps these onto `EventKitError`
/// with formatted dates and the master event ID.
enum ExclusionExecutionError: Error {
    /// Pass 1: a date resolved to no occurrence. Rollback succeeded — no partial state.
    case noOccurrence(Date)
    /// Pass 2: removing an occurrence failed. Rollback succeeded — no partial state.
    case removeFailed(Date)
    /// Rollback itself failed: the series still exists with `appliedDates` exclusions applied.
    case rollbackFailed(appliedDates: [Date])
}

/// Two-pass exclusion sequencing core.
///
/// Pass 1 resolves EVERY date before pass 2 removes ANY occurrence, so a
/// non-matching date aborts while the store is still in the "series just
/// created, nothing removed" state. Every failure path invokes `rollback`
/// (compensating delete of the whole series); a rollback failure supersedes
/// the original error and carries the exclusions already applied, because at
/// that point partial state exists and MUST be reported, never swallowed.
enum ExclusionExecutor {
    static func run<Occurrence>(
        dates: [Date],
        resolve: (Date) -> Occurrence?,
        remove: (Occurrence) throws -> Void,
        rollback: () throws -> Void
    ) throws -> [Date] {
        guard !dates.isEmpty else { return [] }

        // PASS 1 — resolve everything up front.
        var resolved: [(date: Date, occurrence: Occurrence)] = []
        for date in dates {
            guard let occurrence = resolve(date) else {
                try runRollback(rollback, applied: [])
                throw ExclusionExecutionError.noOccurrence(date)
            }
            resolved.append((date, occurrence))
        }

        // PASS 2 — remove, tracking what has been applied for rollback reporting.
        var applied: [Date] = []
        for (date, occurrence) in resolved {
            do {
                try remove(occurrence)
            } catch {
                try runRollback(rollback, applied: applied)
                throw ExclusionExecutionError.removeFailed(date)
            }
            applied.append(date)
        }
        return applied
    }

    private static func runRollback(_ rollback: () throws -> Void, applied: [Date]) throws {
        do {
            try rollback()
        } catch {
            throw ExclusionExecutionError.rollbackFailed(appliedDates: applied)
        }
    }
}
