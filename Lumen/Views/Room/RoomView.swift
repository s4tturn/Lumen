import RealityKit
import SwiftUI
import _RealityKit_SwiftUI

/// Room page: the untitled model from the USDZ, shown from a fixed isometric
/// orthographic camera that frames the model's bounds. Drag inside the circle
/// to rotate the model in the z-x plane; taps and gestures outside the circle
/// are left for navigation.
struct RoomView: View {
    /// Object names in RoomScene, grouped by wall. Single source of truth for
    /// wall fading: edit freely — both membership (which objects fade) and
    /// each wall's facing direction (derived from member positions at load)
    /// come from here. Dots and underscores match interchangeably, so Blender
    /// names like "SHOESTEMP.001" match USDZ names like "SHOESTEMP_001".
    private static let wallObjectNames: [String: [String]] = [
        "bedroomWall1": ["Door", "Target", "DESKTEMP"],
        "bedroomWall2": ["DeskWindow", "PottedPlant", "SideTable", "Painting", "Modern_Bed", "MESSYBED", "Lamp"],
        "bedroomWall3": ["BedWindow", "SIDETABLETEMP.001"],
        "bedroomWall4": ["SHELVESTEMP", "WARDROBETEMP", "SHOESTEMP", "SHOESTEMP.001"],
    ]

    /// Yaw of the fixed isometric camera (matches the camera setup below).
    private static let cameraYaw: Float = 45 * .pi / 180

    private struct SceneObject: Identifiable {
        let id: ObjectIdentifier
        let name: String
        let entity: Entity
        var isVisible: Bool
    }

    @State private var pivotEntity: Entity?
    @State private var rotation: CGFloat = 0
    @State private var dragBase: CGFloat = 0
    @State private var objects: [SceneObject] = []
    @State private var fadedWalls: Set<String> = []
    @State private var wallDirections: [String: SIMD2<Float>] = [:]

    var body: some View {
        GeometryReader { proxy in
            let width = CGFloat(proxy.size.width)
            let bothScale: CGFloat = 2.5
            let circleRatio: CGFloat = 0.5
            let ratio = bothScale * circleRatio
            let diameter = width
            ZStack {
                RealityView { content in
                    content.camera = .virtual
                    content.environment = .default
                    guard let entity = try? await Entity(named: "RoomScene") else { return }
                    content.add(entity)

                    guard let library = MTLCreateSystemDefaultDevice()?.makeDefaultLibrary() else { return }
                let surfaceShader = CustomMaterial.SurfaceShader(named: "lumenSurfaceShader", in: library)
                if var modelComponent = entity.components[ModelComponent.self] {
                    modelComponent.materials = modelComponent.materials.map { material in
                        (try? CustomMaterial(from: material, surfaceShader: surfaceShader)) ?? material
                    }
                    entity.components.set(modelComponent)
                }

                    let bounds = entity.visualBounds(recursive: true, relativeTo: nil)
                    let center = bounds.center
                    let footprint = (bounds.extents.x + bounds.extents.z) / Float(2).squareRoot()
                    let height = bounds.extents.y
                    let cameraScale = Float(ratio) * max(footprint, height)

                    var camera = OrthographicCameraComponent()
                    camera.near = 0.01
                    camera.far = max(max(bounds.extents.x, bounds.extents.y, bounds.extents.z), 1) * 8
                    camera.scale = cameraScale
                    camera.scaleDirection = .horizontal

                    let maxExtent = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
                    let radius = maxExtent * 2
                    let pitch = 35.264 * Float.pi / 180
                    let yaw = 45 * Float.pi / 180
                    let offset = SIMD3<Float>(
                        radius * cos(pitch) * cos(yaw),
                        radius * sin(pitch),
                        radius * cos(pitch) * sin(yaw)
                    )
                    let cameraEntity = Entity()
                    cameraEntity.components.set(camera)
                    cameraEntity.look(at: center, from: center + offset, relativeTo: nil)
                    content.add(cameraEntity)

                    let originalScale = entity.scale
                    let worldPos = entity.position
                    let pivot = Entity()
                    pivot.position = center
                    content.add(pivot)
                    entity.position = worldPos - center
                    pivot.addChild(entity)
                    entity.scale = originalScale * Float(bothScale)
                    pivotEntity = pivot

                    @MainActor func containsModel(_ e: Entity) -> Bool {
                        if e.components[ModelComponent.self] != nil { return true }
                        for child in e.children where containsModel(child) { return true }
                        return false
                    }
                    var container = entity
                    while container.components[ModelComponent.self] == nil {
                        let candidates = container.children.filter(containsModel)
                        if candidates.count == 1 { container = candidates[0] } else { break }
                    }
                    let namedObjects = container.children.filter(containsModel)
                    objects = namedObjects.enumerated().map { index, child in
                        SceneObject(
                            id: ObjectIdentifier(child),
                            name: child.name.isEmpty ? "Object \(index + 1)" : child.name,
                            entity: child,
                            isVisible: true)
                    }
                    // Derive each wall's outward direction (world XZ) from the
                    // average position of its members relative to the room
                    // center, so regrouping wallObjectNames just works.
                    var directions: [String: SIMD2<Float>] = [:]
                    for (wall, names) in Self.wallObjectNames {
                        var sum = SIMD2<Float>.zero
                        var count: Float = 0
                        for child in namedObjects where names.contains(where: { Self.matches($0, child.name) }) {
                            let bounds = child.visualBounds(recursive: true, relativeTo: nil)
                            sum += SIMD2<Float>(bounds.center.x - center.x, bounds.center.z - center.z)
                            count += 1
                        }
                        if count > 0 {
                            let avg = sum / count
                            if length(avg) > 0.001 {
                                directions[wall] = normalize(avg)
                            }
                        }
                    }
                    wallDirections = directions
                    updateWallFading(animated: false)
                }
                Color.clear
                    .frame(width: diameter, height: diameter)
                    .contentShape(Circle())
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                rotation = dragBase + value.translation.width * 0.01
                                if let pivot = pivotEntity {
                                    pivot.orientation = simd_quatf(
                                        angle: Float(rotation), axis: SIMD3<Float>(0, 1, 0))
                                }
                            }
                            .onEnded { value in
                                dragBase = rotation
                            }
                    )
            }
            .onChange(of: rotation) { _, _ in updateWallFading() }
        }
        .overlay(alignment: .topLeading) {
            Menu {
                if objects.isEmpty {
                    Text("Loading objects…")
                        .disabled(true)
                } else {
                    ForEach(objects) { object in
                        Toggle(object.name, isOn: binding(for: object))
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass(.regular))
            .padding(.top, 50)
            .padding(.leading, UIConstants.General.safeSpace)
            .accessibilityLabel("Objects")
        }
        .accessibilityLabel("Room")
        .accessibilityAddTraits(.isHeader)
    }

    private func binding(for object: SceneObject) -> Binding<Bool> {
        Binding(
            get: { objects.first(where: { $0.id == object.id })?.isVisible ?? true },
            set: { visible in toggleVisibility(id: object.id, visible: visible) }
        )
    }

    private func toggleVisibility(id: ObjectIdentifier, visible: Bool) {
        guard let index = objects.firstIndex(where: { $0.id == id }) else { return }
        objects[index].isVisible = visible
        objects[index].entity.isEnabled = visible
    }

    /// Blender dots and USDZ underscores match interchangeably.
    private static func matches(_ grouped: String, _ actual: String) -> Bool {
        grouped.replacingOccurrences(of: ".", with: "_") == actual.replacingOccurrences(of: ".", with: "_")
    }

    private func wallName(for objectName: String) -> String? {
        for (wall, names) in Self.wallObjectNames where names.contains(where: { Self.matches($0, objectName) }) {
            return wall
        }
        return nil
    }

    /// Walls whose outward normal points most toward the fixed camera.
    /// Directions come from member positions at load; the camera sits at
    /// +X/+Z, so at any Y rotation exactly the two adjacent walls on the
    /// camera side score highest.
    private func frontWallNames(for rotation: CGFloat) -> Set<String> {
        let theta = Float(rotation)
        let cam = SIMD2<Float>(cos(Self.cameraYaw), sin(Self.cameraYaw))
        let c = cos(theta)
        let s = sin(theta)
        let scored = wallDirections.map { (wall, base) -> (String, Float) in
            let rx = base.x * c + base.y * s
            let rz = -base.x * s + base.y * c
            return (wall, rx * cam.x + rz * cam.y)
        }
        .sorted { $0.1 > $1.1 }
        return Set(scored.prefix(2).map { $0.0 })
    }

    private func updateWallFading(animated: Bool = true) {
        let front = frontWallNames(for: rotation)
        guard front != fadedWalls else { return }
        fadedWalls = front
        for object in objects {
            guard let wall = wallName(for: object.name) else { continue }
            let target: Float = front.contains(wall) ? 0 : 1
            if animated {
                Entity.animate(.easeInOut(duration: 0.3)) {
                    object.entity.components[OpacityComponent.self]?.opacity = target
                }
            } else {
                object.entity.components.set(OpacityComponent(opacity: target))
            }
        }
    }
}

#Preview {
    RoomView()
}
