import Foundation

/// Resolves the target of a reminder history entry and classifies a miss (#206).
///
/// `lookup` must be a real store fetch (the manager uses `fetchReminders`, not the
/// in-memory `calendarItem(withIdentifier:)` cache, so hits are fresh too). A miss is
/// given one `refresh` and a second fetch; a miss that survives both is reported as
/// `NotFound`. EventKit cannot positively confirm a deletion — the same result is
/// produced by a move to another account (which re-identifies the item) or by an
/// account that is temporarily unavailable — so the message the manager builds from
/// `NotFound` names the entry and lists those possibilities rather than asserting one.
///
/// Pure and generic: the closures are the store (closure seam, #182). Errors thrown
/// by `lookup` itself propagate unchanged and stay transient (`.restore`).
enum ReminderUndoLookup {
    struct NotFound: Error, Equatable { let id: String }

    static func resolve<Item>(id: String,
                              lookup: (String) async throws -> Item?,
                              refresh: () async throws -> Void) async throws -> Item {
        if let item = try await lookup(id) { return item }
        try await refresh()
        if let item = try await lookup(id) { return item }
        throw NotFound(id: id)
    }

    /// The permanent, discard-classified error for a `NotFound`. `title` is a
    /// store-derived value and is sanitized here; `id` and `verb` are sanitized too so
    /// the `TrustedErrorMessage` invariant on `UnrecoverableUndoError` holds locally.
    static func permanentError(for missing: NotFound, title: String, verb: String) -> UnrecoverableUndoError {
        let safeTitle = EventKitErrorSanitizer.sanitizeForInterpolation(title)
        let safeID = EventKitErrorSanitizer.sanitizeForInterpolation(missing.id)
        let safeVerb = EventKitErrorSanitizer.sanitizeForInterpolation(verb)
        return UnrecoverableUndoError(message: "Cannot \(safeVerb) '\(safeTitle)' (\(safeID)): the reminder could not be found in the store under that identifier, even after refreshing its sources. It was deleted, moved to another account (which assigns a new identifier), or its account is currently unavailable. This history entry was discarded so the rest of the history stays reachable.")
    }
}
