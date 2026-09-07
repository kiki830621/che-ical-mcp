import Foundation

/// Resolves the target of a reminder history entry and classifies a miss (#206).
///
/// A miss on the first lookup may be store lag, so the store is refreshed and the
/// lookup repeated once; a miss that survives the refresh is treated as a deletion
/// and surfaces as `UnrecoverableUndoError`, which `UndoFailureDisposition` maps to
/// `.discard` — the entry is dropped so every older entry stays reachable instead of
/// jamming the stack head forever (#191 kept every not-found as transient).
///
/// Pure and generic: the closures are the store (closure seam, #182). Errors thrown
/// by `lookup` itself propagate unchanged and stay transient.
enum ReminderUndoLookup {
    static func resolve<Item>(id: String, what: String,
                              lookup: (String) throws -> Item?,
                              refresh: () throws -> Void) throws -> Item {
        if let item = try lookup(id) { return item }
        try refresh()
        if let item = try lookup(id) { return item }
        throw UnrecoverableUndoError(message: "Cannot find the \(what) this history entry refers to even after refreshing the store — it was deleted since. This history entry was discarded so earlier operations remain undoable.")
    }
}
