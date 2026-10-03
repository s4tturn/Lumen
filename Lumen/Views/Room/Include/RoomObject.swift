import Foundation

/// One toggleable object in the room, as the menu sees it.
///
/// Deliberately a plain value with no entity in it: the entity behind an object
/// lives in `RoomStage`, keyed by `id`. That keeps this type `Sendable`, keeps
/// an entity out of every value comparison SwiftUI makes while diffing the menu,
/// and means the only way to change what is drawn still goes through the stage.
struct RoomObject: Identifiable, Equatable, Sendable {
    /// The object's name in the scene. It is both what the menu labels the row
    /// with and the key the stage looks the backing entity up by, which is why
    /// the loader falls back to a positional name rather than leaving it empty.
    typealias ID = String

    let id: ID
    var isVisible: Bool
}