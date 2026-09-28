import SwiftUI

/// The smallest thing a person can complete: one task inside a `Collection`.
///
/// Identical in kind to `Collection`, and never interchangeable with it — the two
/// identities are distinct types on purpose, so a collection can never be
/// passed where a task is expected.
struct CollectionTask: Identifiable, Equatable, Sendable {
    /// A stable, hand-written identifier, namespaced by its collection.
    ///
    /// The prefix is load-bearing, not decoration: `space.beauty` and
    /// `joy.beauty` are two different tasks that happen to share a title, so a
    /// bare `beauty` would collide. This value is the key a completion is filed
    /// under in the keychain, so it must never change once written — renaming a
    /// task's *text* is free, renaming this is a data migration.
    struct ID: Hashable, Sendable, CustomStringConvertible {
        let rawValue: String

        init(_ rawValue: String) {
            self.rawValue = rawValue
        }

        var description: String { rawValue }
    }

    let id: ID
    /// A short label — the task's name on its own. Used where the instruction
    /// would be too much: VoiceOver, the completed list in Memory.
    let title: LocalizedStringResource
    /// The instruction itself: the sentence that tells you what to actually do.
    let instruction: LocalizedStringResource
    /// A pictogram standing in for the task. A `String` rather than an SF Symbol
    /// name because emoji need no asset and carry their own colour and weight.
    ///
    /// Emoji do not scale on their own, so whatever draws one is responsible for
    /// sizing it with `@ScaledMetric` — a fixed point size here would be the one
    /// part of a task that ignores Dynamic Type. Swapping the catalog wholesale
    /// to SF Symbols is a one-line change if that trade is ever revisited.
    let symbol: String
}
