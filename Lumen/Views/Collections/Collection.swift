import SwiftUI

/// One themed group of tasks — a single spoke of the wheel.
///
/// Immutable and value-typed: the catalog is a `static let`, so a collection's
/// contents can never change while a view holds one.
struct Collection: Identifiable, Equatable, Sendable {
    /// A stable, hand-written identifier such as `self` or `kitchen`.
    ///
    /// Written by hand rather than generated. It outlives the process, the
    /// catalog's ordering, and the device, so anything persisted or synced can
    /// key off it. Never widen this to a `UUID`: a generated identity is
    /// different on every launch, which makes persistence impossible by
    /// construction.
    struct ID: Hashable, Sendable, CustomStringConvertible {
        let rawValue: String

        init(_ rawValue: String) {
            self.rawValue = rawValue
        }

        var description: String { rawValue }
    }

    let id: ID
    /// The wheel slot's name. A `LocalizedStringResource` rather than a `String`
    /// so the string is extractable — a runtime `String` yields no key for the
    /// compiler to localise, and silently stays English forever.
    let title: LocalizedStringResource
    /// Typed asset reference rather than a name string: a renamed or deleted
    /// asset becomes a compile error instead of an empty `Image` at runtime.
    let background: ImageResource
    let tasks: [CollectionTask]

    /// This collection's task with the given identity, if it has one.
    func task(with id: CollectionTask.ID) -> CollectionTask? {
        tasks.first { $0.id == id }
    }
}
