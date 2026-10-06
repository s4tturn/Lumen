import CoreGraphics
import Foundation
import RealityKit
import UIKit

/// One load of a room's USDZ, resolved: the entities to add to the view, and how
/// the room is framed.
///
/// Built once, kept, and then never walked again. Anything that needs the room's
/// geometry has already read it here, so the per-drag work is a quaternion write
/// plus one opacity write per wall that has moved — and returning to a room is
/// putting an already-built graph back in the scene rather than measuring the
/// asset all over again.
struct RoomSceneGraph {
    /// Parent of the whole room. Turning this is what a drag turns.
    let pivot: Entity

    /// The fixed isometric camera, parentless like the pivot.
    let camera: Entity

    /// The room's framing, kept so a change of viewport can re-fit the camera
    /// without loading or rebuilding anything.
    let framing: RoomCamera

    /// The declared walls, each resolved to the nodes that fade as one.
    let walls: [RoomWallGroup]

    /// Each declared reward, resolved to the nodes it puts in the room, so the
    /// stage can show or hide them without walking the graph again.
    let reveals: [RoomRevealGroup]

    /// Which side of the room the camera stands on. See `RoomCamera.bearing`.
    let cameraBearing: SIMD3<Float>
}

/// One reward, resolved: the nodes it names, and the task that earns them.
struct RoomRevealGroup {
    let task: CollectionTask.ID
    let entities: [Entity]
}

/// One declared wall: the nodes that fade together, and the way it looks.
///
/// `facing` is read from the loaded geometry rather than from the wall's place
/// in the declaration, which is what lets that declaration be reordered,
/// extended or trimmed without changing which walls fade.
struct RoomWallGroup {
    /// Unit vector on the ground plane, pointing out of the room.
    let facing: SIMD3<Float>

    /// The wall and everything mounted on it, as resolved nodes.
    let entities: [Entity]
}

/// Turns a room's asset into a `RoomSceneGraph`.
///
/// Split into two steps on purpose, and this is the reason for the split: the load
/// suspends and the resolve does not. `load` is the only part that has to wait,
/// and `resolve` is the only part that touches the geometry — so resolving a room
/// the stage has already loaded is a synchronous dictionary lookup, and arriving
/// back at a room is the graph that was built the first time rather than a fresh
/// walk of thirty meshes.
@MainActor
enum RoomSceneFactory {
    /// Loads and repairs one room's asset. Cached by `RoomStage`, so this runs at
    /// most once per room per launch.
    static func load(_ scene: RoomScene) async -> Entity? {
        guard let entity = try? await Entity(named: scene.assetName) else { return nil }
        uncullFaces(in: entity)
        return entity
    }

    /// Builds the graph for a room: what to add to the view, and how it is framed.
    ///
    /// `viewport` only seeds the camera's opening frame. From the first mount on,
    /// `RoomStage` owns the frame and re-fits it whenever the page changes size,
    /// so nothing here has to be rebuilt for a rotation or a window drag.
    static func resolve(
        _ scene: RoomScene,
        from model: Entity,
        viewport: CGSize
    ) -> RoomSceneGraph {
        // The asset's own object groups — "Wall1", "PottedPlant" — are the level
        // its names live at, so they are what a wall declaration is resolved
        // against.
        let members = authoredMembers(of: model)
        let entities = Dictionary(
            members.map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        // Rewards reach deeper than the wall declarations do — a dumbbell is a
        // child of a child of the rack — so they are resolved against the whole
        // graph rather than its top level.
        let named = nodesByName(in: model)
        let revealGroups = revealGroups(for: scene.reveals, nodes: named)

        // Framing reads the meshes rather than the groups: the silhouette is the
        // room as drawn, and a group's own box can be wider than its furniture.
        // Each is kept beside its own bounds, so the two can be filtered together.
        let meshes = members.flatMap(meshNodes(of:)).map {
            ($0, $0.visualBounds(recursive: true, relativeTo: nil))
        }

        // Geometry a reward keeps hidden is not geometry the room draws yet, so it
        // is left out of the framing. The Kitchen's cabinet and chimney reach well
        // past its shell, and framing to them put the shell it does draw a whole
        // room-width off the middle of the frame — measured, and the reason the
        // Kitchen read off-centre while the other two, whose rewards stay inside
        // their shells, read as centred.
        //
        // Excluded per mesh rather than per group, because the split is not the
        // same granularity the declaration is written at: a chimney is a reward
        // and lives inside a wall that is always drawn, and dropping the wall with
        // it would frame the room on the one surface that fades out of view.
        let hidden = Set(
            revealGroups.flatMap(\.entities).flatMap(meshNodes(of:)).map(ObjectIdentifier.init)
        )
        let framing = danglingFilter(
            meshes.filter { !hidden.contains(ObjectIdentifier($0.0)) }.map(\.1)
        )

        guard !framing.isEmpty else {
            // Nothing to frame and nothing to draw: a stripped asset, or one whose
            // every mesh is a reward. A camera with no room behind it is still a
            // valid camera, and an empty graph still satisfies the stage, so this
            // degrades to an empty stage rather than to a crash on the page.
            let fallback = model.visualBounds(recursive: true, relativeTo: nil)
            let camera = RoomCamera(center: fallback.center, extents: fallback.extents, silhouette: [])
            return RoomSceneGraph(
                pivot: Entity(),
                camera: camera.makeEntity(viewport: viewport),
                framing: camera,
                walls: [],
                reveals: [],
                cameraBearing: camera.bearing
            )
        }

        let bounds = RoomBounds(framing)
        let center = bounds.mid
        // Every mesh, hidden ones included, sizes the room for the standoff and the
        // far plane. Framing is about what is drawn; clipping is about what can be,
        // and a reward that arrives later must still have room in the frame to
        // arrive into.
        let whole = RoomBounds(meshes.map(\.1))
        let camera = RoomCamera(
            center: center,
            extents: whole.extents,
            silhouette: framing.map {
                RoomSilhouette(offset: $0.center - center, half: $0.extents / 2)
            }
        )

        // Resolved before the re-parent below, while every wall is still
        // measured in the same space as `center`.
        let wallGroups = wallGroups(for: scene.walls, entities: entities, center: center)

        let pivot = Entity()
        pivot.position = center
        pivot.addChild(model)
        addLighting(to: pivot)
        // Nothing is scaled here. Framing used to magnify the model and then
        // divide by the same number in the camera, which cancelled exactly and
        // left two constants that had to be read together to be understood; the
        // room is now simply drawn at the size its geometry says it is.

        return RoomSceneGraph(
            pivot: pivot,
            camera: camera.makeEntity(viewport: viewport),
            framing: camera,
            walls: wallGroups,
            reveals: revealGroups,
            cameraBearing: camera.bearing
        )
    }

    // MARK: - Reveals

    /// Resolves the declared rewards against the loaded model.
    ///
    /// A task with nothing left to point at is dropped rather than resolved to an
    /// empty group, so a name that no longer matches the asset costs one line of
    /// content and no error — the same way an unmatched wall name is skipped.
    /// Names that do match are kept in the order they were declared, so the
    /// declaration reads in the same order as the room does.
    private static func revealGroups(
        for declarations: [RoomReveal],
        nodes: [String: Entity]
    ) -> [RoomRevealGroup] {
        declarations.compactMap { declaration in
            let group = declaration.nodes.compactMap { nodes[$0] }
            guard !group.isEmpty else { return nil }
            return RoomRevealGroup(task: declaration.task, entities: group)
        }
    }

    /// Every named node in `entity` and everything beneath it, keyed by name.
    ///
    /// Depth-first with the outermost match kept, which is what makes a name
    /// identify an object rather than one of its parts: `"Dumbell"` finds the
    /// node that *is* the dumbbell, and a name shared by a node and its own mesh
    /// resolves to the node — so hiding it hides the geometry with it.
    private static func nodesByName(in entity: Entity) -> [String: Entity] {
        var found: [String: Entity] = [:]
        func walk(_ node: Entity) {
            if !node.name.isEmpty, found[node.name] == nil {
                found[node.name] = node
            }
            for child in node.children { walk(child) }
        }
        walk(entity)
        return found
    }

    // MARK: - Wall groups

    /// Resolves the declared walls against the loaded model. Each declaration
    /// is the wall itself plus the objects standing on it, and becomes one
    /// group that fades as a unit.
    ///
    /// A name the scene does not carry is dropped rather than failing the load,
    /// so a declaration can be trimmed, extended or spelled differently without
    /// taking the room down with it.
    private static func wallGroups(
        for declarations: [[String]],
        entities: [String: Entity],
        center: SIMD3<Float>
    ) -> [RoomWallGroup] {
        declarations.compactMap { declaration in
            let group = declaration.compactMap { entities[$0] }
            guard !group.isEmpty else { return nil }
            return RoomWallGroup(facing: facing(of: group, from: center), entities: group)
        }
    }

    /// Which way a wall looks, on the ground plane.
    ///
    /// The room is four upright panels around one box, so the flat horizontal
    /// offset from the room's middle to a wall's own middle is that panel's
    /// outward normal. Measured rather than listed, which is what lets the
    /// declaration in `RoomScene` be in any order. A group with no offset has no
    /// facing to read, so it keeps `+Z` and stays a well-behaved wall.
    private static func facing(of group: [Entity], from center: SIMD3<Float>) -> SIMD3<Float> {
        let middle = RoomBounds(group.map { $0.visualBounds(recursive: true, relativeTo: nil) }).mid
        let offset = SIMD3<Float>(middle.x - center.x, 0, middle.z - center.z)
        let distance = simd_length(offset)
        return distance > 0 ? offset / distance : SIMD3<Float>(0, 0, 1)
    }

    // MARK: - Framing

    /// Drops the meshes that stretch the room far beyond itself.
    ///
    /// One dangling mesh — a shirt inside a wardrobe hanging tens of metres
    /// below the floor — triples the room's height and drags its middle with it.
    /// Framing cannot survive that, so any mesh that on its own reaches more than
    /// half again past what the rest of the room reaches is left out (to a
    /// fixpoint, so two danglers cannot mask each other). The room's own shell
    /// can never trigger this: the four walls share the extremes, so no single
    /// wall owns them.
    ///
    /// A single pass, and not a rescan from the start after each removal, because
    /// the two answer the same question and always have: taking a mesh away can
    /// only shrink what is left, so a mesh that was already overhanging the rest
    /// still is. There is therefore a largest set of meshes that overhang nothing,
    /// and every route to it arrives at the same one — which is worth knowing,
    /// because a fixpoint that depended on the order it was reached in would be a
    /// number nobody could reason about. What the pass costs is one union of the
    /// remainder per mesh, quadratic in the number of meshes and nothing at all
    /// once, at load.
    ///
    /// An excluded mesh is merely left out of the framing, never hidden — a
    /// wardrobe's shirt hanging below the floor is outside the frame anyway, so
    /// nothing a viewer can see is affected.
    private static func danglingFilter(_ boxes: [BoundingBox]) -> [BoundingBox] {
        var kept = boxes
        var index = 0
        while index < kept.count {
            // Everything but this mesh, as this mesh would see it if it were the
            // only one left: what is already behind it, then what is ahead.
            var rest = RoomBounds(kept[..<index])
            for ahead in kept[(index + 1)...] {
                rest = rest.united(with: RoomBounds([ahead]))
            }
            if RoomBounds([kept[index]]).overhangs(rest) {
                kept.remove(at: index)
            } else {
                index += 1
            }
        }
        return kept
    }

    // MARK: - Lighting

    /// Adds a soft, directional key light from the top-right to lift materials
    /// without adding texture memory or heavy shader work.
    ///
    /// Built here rather than on every mount because it belongs to the room rather
    /// than to the scene: one light, authored once into the pivot, that turns with
    /// the room so its direction is fixed relative to the walls it is lighting.
    private static func addLighting(to pivot: Entity) {
        let light = Entity()
        light.name = "RoomKeyLight"
        light.position = [1.0, 2.0, 1.0]
        light.look(at: SIMD3<Float>(0, 0, 0), from: light.position, relativeTo: pivot)
        var directional = DirectionalLightComponent()
        directional.color = .white
        directional.intensity = 300
        directional.isRealWorldProxy = false
        light.components.set(directional)
        pivot.addChild(light)
    }

    // MARK: - The asset's own structure

    /// The asset's top-level object groups — the named children one level below
    /// the group that actually holds geometry.
    ///
    /// The asset nests everything under an unnamed wrapper, so this descends
    /// through single-child wrappers until it reaches the level it was authored
    /// at: "Modern_Bed", "Wall1", "PottedPlant", and so on. A wrapper with more
    /// than one geometry-bearing child is ambiguous, so the walk stops there and
    /// that level's children are used instead.
    private static func authoredMembers(of model: Entity) -> [Entity] {
        var container = model
        while container.components[ModelComponent.self] == nil {
            let candidates = container.children.filter(containsMesh)
            guard candidates.count == 1 else { break }
            container = candidates[0]
        }
        return container.children.filter(containsMesh)
    }

    /// Whether `entity` carries geometry itself or anywhere beneath it.
    private static func containsMesh(_ entity: Entity) -> Bool {
        if entity.components[ModelComponent.self] != nil { return true }
        return entity.children.contains { containsMesh($0) }
    }

    /// Every mesh at or under `entity`. A mesh-bearing node contributes itself and
    /// stops: geometry nested inside it is inside that box already, so descending
    /// would measure the same volume twice.
    ///
    /// The nodes rather than their bounds, because the framing has to be able to
    /// leave one of them out — see the reward-hidden meshes in `resolve` — and a
    /// bound cannot say which mesh it came from.
    private static func meshNodes(of entity: Entity) -> [Entity] {
        guard entity.components[ModelComponent.self] == nil else { return [entity] }
        return entity.children.flatMap(meshNodes(of:))
    }

    /// Gives the room back the double-sided geometry the assets ask for.
    ///
    /// Every mesh in these assets is authored `doubleSided = 1`, and that is not
    /// decoration: the furniture is mirrored on its way out of Blender, so the
    /// `Cabinet` and the `Countertop` carry a negative-determinant scale and
    /// their screen-space winding is reversed. RealityKit's USD importer drops
    /// `doubleSided` and builds every material with back-face culling on, which
    /// is exactly wrong for that geometry — the surface facing the camera is
    /// discarded and you look straight through the cabinet at its own interior.
    ///
    /// Turning culling off restores the asset's intent, and it is the right
    /// repair rather than a patch because it does not depend on which way any
    /// given mesh ended up wound: with culling off, depth alone decides, so the
    /// nearest surface is the one that survives. It runs once per load, over
    /// roughly thirty meshes, and never again.
    private static func uncullFaces(in entity: Entity) {
        if var model = entity.components[ModelComponent.self] {
            model.materials = model.materials.map(unculled)
            entity.components.set(model)
        }
        for child in entity.children { uncullFaces(in: child) }
    }

    /// One material with back-face culling switched off, or itself unchanged if
    /// it has none to switch off. A USDZ import is always
    /// `PhysicallyBasedMaterial`; `SimpleMaterial` is handled too so a
    /// hand-built entity cannot reintroduce the fault.
    private static func unculled(_ material: any Material) -> any Material {
        var material = material
        if var pbr = material as? PhysicallyBasedMaterial {
            pbr.faceCulling = .none
            material = pbr
        } else if var simple = material as? SimpleMaterial {
            simple.faceCulling = .none
            material = simple
        }
        return material
    }
}
