import Observation

/// The collection task currently on screen, or `nil` when no collection is open.
///
/// A separate, deliberately tiny fact rather than a window onto the wheel's own
/// state. The orbit has plenty of live state that means nothing outside itself —
/// rotation, drag velocity, the settle epoch — and the one thing that does mean
/// something is which task a person is looking at right now. That is what the
/// ambient player's complete control acts on, and it is the only thing it needs.
///
/// The invariant that keeps this honest: `task` is non-`nil` exactly while a
/// collection is open. It is set when a card expands and cleared the moment it
/// collapses, so a completion can never outlive the card it was made from.
@MainActor @Observable
final class CollectionFocus {
    /// The open collection's visible task.
    var task: CollectionTask.ID?
}
