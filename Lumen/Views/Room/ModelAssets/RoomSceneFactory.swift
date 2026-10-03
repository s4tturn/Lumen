import Foundation
import RealityKit

/// One load of `RoomScene.usdz`, resolved: the entities to add to the view, and
/// the objects the menu can toggle.
///
/// Built once, handed to `RoomStage`, and then never walked again. Anything that
/// needs the room's geometry has already read it here, so the per-drag work is a
/// single quaternion write.
struct RoomSceneGraph {
    /// Parent of the whole room. Turning this is the only thing a drag does.
    let pivot: Entity

    /// The fixed isometric camera, parentless like the pivot.
    let camera: Entity

    /// The toggleable objects, in scene order.
    let objects: [RoomObject]

    /// The entity behind each object, keyed by `RoomObject.ID`.
    let entities: [RoomObject.ID: Entity]
}

/// Turns the loaded asset into a `RoomSceneGraph`.
@MainActor
enum RoomSceneFactory {
    /// The USDZ in this folder, resolved from the app bundle.
    static let assetName = "RoomScene"

    static func make(from model: Entity) -> RoomSceneGraph {
        let fullBounds = model.visualBounds(recursive: true, relativeTo: nil)
        let members = toggleableMembers(of: model)

        // The camera fits the full bounds (so nothing can ever be cropped
        // out) but looks at the room's lived-in middle, not the box middle:
        // see `livedInCenter` for why those differ.
        let camera = RoomCamera(
            center: livedInCenter(members: members, fallback: fullBounds.center),
            extents: fullBounds.extents
        )

        let pivot = Entity()
        pivot.position = camera.center
        recentre(model, on: pivot)

        var objects: [RoomObject] = []
        var entities: [RoomObject.ID: Entity] = [:]
        objects.reserveCapacity(members.count)
        entities.reserveCapacity(members.count)
        for (index, member) in members.enumerated() {
            // A scene node's name is its label, so it falls back to position
            // rather than to an empty row.
            let id = member.name.isEmpty ? "Object \(index + 1)" : member.name
            objects.append(RoomObject(id: id, isVisible: true))
            entities[id] = member
        }

        return RoomSceneGraph(
            pivot: pivot,
            camera: camera.makeEntity(),
            objects: objects,
            entities: entities
        )
    }

    /// Moves the room onto the pivot, enlarges it, and centres its geometry on
    /// the pivot so it projects to the middle of the frame.
    ///
    /// The centre is measured, not assumed: after the re-parent and scale the
    /// model's own bounds are read back in pivot space and the model is shifted
    /// by exactly that much. Whatever the asset's origin or the pivot offset,
    /// the room's visual centre ends up on the pivot — which is also where the
    /// camera looks — so the room sits centred vertically and horizontally.
    private static func recentre(_ model: Entity, on pivot: Entity) {
        let worldScale = model.scale
        pivot.addChild(model)
        model.scale = worldScale * RoomCamera.modelScale
        let offset = model.visualBounds(recursive: true, relativeTo: pivot).center
        model.position -= offset
    }

    /// Where the camera looks and the room pivots: the middle of the room's
    /// lived-in volume.
    ///
    /// That is deliberately not the bounding-box middle. One dangling mesh —
    /// currently a shirt inside the Wardrobe hanging ~35m below the floor —
    /// triples the box height and drags its middle ~17m under the visible room,
    /// which puts the room ~110pt too high on screen. So any member that on its
    /// own stretches the room by more than half again is left out of the middle
    /// (to a fixpoint, so two danglers can't mask each other). The room's own
    /// shell can never trigger this: the four walls share the extremes, so no
    /// single wall owns them. Framing still uses the full bounds, so an excluded
    /// member is merely off-center, never cropped.
    private static func livedInCenter(members: [Entity], fallback: SIMD3<Float>) -> SIMD3<Float> {
        var boxes = members.map { $0.visualBounds(recursive: true, relativeTo: nil) }
        guard !boxes.isEmpty else { return fallback }

        var changed = true
        while changed, boxes.count > 1 {
            changed = false
            for index in boxes.indices {
                var rest = boxes
                rest.remove(at: index)
                let (lo, hi) = union(rest)
                let span = hi - lo
                let (mineLo, mineHi) = (boxes[index].center - boxes[index].extents / 2,
                                        boxes[index].center + boxes[index].extents / 2)
                if mineLo.x < lo.x - span.x / 2 || mineHi.x > hi.x + span.x / 2
                    || mineLo.y < lo.y - span.y / 2 || mineHi.y > hi.y + span.y / 2
                    || mineLo.z < lo.z - span.z / 2 || mineHi.z > hi.z + span.z / 2
                {
                    boxes.remove(at: index)
                    changed = true
                    break
                }
            }
        }

        let (lo, hi) = union(boxes)
        return (lo + hi) / 2
    }

    /// Component-wise min/max corners over `boxes`.
    private static func union(_ boxes: [BoundingBox]) -> (lo: SIMD3<Float>, hi: SIMD3<Float>) {
        var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var hi = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for box in boxes {
            let boxLo = box.center - box.extents / 2
            let boxHi = box.center + box.extents / 2
            lo = SIMD3(min(lo.x, boxLo.x), min(lo.y, boxLo.y), min(lo.z, boxLo.z))
            hi = SIMD3(max(hi.x, boxHi.x), max(hi.y, boxHi.y), max(hi.z, boxHi.z))
        }
        return (lo, hi)
    }

    /// The asset's top-level object groups — the named children one level below
    /// the group that actually holds geometry.
    ///
    /// The asset nests everything under an unnamed wrapper, so this descends
    /// through single-child wrappers until it reaches the level it was authored
    /// at: "Modern_Bed", "Wall1", "PottedPlant", and so on. A wrapper with more
    /// than one geometry-bearing child is ambiguous, so the walk stops there and
    /// that level's children are used instead.
    private static func toggleableMembers(of model: Entity) -> [Entity] {
        var container = model
        while container.components[ModelComponent.self] == nil {
            let candidates = container.children.filter(containsMesh)
            guard candidates.count == 1 else { break }
        x    container = candidates[0]
        }
        return container.children.filter(containsMesh)
    }

    /// Whether `entity` carries geometry itself or anywhere beneath it.
    private static func containsMesh(_ entity: Entity) -> Bool {
        if entity.components[ModelComponent.self] != nil { return true }
        return entity.children.contains { containsMesh($0) }
    }
}
