import Foundation
import RealityKit
import Observation

/// The room's state, and the only thing in the page allowed to touch RealityKit.
///
/// The split that makes this fast: `objects` is observed, and everything a drag
/// touches is not. Turning the room writes `@ObservationIgnored` properties and
/// the pivot's orientation, so a drag sample reaches no SwiftUI body at all —
/// which is the entire cost of a turn. `objects` changes twice in the life of
/// the page, when the asset lands and when a toggle flips, and both are exactly
/// the moments the menu has to redraw.
///
/// - Note: The walls do not fade, and nothing here should be added to make them
///   fade. An earlier version of this page faded the two walls facing the camera
///   as the room turned, and it never once worked: the scene's nodes are plain
///   transforms with no `OpacityComponent`, so writing
///   `entity.components[OpacityComponent.self]?.opacity` did nothing and the room
///   was always drawn whole — the cost was real, the effect was not. To restore
///   it, set the component before writing it
///   (`entity.components.set(OpacityComponent(opacity:))`) and group the walls by
///   name: Door/Target/Wall1, DeskWindow/Painting/Wall2, BedWindow/Wall3,
///   Shelves/Wardrobe/Wall4.
@MainActor
@Observable
final class RoomStage {
    /// The room's toggleable objects, in scene order. Assigning it is what
    /// reveals the menu; everything else here is invisible to SwiftUI.
    private(set) var objects: [RoomObject] = []

    /// Carries the room, and so carries the rotation a drag writes.
    @ObservationIgnored private var pivot: Entity?

    /// The entity behind each object, so a toggle never searches the tree.
    @ObservationIgnored private var entities: [RoomObject.ID: Entity] = [:]

    /// Running rotation in radians, accumulated rather than published.
    @ObservationIgnored private var yaw: Float = 0

    /// Whether the room's graph participates in the scene. Off-live pages park
    /// the whole pivot (the camera stays enabled), collapsing RealityKit's
    /// per-frame GPU work to nothing while keeping the warm asset. Stored so a
    /// load that lands while off-live starts parked.
    @ObservationIgnored private var isActive = true

    /// Takes ownership of a freshly loaded room.
    func install(_ graph: RoomSceneGraph) {
        pivot = graph.pivot
        entities = graph.entities
        objects = graph.objects
        // A drag can land before the asset does; replay the rotation rather
        // than drop it.
        applyOrientation()
        pivot?.isEnabled = isActive
    }

    /// Sets the absolute yaw, in radians. The gesture owns the base+offset
    /// arithmetic so samples cannot compound.
    func setYaw(_ yaw: Float) {
        self.yaw = yaw
        applyOrientation()
    }

    /// Turns the room by `radians` from wherever it is now (used by
    /// accessibility).
    func turn(byRadians radians: Float) {
        yaw += radians
        applyOrientation()
    }

    /// Shows or hides one object.
    func setVisibility(_ isVisible: Bool, for id: RoomObject.ID) {
        guard let index = objects.firstIndex(where: { $0.id == id }),
              objects[index].isVisible != isVisible
        else { return }
        objects[index].isVisible = isVisible
        entities[id]?.isEnabled = isVisible
    }

    /// Parks or resumes the room's graph. No-op when unchanged, so liveness
    /// flips from the pager never touch the scene twice.
    func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        pivot?.isEnabled = active
    }

    /// Current rotation, wrapped into `0..<360` so it stays short however far
    /// the room has been turned. For accessibility only.
    var turnDegrees: Int {
        let degrees = Int((yaw * 180 / Float.pi).rounded())
        return (degrees % 360 + 360) % 360
    }

    private func applyOrientation() {
        pivot?.orientation = simd_quatf(angle: yaw, axis: SIMD3(0, 1, 0))
    }
}
