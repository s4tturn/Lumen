import SwiftUI

struct RoomReveal: Sendable {

    let task: CollectionTask.ID

    let nodes: [String]
}

struct RoomScene: Identifiable, Hashable, Sendable {

    let walls: [[String]]

    let reveals: [RoomReveal]

    let assetName: String

    let title: LocalizedStringResource

    let tabTitle: LocalizedStringResource

    let symbol: String

    var tabTint: Color? {
        switch self {
        case .bedroom: return .blue.opacity(0.3)
        case .livingRoom: return .red.opacity(0.25)
        case .kitchen: return .yellow.opacity(0.25)
        default: return nil
        }
    }

    static let all: [RoomScene] = [.bedroom, .livingRoom, .kitchen]

    static let bedroom = RoomScene(
        walls: [
            ["Wall1", "Door", "Target"],
            ["Wall2", "DeskWindow", "Painting"],
            ["Wall3", "BedWindow"],
            ["Wall4", "Shelves", "Wardrobe"],
        ],
        reveals: [
            RoomReveal(task: .init("self.clothes"), nodes: ["Wardrobe"]),
            RoomReveal(task: .init("self.water"), nodes: ["SideTable", "Bottle"]),
            RoomReveal(task: .init("self.ritual"), nodes: ["Mirror"]),
            RoomReveal(task: .init("space.surface"), nodes: ["Rug"]),
            RoomReveal(task: .init("space.bed"), nodes: ["Modern_Bed"]),
            RoomReveal(task: .init("space.windows"), nodes: ["Painting"]),
            RoomReveal(task: .init("space.beauty"), nodes: ["Lamp"]),
            RoomReveal(task: .init("growth.reading"), nodes: ["Books"]),
            RoomReveal(task: .init("growth.practice"), nodes: ["Target"]),
            RoomReveal(task: .init("growth.idea"), nodes: ["Diary"]),
            RoomReveal(task: .init("growth.making"), nodes: ["Tool_box_Cube_026"]),
            RoomReveal(task: .init("joy.beauty"), nodes: ["PottedPlant"]),
        ],
        assetName: "Bedroom",
        title: "Bedroom",
        tabTitle: "Bedroom",
        symbol: "bed.double"
    )

    static let livingRoom = RoomScene(
        walls: [
            ["LivingroomWall1", "BedroomDoor", "DisplayShelf"],
            ["LivingroomWall2", "DeskWindow", "TV"],
            ["LivingroomWall3", "MainDoor", "Clock"],
            ["LivingroomWall4", "KitchenDoor_001", "WallMask"],
        ],
        reveals: [

            RoomReveal(task: .init("self.walk"), nodes: ["ConverseShoes", "SneakerShoes"]),
            RoomReveal(task: .init("self.stretch"), nodes: [
                "Dumbell", "Dumbell_001", "Dumbell_002", "Dumbell_003",
            ]),
            RoomReveal(task: .init("space.belongings"), nodes: ["LaundryBasket"]),
            RoomReveal(task: .init("connection.photo"), nodes: [
                "FilmCamera", "InstantCamera", "DigitalCamera",
            ]),
            RoomReveal(task: .init("connection.appreciation"), nodes: ["PaperStack"]),
            RoomReveal(task: .init("connection.call"), nodes: ["PhoneTable"]),
            RoomReveal(task: .init("connection.favor"), nodes: ["Trophy"]),
            RoomReveal(task: .init("connection.presence"), nodes: ["Clock"]),
            RoomReveal(task: .init("growth.learning"), nodes: ["PottedPlant2"]),
            RoomReveal(task: .init("joy.music"), nodes: ["VinylCorner"]),
            RoomReveal(task: .init("joy.hobby"), nodes: ["Easel"]),
            RoomReveal(task: .init("joy.silly"), nodes: ["WallMask"]),
            RoomReveal(task: .init("joy.laughter"), nodes: ["TV"]),
        ],
        assetName: "LivingRoom",
        title: "Living Room",
        tabTitle: "Living",
        symbol: "sofa"
    )

    static let kitchen = RoomScene(
        walls: [
            ["KitchenWall1", "Chimney"],
            ["KitchenWall2", "KitchenDoor", "Fridge"],
            ["KitchenWall3"],
            ["KitchenWall4", "KitchenWindow"],
        ],
        reveals: [
            RoomReveal(task: .init("kitchen.breakfast"), nodes: ["Toaster"]),
            RoomReveal(task: .init("kitchen.snack"), nodes: ["Fridge"]),
            RoomReveal(task: .init("kitchen.recipe"), nodes: ["Stove", "Chimney"]),
            RoomReveal(task: .init("kitchen.drink"), nodes: ["CoffeeMachine"]),
            RoomReveal(task: .init("kitchen.memory"), nodes: ["Cabinet"]),
        ],
        assetName: "Kitchen",
        title: "Kitchen",
        tabTitle: "Kitchen",
        symbol: "frying.pan"
    )

    var id: String { assetName }

    var order: Int { Self.all.firstIndex(of: self) ?? 0 }

    static func == (lhs: RoomScene, rhs: RoomScene) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
import CoreGraphics
import Foundation
import RealityKit

struct RoomCamera {

    static let pitch: Float = 35.264 * Float.pi / 180

    static let yaw: Float = 45 * Float.pi / 180

    static let near: Float = 0.01

    static let fill: Float = 0.88

    private static let standoffFactor: Float = 2

    private static func standoff(for extents: SIMD3<Float>) -> Float {
        max(extents.x, extents.y, extents.z) * standoffFactor
    }

    private static let farFactor: Float = 8

    static let right: SIMD3<Float> = {
        let forward = SIMD3<Float>(cos(pitch) * cos(yaw), sin(pitch), cos(pitch) * sin(yaw))
        return simd_normalize(SIMD3<Float>(-forward.z, 0, forward.x))
    }()

    static let up: SIMD3<Float> = {
        let forward = SIMD3<Float>(cos(pitch) * cos(yaw), sin(pitch), cos(pitch) * sin(yaw))
        return simd_normalize(simd_cross(right, forward))
    }()

    private static let rightOnHeight = abs(simd_dot(right, SIMD3<Float>(0, 1, 0)))
    private static let upOnHeight = abs(simd_dot(up, SIMD3<Float>(0, 1, 0)))

    let center: SIMD3<Float>

    let extents: SIMD3<Float>

    let silhouette: [RoomSilhouette]

    init(center: SIMD3<Float>, extents: SIMD3<Float>, silhouette: [RoomSilhouette]) {

        let drawn = Self.screenBounds(silhouette, yaw: 0)
        let bearing = Self.bearing(
            of: Self.pose(offset: drawn.offset, center: center, standoff: Self.standoff(for: extents)).position,
            from: center
        )
        self.center = center
        self.extents = extents
        self.silhouette = silhouette
        self.size = drawn.size
        self.bearing = bearing
    }

    let size: SIMD2<Float>

    let bearing: SIMD3<Float>

    var standoff: Float {
        Self.standoff(for: extents)
    }

    var far: Float {
        max(extents.x, extents.y, extents.z, 1) * Self.farFactor
    }

    func scale(in viewport: CGSize) -> Float {
        let width = Float(viewport.width)
        let height = Float(viewport.height)
        let framed = width > 0 && height > 0
            ? max(size.x, size.y * (width / height))
            : size.x
        return framed / (2 * Self.fill)
    }

    private static func bearing(of position: SIMD3<Float>, from center: SIMD3<Float>) -> SIMD3<Float> {
        let offset = position - center
        let horizontal = SIMD3<Float>(offset.x, 0, offset.z)
        let distance = simd_length(horizontal)
        return distance > 0 ? horizontal / distance : SIMD3<Float>(0, 0, 1)
    }

    private static func pose(
        offset: SIMD2<Float>,
        center: SIMD3<Float>,
        standoff: Float
    ) -> (aim: SIMD3<Float>, position: SIMD3<Float>) {
        let aim = center + right * offset.x + up * offset.y
        let horizontal = standoff * cos(pitch)
        return (aim, aim + SIMD3(
            horizontal * cos(yaw),
            standoff * sin(pitch),
            horizontal * sin(yaw)
        ))
    }

    func pose(yaw: Float) -> (aim: SIMD3<Float>, position: SIMD3<Float>) {
        Self.pose(
            offset: Self.screenBounds(silhouette, yaw: yaw).offset,
            center: center,
            standoff: standoff
        )
    }

    func makeEntity(viewport: CGSize) -> Entity {
        var component = OrthographicCameraComponent()
        component.near = Self.near
        component.far = far
        component.scale = scale(in: viewport)
        component.scaleDirection = .horizontal

        let entity = Entity()
        entity.components.set(component)
        let pose = pose(yaw: 0)
        entity.look(at: pose.aim, from: pose.position, relativeTo: nil)
        return entity
    }

    private static func screenBounds(
        _ silhouette: [RoomSilhouette],
        yaw: Float
    ) -> (offset: SIMD2<Float>, size: SIMD2<Float>) {

        guard !silhouette.isEmpty else {
            return (SIMD2<Float>.zero, SIMD2<Float>(repeating: 1))
        }

        let cosine = cos(yaw), sine = sin(yaw)
        let swung = (SIMD3<Float>(cosine, 0, -sine), SIMD3<Float>(sine, 0, cosine))

        let spread = (
            SIMD3<Float>(
                abs(simd_dot(Self.right, swung.0)),
                Self.rightOnHeight,
                abs(simd_dot(Self.right, swung.1))
            ),
            SIMD3<Float>(
                abs(simd_dot(Self.up, swung.0)),
                Self.upOnHeight,
                abs(simd_dot(Self.up, swung.1))
            )
        )

        var lo = SIMD2<Float>(repeating: .greatestFiniteMagnitude)
        var hi = SIMD2<Float>(repeating: -.greatestFiniteMagnitude)
        for box in silhouette {
            let middle = SIMD3<Float>(
                box.offset.x * cosine + box.offset.z * sine,
                box.offset.y,
                -box.offset.x * sine + box.offset.z * cosine
            )
            let half = SIMD2<Float>(simd_dot(spread.0, box.half), simd_dot(spread.1, box.half))
            let point = SIMD2<Float>(simd_dot(middle, Self.right), simd_dot(middle, Self.up))
            lo = SIMD2<Float>(min(lo.x, point.x - half.x), min(lo.y, point.y - half.y))
            hi = SIMD2<Float>(max(hi.x, point.x + half.x), max(hi.y, point.y + half.y))
        }

        return ((lo + hi) / 2, hi - lo)
    }
}
import RealityKit

struct RoomBounds {

    let lo: SIMD3<Float>

    let hi: SIMD3<Float>

    var mid: SIMD3<Float> { (lo + hi) / 2 }

    var extents: SIMD3<Float> { hi - lo }

    init(_ boxes: some Sequence<BoundingBox>) {
        var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var hi = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for box in boxes {
            let half = box.extents / 2
            lo = simd_min(lo, box.center - half)
            hi = simd_max(hi, box.center + half)
        }
        self.init(lo: lo, hi: hi)
    }

    private init(lo: SIMD3<Float>, hi: SIMD3<Float>) {
        self.lo = lo
        self.hi = hi
    }

    func united(with other: RoomBounds) -> RoomBounds {
        RoomBounds(lo: simd_min(lo, other.lo), hi: simd_max(hi, other.hi))
    }

    func overhangs(_ rest: RoomBounds) -> Bool {
        let slack = rest.extents / 2
        return lo.x < rest.lo.x - slack.x || hi.x > rest.hi.x + slack.x
            || lo.y < rest.lo.y - slack.y || hi.y > rest.hi.y + slack.y
            || lo.z < rest.lo.z - slack.z || hi.z > rest.hi.z + slack.z
    }
}

struct RoomSilhouette {

    let offset: SIMD3<Float>

    let half: SIMD3<Float>
}
import RealityKit
import SwiftUI

struct RoomRealityStage: View {
    let stage: RoomStage
    let scene: RoomScene

    var body: some View {
        RealityView { content in

            content.camera = .virtual
            content.environment = .default

            guard await stage.graph(for: scene) != nil else { return }
            stage.mount(scene, in: &content)
        } update: { content in

            stage.mount(scene, in: &content)
        }

        .debugSurfaceBorder()
    }
}
import CoreGraphics
import Foundation
import Observation
import RealityKit
import SwiftUI

@MainActor
@Observable
final class RoomStage {

    private static let fadeBand: Float = 0.35

    private static let fadeDeadband: Float = 0.002

    static let travelDistance: CGFloat = 0.3

    static let travelRecede: CGFloat = 0.12

    private static let radiansPerPoint: Float = 0.01

    private static let glideSeconds: Float = 0.16
    private static let glideCeiling: Float = 1.2

    private static let glideSteps = 34

    private static let pinchResistFloor: Float = 0.75
    private static let pinchResistCeiling: Float = 1.5

    private static let pinchResistFloorLog = log(pinchResistFloor)
    private static let pinchResistCeilingLog = log(pinchResistCeiling)

    private static let pinchBandGive: Float = 0.55

    private static let pinchBandSpan: Float = 0.35

    private static let pinchBandGap: Float = 0.03

    private static let pinchDeadband: Float = 0.001

    private static let pinchSettleAt: Float = 0.02

    private static let pinchSettleRate: Float = 16
    private static let pinchSettleDamping: Float = 0.7

    private static let pinchSettleTolerance: Float = 0.002

    private static var pinchSettleTime: Float {
        -log(pinchSettleTolerance) / (pinchSettleDamping * pinchSettleRate)
    }

    private static let pinchReleaseCeiling: Float = 2.5

    private(set) var selection: RoomScene = .bedroom

    private(set) var shown: RoomScene = .bedroom

    private(set) var slide: CGFloat = 0

    private(set) var fade: Double = 1

    private(set) var settleTick = 0

    private(set) var pinchTick = 0

    private(set) var pinchArriveTick = 0

    @ObservationIgnored private var pivot: Entity?

    @ObservationIgnored private var camera: Entity?

    @ObservationIgnored private var framing: RoomCamera?

    @ObservationIgnored private var viewport: CGSize = .zero

    @ObservationIgnored private var mounted: RoomScene?

    @ObservationIgnored private var wallGroups: [RoomWallGroup] = []

    @ObservationIgnored private var revealGroups: [RoomRevealGroup] = []

    @ObservationIgnored private var earned: Set<CollectionTask.ID> = []

    @ObservationIgnored private var wallOpacities: [Float] = []

    @ObservationIgnored private var cameraBearing: SIMD3<Float> = SIMD3(0, 0, 1)

    @ObservationIgnored private var yaw: Float = 0

    @ObservationIgnored private var turnBase: Float = 0

    @ObservationIgnored private var glide: Task<Void, Never>?

    @ObservationIgnored private var pinchTrack: Float = 1

    @ObservationIgnored private var pinchScale: Float = 1

    @ObservationIgnored private var pinchBase: Float = 1

    @ObservationIgnored private var pinchAnnounced = false

    @ObservationIgnored private var settleZoomTask: Task<Void, Never>?

    @ObservationIgnored private var isActive = true

    @ObservationIgnored private var graphs: [RoomScene.ID: RoomSceneGraph] = [:]

    @ObservationIgnored private var switchTask: Task<Void, Never>?

    @ObservationIgnored private var switchID: Int = 0

    @discardableResult
    func graph(for scene: RoomScene) async -> RoomSceneGraph? {
        if let cached = graphs[scene.id] { return cached }
        guard let model = await RoomSceneFactory.load(scene) else { return nil }
        let graph = RoomSceneFactory.resolve(scene, from: model, viewport: viewport)
        graphs[scene.id] = graph
        return graph
    }

    func prefetchOthers() async {
        for scene in RoomScene.all where scene != shown {
            await graph(for: scene)
        }
    }

    func mount(_ scene: RoomScene, in content: inout RealityViewCameraContent) {
        guard mounted != scene, let graph = graphs[scene.id] else { return }

        if let pivot, let camera {
            content.remove(pivot)
            content.remove(camera)
        }

        content.add(graph.pivot)
        content.add(graph.camera)

        pivot = graph.pivot
        camera = graph.camera
        mounted = scene
        install(graph)
    }

    func select(_ scene: RoomScene, reduceMotion: Bool) {
        guard scene != selection else { return }
        selection = scene
        runSwitch(reduceMotion: reduceMotion)
    }

    private func runSwitch(reduceMotion: Bool) {
        switchID &+= 1
        let id = switchID
        switchTask?.cancel()
        switchTask = Task { await travel(id, reduceMotion: reduceMotion) }
    }

    private func travel(_ id: Int, reduceMotion: Bool) async {
        while shown != selection || slide != 0 || fade != 1 {
            guard shown != selection else {

                await animate(UIConstants.Animation.reduceMotionGate(UIConstants.Animation.commit, reduceMotion: reduceMotion)) {
                    self.slide = 0
                    self.fade = 1
                }
                guard id == switchID else { return }
                if slide == 0, fade == 1 { settleTick &+= 1 }
                continue
            }

            let out: CGFloat = selection.order > shown.order ? -1 : 1

            if reduceMotion {
                await animate(UIConstants.Animation.reduced) { self.fade = 0 }
            } else {
                await animate(UIConstants.Animation.commit) {
                    self.slide = out * Self.travelDistance
                    self.fade = 0
                }
            }
            guard id == switchID else { return }

            let incoming = await graph(for: selection)
            guard id == switchID else { return }
            guard incoming != nil else {

                selection = shown
                return
            }

            shown = selection
            if !reduceMotion {

                withoutAnimation { self.slide = -out * Self.travelDistance }
            }
        }
    }

    private func animate(_ animation: Animation, _ change: () -> Void) async {
        await withCheckedContinuation { continuation in
            withAnimation(animation, completionCriteria: .logicallyComplete, change) {
                continuation.resume()
            }
        }
    }

    private func withoutAnimation(_ change: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, change)
    }

    private func install(_ graph: RoomSceneGraph) {
        framing = graph.framing
        wallGroups = graph.walls
        wallOpacities = Array(repeating: -1, count: graph.walls.count)
        revealGroups = graph.reveals
        cameraBearing = graph.cameraBearing

        glide?.cancel()
        yaw = 0
        turnBase = 0
        applyOrientation()
        pivot?.isEnabled = isActive

        applyCameraScale()
        applyReveals()
    }

    func setEarned(_ tasks: Set<CollectionTask.ID>) {
        guard tasks != earned else { return }
        earned = tasks
        applyReveals()
    }

    private func applyReveals() {
        for group in revealGroups {
            let visible = earned.contains(group.task)
            for entity in group.entities { entity.isEnabled = visible }
        }
    }

    func setViewport(_ size: CGSize) {
        guard size != viewport, size.width > 0, size.height > 0 else { return }
        viewport = size
        applyCameraScale()
    }

    private func applyCameraScale() {
        guard let camera,
              var component = camera.components[OrthographicCameraComponent.self],
              let framing,
              viewport.width > 0, viewport.height > 0
        else { return }
        component.scale = framing.scale(in: viewport) / pinchScale
        camera.components.set(component)
    }

    func beginPinch() {
        yaw = turnBase
        settleZoomTask?.cancel()
        settleZoomTask = nil
        pinchBase = pinchTrack
    }

    func updatePinch(scale: Float) {
        let track = pinchBase * scale

        pinchTrack = track
        let zoom = Self.bandedZoom(track)
        guard abs(zoom - pinchScale) > Self.pinchDeadband else { return }
        pinchScale = zoom
        applyCameraScale()
        announceBand(track: track)
    }

    private func announceBand(track: Float) {
        guard track > Self.pinchResistCeiling || track < Self.pinchResistFloor else {
            if track < Self.pinchResistCeiling - Self.pinchBandGap,
               track > Self.pinchResistFloor + Self.pinchBandGap {
                pinchAnnounced = false
            }
            return
        }
        guard !pinchAnnounced else { return }
        pinchAnnounced = true
        pinchTick &+= 1
    }

    func endPinch(velocity: Float, reduceMotion: Bool) {
        let track = pinchTrack
        pinchAnnounced = false
        let announces = abs(track - 1) > Self.pinchSettleAt
        guard !reduceMotion, abs(track - 1) > Self.pinchDeadband else {
            arriveAtPreset(announces: announces)
            return
        }
        settleZoom(from: track, velocity: velocity, announces: announces)
    }

    private func settleZoom(from track: Float, velocity: Float, announces: Bool) {
        settleZoomTask?.cancel()
        let damping = Self.pinchSettleDamping
        let rate = Self.pinchSettleRate
        let decay = damping * rate
        let frequency = rate * (1 - damping * damping).squareRoot()
        let offset = track - 1
        let phase = (min(max(velocity, -Self.pinchReleaseCeiling), Self.pinchReleaseCeiling)
            + decay * offset) / frequency
        let settled = Self.pinchSettleTime
        settleZoomTask = Task { @MainActor [weak self] in
            let start = Date()
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                guard let self, !Task.isCancelled else { return }
                let t = Float(Date().timeIntervalSince(start))
                guard t < settled else {
                    self.arriveAtPreset(announces: announces)
                    return
                }
                let travel = exp(-decay * t) * (offset * cos(frequency * t) + phase * sin(frequency * t))
                self.pinchTrack = 1 + travel
                self.pinchScale = Self.bandedZoom(self.pinchTrack)
                self.applyCameraScale()
            }
        }
    }

    private func arriveAtPreset(announces: Bool) {
        pinchTrack = 1
        pinchScale = 1
        applyCameraScale()
        if announces { pinchArriveTick &+= 1 }
        settleZoomTask = nil
    }

    private static func bandedZoom(_ track: Float) -> Float {
        let zoom = log(max(track, .leastNormalMagnitude))
        if zoom > pinchResistCeilingLog {
            return exp(pinchResistCeilingLog + bandedTravel(zoom - pinchResistCeilingLog))
        }
        if zoom < pinchResistFloorLog {
            return exp(pinchResistFloorLog - bandedTravel(pinchResistFloorLog - zoom))
        }
        return exp(zoom)
    }

    private static func bandedTravel(_ past: Float) -> Float {
        (1 - 1 / (past * pinchBandGive / pinchBandSpan + 1)) * pinchBandSpan
    }

    func beginTurn() {
        glide?.cancel()
        if let pivot {
            let turn = pivot.orientation(relativeTo: nil)
            yaw = 2 * atan2(turn.vector.y, turn.vector.w)
        }
        turnBase = yaw
    }

    func turn(byPoints points: CGFloat) {
        yaw = turnBase + Float(points) * Self.radiansPerPoint
        applyOrientation()
    }

    func turn(byRadians radians: Float) {
        yaw += radians
        turnBase = yaw
        applyOrientation()
    }

    func endTurn(pointsPerSecond: CGFloat, reduceMotion: Bool) {
        turnBase = yaw
        guard !reduceMotion else { return }
        let carried = Float(pointsPerSecond) * Self.radiansPerPoint * Self.glideSeconds
        let target = yaw + min(max(carried, -Self.glideCeiling), Self.glideCeiling)
        guard abs(target - yaw) > 0.0005 else { return }
        glide(from: yaw, to: target)
    }

    private func glide(from start: Float, to target: Float) {
        glide?.cancel()
        let distance = target - start
        glide = Task { @MainActor [weak self] in
            for step in 1...Self.glideSteps {
                guard let self, !Task.isCancelled else { return }
                let t = Float(step) / Float(Self.glideSteps)
                self.yaw = start + distance * Self.glideCurve(t)
                self.applyOrientation()
                if step == Self.glideSteps {
                    self.turnBase = self.yaw
                    self.glide = nil
                    return
                }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    private static func glideCurve(_ t: Float) -> Float {
        let decay: Float = 5
        return (1 - exp(-decay * t)) / (1 - exp(-decay))
    }

    func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        pivot?.isEnabled = active
        guard !active else { return }
        glide?.cancel()
        switchID &+= 1
        switchTask?.cancel()

        settleZoomTask?.cancel()
        settleZoomTask = nil
        pinchTrack = 1
        pinchScale = 1
        applyCameraScale()
    }

    var turnDegrees: Int {
        let degrees = Int((yaw * 180 / Float.pi).rounded())
        return (degrees % 360 + 360) % 360
    }

    private func applyOrientation() {
        let turn = simd_quatf(angle: yaw, axis: SIMD3(0, 1, 0))
        pivot?.orientation = turn
        applyCameraPose()
        applyWallFade(turn)
    }

    private func applyCameraPose() {
        guard let camera, let framing else { return }
        let pose = framing.pose(yaw: yaw)
        camera.look(at: pose.aim, from: pose.position, relativeTo: nil)
    }

    private func applyWallFade(_ turn: simd_quatf) {
        for index in wallGroups.indices {

            let facingCamera = simd_dot(turn.act(wallGroups[index].facing), cameraBearing)
            let opacity = 1 - Self.smoothstep((facingCamera + Self.fadeBand) / (2 * Self.fadeBand))
            guard abs(opacity - wallOpacities[index]) > Self.fadeDeadband else { continue }
            wallOpacities[index] = opacity
            for entity in wallGroups[index].entities {

                entity.components.set(OpacityComponent(opacity: opacity))
            }
        }
    }

    private static func smoothstep(_ t: Float) -> Float {
        let x = min(max(t, 0), 1)
        return x * x * (3 - 2 * x)
    }
}
