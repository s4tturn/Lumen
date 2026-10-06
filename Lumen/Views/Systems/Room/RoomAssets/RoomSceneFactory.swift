import CoreGraphics
import Foundation
import RealityKit
import UIKit

struct RoomSceneGraph {

    let pivot: Entity

    let camera: Entity

    let framing: RoomCamera

    let walls: [RoomWallGroup]

    let reveals: [RoomRevealGroup]

    let cameraBearing: SIMD3<Float>
}

struct RoomRevealGroup {
    let task: CollectionTask.ID
    let entities: [Entity]
}

struct RoomWallGroup {

    let facing: SIMD3<Float>

    let entities: [Entity]
}

@MainActor
enum RoomSceneFactory {

    static func load(_ scene: RoomScene) async -> Entity? {
        guard let entity = try? await Entity(named: scene.assetName) else { return nil }
        uncullFaces(in: entity)
        return entity
    }

    static func resolve(
        _ scene: RoomScene,
        from model: Entity,
        viewport: CGSize
    ) -> RoomSceneGraph {

        let members = authoredMembers(of: model)
        let entities = Dictionary(
            members.map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let named = nodesByName(in: model)
        let revealGroups = revealGroups(for: scene.reveals, nodes: named)

        let meshes = members.flatMap(meshNodes(of:)).map {
            ($0, $0.visualBounds(recursive: true, relativeTo: nil))
        }

        let hidden = Set(
            revealGroups.flatMap(\.entities).flatMap(meshNodes(of:)).map(ObjectIdentifier.init)
        )
        let framing = danglingFilter(
            meshes.filter { !hidden.contains(ObjectIdentifier($0.0)) }.map(\.1)
        )

        guard !framing.isEmpty else {

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

        let whole = RoomBounds(meshes.map(\.1))
        let camera = RoomCamera(
            center: center,
            extents: whole.extents,
            silhouette: framing.map {
                RoomSilhouette(offset: $0.center - center, half: $0.extents / 2)
            }
        )

        let wallGroups = wallGroups(for: scene.walls, entities: entities, center: center)

        let pivot = Entity()
        pivot.position = center
        pivot.addChild(model)
        addLighting(to: pivot)

        return RoomSceneGraph(
            pivot: pivot,
            camera: camera.makeEntity(viewport: viewport),
            framing: camera,
            walls: wallGroups,
            reveals: revealGroups,
            cameraBearing: camera.bearing
        )
    }

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

    private static func facing(of group: [Entity], from center: SIMD3<Float>) -> SIMD3<Float> {
        let middle = RoomBounds(group.map { $0.visualBounds(recursive: true, relativeTo: nil) }).mid
        let offset = SIMD3<Float>(middle.x - center.x, 0, middle.z - center.z)
        let distance = simd_length(offset)
        return distance > 0 ? offset / distance : SIMD3<Float>(0, 0, 1)
    }

    private static func danglingFilter(_ boxes: [BoundingBox]) -> [BoundingBox] {
        var kept = boxes
        var index = 0
        while index < kept.count {

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

    private static func authoredMembers(of model: Entity) -> [Entity] {
        var container = model
        while container.components[ModelComponent.self] == nil {
            let candidates = container.children.filter(containsMesh)
            guard candidates.count == 1 else { break }
            container = candidates[0]
        }
        return container.children.filter(containsMesh)
    }

    private static func containsMesh(_ entity: Entity) -> Bool {
        if entity.components[ModelComponent.self] != nil { return true }
        return entity.children.contains { containsMesh($0) }
    }

    private static func meshNodes(of entity: Entity) -> [Entity] {
        guard entity.components[ModelComponent.self] == nil else { return [entity] }
        return entity.children.flatMap(meshNodes(of:))
    }

    private static func uncullFaces(in entity: Entity) {
        if var model = entity.components[ModelComponent.self] {
            model.materials = model.materials.map(unculled)
            entity.components.set(model)
        }
        for child in entity.children { uncullFaces(in: child) }
    }

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
