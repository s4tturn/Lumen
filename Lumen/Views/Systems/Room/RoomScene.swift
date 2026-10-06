import SwiftUI

// MARK: - Room

/// An object the room only draws once its task is finished.
///
/// The room's whole reward system: a task is completed somewhere else in the
/// app, recorded in the keychain, and the object it names appears here. So a
/// room is a record of what has actually been done rather than a picture of a
/// house, and the list of what is missing is the list itself.
///
/// The names are the asset's own node names, and may sit at any depth — a
/// dumbbell three levels down inside a shoe rack is named as directly as a
/// wardrobe is. A name the scene does not carry is skipped rather than failing
/// the load, and an object named by nothing here is always drawn.
struct RoomReveal: Sendable {
    /// The task that earns it, and so the keychain record that decides.
    let task: CollectionTask.ID

    /// The nodes this task puts in the room. Several names for one task is the
    /// normal case, not an exception: "both shoes" is two nodes, and so is
    /// "every camera in the room".
    let nodes: [String]
}

/// One room the page can show: the asset it loads, the two ways it is named,
/// and the scene nodes that fade while it is on screen.
///
/// This is the whole room list. The tab renders `all`, the stage mounts whichever
/// entry it is pointed at — so adding a room is a USDZ beside the others and one
/// more case here, with nothing else to wire up.
struct RoomScene: Identifiable, Hashable, Sendable {
    /// The room's walls, and everything mounted on each: the wall itself first,
    /// then the objects that stand against it. Every node listed in one entry
    /// fades as one — the wall, and its subcomponents with it — and nothing else
    /// in the room is touched.
    ///
    /// Whichever two walls the camera stands closest to are the two that
    /// disappear, leaving the two behind them to describe the room, and the swap
    /// between them is a fade rather than a cut.
    ///
    /// The names are the asset's own node names, and each list below was read off
    /// that model: one wall plus whatever is fixed flat to it. Furniture that only
    /// happens to stand near a wall — a bed, a floor plant, a lamp — is left out,
    /// so the shell of the room stays where it is while its walls go.
    ///
    /// Edit freely: reorder the entries, split one wall's contents apart, add or
    /// drop names. Each wall's facing is measured from the loaded model rather
    /// than from its place in this list, so the fade follows the geometry, and a
    /// name the scene does not carry is simply skipped. An empty list is a room
    /// whose walls simply do not fade, and takes no other change to turn on.
    let walls: [[String]]

    /// The objects this room keeps hidden until their task is done, and which
    /// task earns each one.
    ///
    /// Everything not named here is drawn from the moment the room loads: the
    /// shell — walls, floor, windows, doors — and the furniture that is not a
    /// reward, such as a bed's frame or a rack's frame. The split is deliberate
    /// in that direction, because a room that starts as bare as its walls reads
    /// as unfinished rather than as somewhere to begin, and because a task with
    /// no object of its own still has to be worth finishing somewhere in the app.
    ///
    /// Nodes are named as deep as they are authored, so a reward can be one
    /// whole object (`"Wardrobe"`) or a single thing inside one
    /// (`"Dumbell_001"`). That is what makes "both shoes" and "all four
    /// dumbbells" expressible without hiding the rack they sit in.
    let reveals: [RoomReveal]

    /// The USDZ in `RoomAssets`, resolved from the app bundle by name.
    let assetName: String

    /// What this room is called. Read by VoiceOver — on the tab itself and on
    /// the page — and never drawn, so it stays the room's real name even where
    /// the tab has to shorten it.
    let title: LocalizedStringResource

    /// What the tab draws for this room. A single word, per HIG tab bars ("use
    /// single words whenever possible"): a label is the only way a symbol is
    /// navigable, and a room called "Living Room" would have to wrap or truncate
    /// in a bar that also has to fit "Kitchen". The full name rides along in
    /// `title`, which VoiceOver reads instead.
    let tabTitle: LocalizedStringResource

    /// The SF Symbol the tab draws for this room, unfilled: the tab fills it for
    /// whichever room is showing, so the symbol itself carries the selection.
    /// A symbol *name* rather than copy, so it is a plain `String` and nothing to
    /// look up in a table.
    let symbol: String

    /// Subtle tint for this room's glass while it is the one being shown.
    ///
    /// Optional because a room with no colour to say should say none: an
    /// untinted selected tab is simply the same glass every other tab is, which
    /// is a legitimate answer rather than a missing one. A room this switch does
    /// not name falls through to `nil` instead of to a default colour, so
    /// dropping a new room into `all` cannot quietly give it a tint nobody
    /// chose.
    ///
    /// Carried on the tab's own `Glass` value rather than painted behind the
    /// button, so it tints the one glass surface instead of adding a second one
    /// on top of it. Computed, because it is presentation only and has no
    /// business in the memberwise initializer the three rooms below are built
    /// with.
    var tabTint: Color? {
        switch self {
        case .bedroom: return .blue.opacity(0.3)
        case .livingRoom: return .red.opacity(0.25)
        case .kitchen: return .yellow.opacity(0.25)
        default: return nil
        }
    }

    /// Every room on offer, in tab order — which is also the order a flick reads
    /// to decide which way the room travels.
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
            // The two shoes, and all four dumbbells: named individually because
            // they sit on a rack that stays either way.
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

    /// Stable across launches, and unique per asset, so a mounted room and its
    /// cached model are keyed the same way everywhere.
    var id: String { assetName }

    /// Where this room sits in `all`. A flick travels from the room it is in
    /// towards the one the tab names, in this order.
    var order: Int { Self.all.firstIndex(of: self) ?? 0 }

    /// Two values are the same room when they name the same asset, and nothing
    /// else counts — which is what lets the stage compare a tab's choice against
    /// the room it has without caring how either was spelled.
    ///
    /// Spelled out rather than derived because the names are
    /// `LocalizedStringResource`, and that type is equatable but not hashable.
    static func == (lhs: RoomScene, rhs: RoomScene) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
import CoreGraphics
import Foundation
import RealityKit

// MARK: - Camera

/// The room's fixed isometric orthographic camera, and the framing that centres
/// and fits it.
///
/// The pose is authored: the pitch and yaw that put the camera on the room's own
/// diagonal, which is what makes the view read as isometric rather than as a
/// photograph. Everything else is measured — the geometry that is always drawn
/// decides how much of the frame it fills and where its middle lands, so a room of
/// any size centres on what is actually there.
///
/// That distinction is the whole reason this type carries the drawn silhouette
/// rather than just an aim point. A bounding box is a poor stand-in for a
/// silhouette: it is wider on screen than the room is, and the middle of its
/// projection is not the middle of the room. Projecting the geometry settles every
/// room at once, with no per-room correction to keep honest and nothing to re-tune
/// if an asset is re-exported.
///
/// The aim moves the eye and itself together, so it is a translation of the whole
/// camera across the view plane: the isometric angles are never touched, and the
/// pivot stays where it was put. Which means the aim can follow the turn — see
/// `pose(yaw:)` — without the room ever leaving its isometric, and without the
/// pivot moving off the middle to compensate.
struct RoomCamera {
    /// Downward tilt, in radians — `atan(1 / √2)`, the true isometric angle.
    static let pitch: Float = 35.264 * Float.pi / 180

    /// Azimuth, in radians. 45° looks along the room's diagonal, so the two
    /// visible walls meet on a centred vertical edge.
    static let yaw: Float = 45 * Float.pi / 180

    /// Near plane. Fixed and very close: the camera never approaches the
    /// geometry, so a small value only buys depth precision.
    static let near: Float = 0.01

    /// Share of the viewport the room's silhouette fills, on whichever of the two
    /// axes binds.
    ///
    /// Well past `1` on purpose, so the room is drawn larger than the frame that
    /// would contain it and its outer edges run off both sides. The progression,
    /// measured on a 393×852 viewport: `0.94` fitted to fit and came to 38% of the
    /// height, reading as a model on a shelf; `1.1` reached 45% and lost only the
    /// shell's outer 20 points at each side; `2.2` reached about 90% of the height,
    /// filling the screen from near the tab bar to near the bottom edge.
    ///
    /// Now `0.88`, which draws every room at a fifth of the size `4.4` gave it: the
    /// Kitchen that filled about 45% of the height at `4.4` fills about 9% here,
    /// and Bedroom and LivingRoom shrink with it. The trade moves with it — the frame
    /// holds the room whole several times over, so all four walls, the whole floor
    /// and a wide margin of empty space around them are in shot, and the room reads
    /// as a small object on a large stage rather than as somewhere you are looking
    /// into.
    ///
    /// Dividing rather than multiplying is the whole of the change, and the
    /// direction is worth being careful about. `scale(in:)` hands the camera
    /// `framed / (2 * fill)`, and `scale` is half the world the camera shows — so
    /// the drawn size of the room goes *with* `fill` and *against* `scale`. A larger
    /// `fill` frames a larger share of the room, which sounds like zooming in but is
    /// the same as shrinking the room inside a fixed frame. Reading `fill` as
    /// "how much of the frame the room fills" is the trap; it is actually "how much
    /// of the room the frame fills".
    ///
    /// Every room shares the one value, so a re-exported asset is re-framed by its
    /// own geometry rather than by a number here; see `RoomSceneFactory`.
    ///
    /// This is the preset a pinch scales on top of, so it stays where it is put
    /// rather than where a previous pinch left it.
    static let fill: Float = 0.88

    /// How far back the camera sits, per unit of room size. Twice the longest
    /// edge clears the room from every direction while keeping the near and far
    /// planes well apart.
    private static let standoffFactor: Float = 2

    /// The standoff for a room of this size. Static because the framing's own
    /// initializer needs it before any of this type exists — a room knows how far
    /// back to stand as soon as it has been measured.
    private static func standoff(for extents: SIMD3<Float>) -> Float {
        max(extents.x, extents.y, extents.z) * standoffFactor
    }

    /// How much further than the room's own longest edge the far plane reaches.
    private static let farFactor: Float = 8

    /// Screen right, in world space, for the pose above: the view direction
    /// flattened onto the ground plane and turned a quarter turn. Derived rather
    /// than composed from the angles directly, so the framing maths and the pose
    /// cannot disagree about which way is which.
    static let right: SIMD3<Float> = {
        let forward = SIMD3<Float>(cos(pitch) * cos(yaw), sin(pitch), cos(pitch) * sin(yaw))
        return simd_normalize(SIMD3<Float>(-forward.z, 0, forward.x))
    }()

    /// Screen up, in world space: the third axis of the same frame, with the
    /// camera's `upVector` pointing the same way `look(at:from:)` will.
    static let up: SIMD3<Float> = {
        let forward = SIMD3<Float>(cos(pitch) * cos(yaw), sin(pitch), cos(pitch) * sin(yaw))
        return simd_normalize(simd_cross(right, forward))
    }()

    /// How much of a box's own height each screen axis sees. Fixed for the life of
    /// the type, because the pivot only ever turns about the vertical — hoisted out
    /// of the per-turn loop rather than recomputed for every box.
    private static let rightOnHeight = abs(simd_dot(right, SIMD3<Float>(0, 1, 0)))
    private static let upOnHeight = abs(simd_dot(up, SIMD3<Float>(0, 1, 0)))

    /// Where the room turns: the middle of the geometry it draws, in world space.
    /// The pivot, and so the rotation axis.
    let center: SIMD3<Float>

    /// Axis-aligned size of the room in world space. Read for the standoff and the
    /// far plane, never for the framing — and measured over *every* mesh rather
    /// than only the drawn ones, so an object that arrives as a reward is never
    /// clipped by a room framed without it.
    let extents: SIMD3<Float>

    /// The drawn geometry, one box at a time, in pivot-local space. Read for the
    /// aim and for the size, and the reason both are measured per yaw.
    let silhouette: [RoomSilhouette]

    init(center: SIMD3<Float>, extents: SIMD3<Float>, silhouette: [RoomSilhouette]) {
        // Both of the values that only ever come from a room standing square to
        // its own front are measured here, once, off the same walk of the
        // geometry that the rest of the type is built on — so constructing the
        // framing is the only place the silhouette is measured at rest, and
        // neither number is ever derived again.
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

    /// The room's drawn size, in screen axes, in the same units as `center`.
    ///
    /// Read at `yaw: 0` and so square to the room's own front, which is how every
    /// room is first shown and the one angle the frame is fitted for.
    let size: SIMD2<Float>

    /// Which side of the room the camera stands on: the horizontal direction from
    /// the room's centre out to the eye, flattened onto the ground plane.
    ///
    /// This is the one value the walls are judged against — a wall whose own
    /// facing agrees with it is between the camera and the room, and is the one
    /// that has to get out of the way.
    let bearing: SIMD3<Float>

    /// How far back the camera sits. Twice the longest edge clears the room from
    /// every direction while keeping near and far planes well apart.
    var standoff: Float {
        Self.standoff(for: extents)
    }

    /// Far plane, with room to spare over the standoff.
    var far: Float {
        max(extents.x, extents.y, extents.z, 1) * Self.farFactor
    }

    /// Half the world width the camera shows. `scaleDirection` is horizontal, so
    /// this is half the frame's width and the height follows from the render
    /// target's aspect.
    ///
    /// The frame is as wide as the room needs and no wider: `size.x` to fill the
    /// width, or `size.y * aspect` to fill the height, whichever is larger. A
    /// room drawn diagonally is far wider than it is tall on any phone, so the
    /// width is what binds in practice — but the height term is what keeps a tall
    /// room, a landscape window or an iPad from having its ceiling cropped.
    ///
    /// Fitted square to the room, and left there through the turn: a silhouette
    /// grows and shrinks as it turns, and re-fitting to each angle would make the
    /// room breathe in and out in the hand rather than turn.
    ///
    /// Falls back to fitting the width alone if there is no viewport yet, which
    /// leaves the room framed and merely a little tight until the first real size
    /// arrives and `RoomStage` re-fits it.
    func scale(in viewport: CGSize) -> Float {
        let width = Float(viewport.width)
        let height = Float(viewport.height)
        let framed = width > 0 && height > 0
            ? max(size.x, size.y * (width / height))
            : size.x
        return framed / (2 * Self.fill)
    }

    /// Which side of the room the camera stands on, read off a pose.
    ///
    /// Read square to the room's front like the frame itself is, because the walls
    /// are only ever compared against the view they were drawn for.
    ///
    /// Measured from the room's own middle rather than from the aim, so the
    /// silhouette's offset counts: the two are different points, and the walls are
    /// judged against where the room is, not where the camera was pointed.
    private static func bearing(of position: SIMD3<Float>, from center: SIMD3<Float>) -> SIMD3<Float> {
        let offset = position - center
        let horizontal = SIMD3<Float>(offset.x, 0, offset.z)
        let distance = simd_length(horizontal)
        return distance > 0 ? horizontal / distance : SIMD3<Float>(0, 0, 1)
    }

    /// Where the camera looks, and where it sits, for a room whose drawn middle
    /// lands `offset` from the pivot.
    ///
    /// The two are one measurement: the position is the aim stepped back along the
    /// pose's own diagonal, so the eye moves and looks together and the isometric
    /// angles are never touched. Taken together because every caller wants both —
    /// aiming is the one operation — and taking them separately walks the room's
    /// geometry twice to answer one question.
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

    /// The room's camera pose with the room turned `yaw`.
    ///
    /// Recomputed for the yaw rather than measured once, and that is what keeps a
    /// room centred at *every* angle instead of only the one it was framed at: the
    /// rotation carries the silhouette across the frame while the pivot sits still,
    /// so a fixed aim leaves the room visibly off-centre as it turns — by up to
    /// half a frame's width on the Kitchen, near a degree in at 45° on the other
    /// two. Following it costs a rectangle per box on the axis of the turn, and buys
    /// centring that does not drift.
    ///
    /// A function of the turn and nothing else, so it moves only when the room
    /// does. The glide that carries a flick, a reduced-motion placement and a drag
    /// all reach the same pose for the same `yaw`.
    func pose(yaw: Float) -> (aim: SIMD3<Float>, position: SIMD3<Float>) {
        Self.pose(
            offset: Self.screenBounds(silhouette, yaw: yaw).offset,
            center: center,
            standoff: standoff
        )
    }

    /// Builds the camera entity. The camera is parentless, so aiming it in
    /// world space is its final placement. Square to the room's own front, which is
    /// how every room is first shown.
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

    /// Where the drawn geometry lands on screen with the room turned `yaw`, and
    /// what it means as an aim.
    ///
    /// Two numbers come out of it and they answer different questions. `size` is
    /// how large the room is drawn, and is read square to the room's front, once.
    /// `offset` is how far the drawn middle sits from the pivot itself, and is read
    /// again on every turn sample.
    ///
    /// Static, and handed the silhouette rather than reading it, because this is
    /// the only walk of the room's geometry that happens more than once per turn —
    /// and it needs to know nothing but the boxes.
    private static func screenBounds(
        _ silhouette: [RoomSilhouette],
        yaw: Float
    ) -> (offset: SIMD2<Float>, size: SIMD2<Float>) {
        // Nothing to measure: a unit box centred on the pivot, so a room with no
        // geometry is framed on its own middle at a fixed size rather than
        // dividing by the extent of an empty rectangle.
        guard !silhouette.isEmpty else {
            return (SIMD2<Float>.zero, SIMD2<Float>(repeating: 1))
        }

        // The room's own axes once the pivot has turned it. X and Z swing round
        // the vertical; Y does not move at all, which is what `rightOnHeight` and
        // `upOnHeight` already account for.
        let cosine = cos(yaw), sine = sin(yaw)
        let swung = (SIMD3<Float>(cosine, 0, -sine), SIMD3<Float>(sine, 0, cosine))

        // How much of a box turned to `swung` each screen axis reaches. This is
        // the support function of a rotated box, so a turn costs one dot product
        // per box per axis rather than eight corners per box.
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
        // Already measured from the pivot: every box's offset is pivot-relative and
        // the turn keeps it that way, so the middle of the range is the offset to
        // move the pivot by. `aim` adds it to a `center` that already *is* the
        // pivot, so subtracting the pivot's own projection here as well counted it
        // twice and left the room off-centre.
        return ((lo + hi) / 2, hi - lo)
    }
}
import RealityKit

// MARK: - Bounds

/// An axis-aligned box by its two opposite corners.
///
/// RealityKit measures geometry as a `BoundingBox` — a middle and a whole size —
/// but every question the room asks of a box is about a corner: where the room
/// starts and stops, how far one mesh reaches past the rest, which way a wall
/// looks. Holding the corners rather than re-deriving them from the middle at
/// every question is what lets the whole of the framing walk below be written
/// once instead of three times.
struct RoomBounds {
    /// The corner with the smallest value on every axis.
    let lo: SIMD3<Float>

    /// The corner with the largest value on every axis.
    let hi: SIMD3<Float>

    /// Middle of the box.
    var mid: SIMD3<Float> { (lo + hi) / 2 }

    /// Whole size of the box along each axis.
    var extents: SIMD3<Float> { hi - lo }

    /// The smallest box containing all of `boxes`.
    ///
    /// Nothing in it. A union with nothing in it is the whole of it, so an empty
    /// input is left to read as that rather than special-cased here — every caller
    /// has something to measure, and the ones that might not already say so.
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

    /// The smallest box containing both of these.
    func united(with other: RoomBounds) -> RoomBounds {
        RoomBounds(lo: simd_min(lo, other.lo), hi: simd_max(hi, other.hi))
    }

    /// Whether this box reaches more than half again past `rest` on any axis.
    ///
    /// That is the test for a mesh that has come loose from the room it is in: a
    /// shirt in a wardrobe hanging tens of metres below the floor, say. It cannot
    /// be a wall, because the four walls share the room's extremes and so no one
    /// of them owns them.
    func overhangs(_ rest: RoomBounds) -> Bool {
        let slack = rest.extents / 2
        return lo.x < rest.lo.x - slack.x || hi.x > rest.hi.x + slack.x
            || lo.y < rest.lo.y - slack.y || hi.y > rest.hi.y + slack.y
            || lo.z < rest.lo.z - slack.z || hi.z > rest.hi.z + slack.z
    }
}

// MARK: - Silhouette

/// One box of the geometry a room draws before any task is done, in the space its
/// pivot turns it in.
///
/// Kept rather than discarded once the frame has been fitted, because the room
/// turns. A room is not a symmetric box, so its silhouette crosses the frame as it
/// turns even though the pivot never moves — the drawn middle is the frame's middle
/// only at the angle it was measured at. These are the only numbers re-aiming needs:
/// a centre and three half-extents, fifteen of them for the Kitchen and thirty-five
/// for the Bedroom, which is nothing beside walking the graph.
struct RoomSilhouette {
    /// Middle of the box, measured from the pivot. Pivot-relative because that is
    /// the space the turn happens in.
    let offset: SIMD3<Float>

    /// Half the box's size along each of its own three axes.
    ///
    /// A half, not a length: RealityKit's `BoundingBox.extents` is the box's whole
    /// size, and `RoomBounds` already halves it to find the corners. Framing
    /// that used the extents as if they were halves measured every silhouette twice
    /// as large as it is, which both halves the room's drawn size and moves the aim
    /// off the middle of what is actually there.
    let half: SIMD3<Float>
}
import RealityKit
import SwiftUI

// MARK: - Reality Stage

/// The RealityKit surface: loads a room, hands the graph to `stage`, and swaps
/// one room for another without ever being rebuilt.
///
/// The stage keeps this one view for the whole page, so a switch is content
/// changing rather than a view being created and thrown away. `make` does the
/// first load — the only place an `await` belongs, since it is the only closure
/// that can suspend — and `update` reconciles every room after that.
struct RoomRealityStage: View {
    let stage: RoomStage
    let scene: RoomScene

    var body: some View {
        RealityView { content in
            // A virtual (non-AR) camera, and the neutral environment: the room
            // is lit by the asset, not by the room it happens to be in.
            content.camera = .virtual
            content.environment = .default

            guard await stage.graph(for: scene) != nil else { return }
            stage.mount(scene, in: &content)
        } update: { content in
            // Reached on every update pass, which is how a swap lands: `travel`
            // names the incoming room, the view reads it, and this hands it over.
            // The stage decides whether there is anything to do — a pass with the
            // same room as last time is a no-op, and so is every pass that is not
            // part of a switch.
            stage.mount(scene, in: &content)
        }
        // The RealityKit surface itself: where the room is drawn, and
        // the frame that travels with it through a switch.
        .debugSurfaceBorder()
    }
}
import CoreGraphics
import Foundation
import Observation
import RealityKit
import SwiftUI

// MARK: - Stage

/// The room's state, and the only thing in the page allowed to touch RealityKit.
///
/// The split that makes this fast: `slide` and `fade` are observed, and
/// everything a drag touches is not. Turning the room writes
/// `@ObservationIgnored` properties and the pivot's orientation, so a drag
/// sample reaches no SwiftUI body at all — which is the entire cost of a turn.
///
/// Wall fading rides that same path: the turn also writes each wall's opacity,
/// from state SwiftUI never sees, so hiding the walls the camera looks over
/// costs no body evaluation either.
///
/// Switching rooms is the one thing here that does drive SwiftUI, because it is
/// a transition and a transition is the view's job. `slide` and `fade` are the
/// two numbers it reads; each is written twice per switch, at the start of a leg
/// and at the end of one, so a switch costs two body evaluations rather than one
/// per frame.
@MainActor
@Observable
final class RoomStage {
    /// Cosine of the angle a wall fades across, measured between the way the
    /// wall faces and the way the camera looks. Outside the band a wall is
    /// either opaque or invisible; inside it, a smoothstep between the two.
    /// Roughly 40° of turning, wide enough that a drag crosses the whole band
    /// instead of snapping across it.
    private static let fadeBand: Float = 0.35

    /// Opacity change too small to see, so a drag only writes a wall once it
    /// has actually moved.
    private static let fadeDeadband: Float = 0.002

    /// How far a switch takes the room, in page widths.
    ///
    /// A third of the page, and it recedes as it goes — see `travelRecede`. The
    /// room has to be gone before the swap, but gone is not the same as travelled
    /// a whole screen's width: a full-width move puts two rooms a page apart in
    /// a transition that lasts a third of a second, which reads as a page flip
    /// rather than as the same room changing its mind. What actually hides the
    /// swap is the fade, not the distance, so the travel only has to read as
    /// direction.
    static let travelDistance: CGFloat = 0.3

    /// How much smaller the room is drawn at the far end of a switch, per unit of
    /// travel. Paired with the fade so the room recedes as it leaves instead of
    /// sliding flat across the screen, which is what stops a lateral move from
    /// looking like a poster being dragged.
    static let travelRecede: CGFloat = 0.12

    /// Radians of turn per point of horizontal travel. Tuned so a drag across
    /// half the circle sweeps the room about 90°, which is the wrist movement
    /// that feels like turning something rather than flicking it.
    private static let radiansPerPoint: Float = 0.01

    /// Seconds of coast a flick at one radian per second carries, and the hard
    /// ceiling on the result. Together they are the whole of the momentum: a
    /// hard shove runs into the ceiling and turns about a quarter turn, a gentle
    /// one coasts a little, and letting go after a careful placement coasts not
    /// at all.
    private static let glideSeconds: Float = 0.16
    private static let glideCeiling: Float = 1.2

    /// Steps in the glide, at the refresh rate. The coast is stepped rather than
    /// timed because a stepped coast is monotonic by construction: no frame
    /// overruns into the next one, and no wall's opacity is ever written twice
    /// for the same sample.
    private static let glideSteps = 34

    /// The two ends of what an ordinary pinch reaches — a quarter
    /// smaller, half again larger. Past either one the band takes over, so these
    /// are where resistance *begins* rather than where the room stops: a determined push
    /// still gets past both, by about an eighth.
    ///
    /// The asymmetry is the requested range's own, not a tuning artefact. The zoom
    /// is a multiplier on a preset of `1`, so reaching `1.5` is half again as much
    /// room as reaching `0.75` is the other way, and no tuning makes a multiplier
    /// arrive at its two ends in equal travel.
    private static let pinchResistFloor: Float = 0.75
    private static let pinchResistCeiling: Float = 1.5

    /// those two ends as logarithms, because that is the axis perceived
    /// size change is linear in. See `bandedZoom`.
    private static let pinchResistFloorLog = log(pinchResistFloor)
    private static let pinchResistCeilingLog = log(pinchResistCeiling)

    /// how much of the fingers' travel the room gives away at the edge of
    /// the range. Apple's own constant for its scroll rubber band, and kept rather
    /// than invented — a band measured by anything else stops being the platform's
    /// band.
    private static let pinchBandGive: Float = 0.55

    /// how far past an end the room can be pushed at all, in log zoom.
    ///
    /// The band's ceiling, and so the whole of how hard the limit is: the room gives
    /// `pinchBandGive` of every point at the edge and steadily less after that, so
    /// a third of a pinch of pure effort buys the last eighth and everything between is
    /// a fight. Measured in log zoom so the far end — which has the most room to grow
    /// into — resists exactly as much as the near one.
    private static let pinchBandSpan: Float = 0.35

    /// how far back inside the range a pinch must come before the band
    /// will announce itself again. Without it a hand resting on the edge would tick
    /// twice a second, which is the whole difference between a limit that is felt
    /// and one that is infuriating.
    private static let pinchBandGap: Float = 0.03

    /// zoom change too small to see, so a pinch only writes the camera
    /// once the fingers have actually moved.
    private static let pinchDeadband: Float = 0.001

    /// the zoom a pinch has to have travelled before arriving back at the
    /// preset is worth announcing. Under it the spring is a rounding error and a tick
    /// would be reporting something nobody could have seen.
    private static let pinchSettleAt: Float = 0.02

    /// the settle spring as an undamped angular frequency and a damping
    /// ratio rather than as a duration and a bounce, because that is the pair whose
    /// closed form takes a release velocity in at the front.
    ///
    /// `16` puts the return at about half a second, the drag-release band; `0.7` is
    /// one clearly visible overshoot of under 5% of the distance travelled and then
    /// nothing. A pinch is a drag release, so that overshoot is earned — stopping
    /// dead after moving the room should feel like letting go of something elastic
    /// rather than like a value being assigned.
    private static let pinchSettleRate: Float = 16
    private static let pinchSettleDamping: Float = 0.7

    /// the fraction of the distance travelled the settle has to fall
    /// inside before it counts as over.
    private static let pinchSettleTolerance: Float = 0.002

    /// how long the settle runs, written as the spring's own settling time
    /// rather than as a number beside it, so retuning the spring cannot leave a
    /// duration behind it.
    private static var pinchSettleTime: Float {
        -log(pinchSettleTolerance) / (pinchSettleDamping * pinchSettleRate)
    }

    /// the fastest release the settle will carry, in zooms a second. A
    /// hard fling is allowed to throw the room a long way past the preset on the way
    /// back — that is the bounce the release has earned — but not so far that the
    /// room sails through its own framing on the way out as well.
    private static let pinchReleaseCeiling: Float = 2.5

    /// The room the tab names: where a switch is heading.
    private(set) var selection: RoomScene = .bedroom

    /// The room the page has committed to showing. `selection` asks for a room,
    /// this is the ask, and the two part company for exactly one update pass —
    /// the pass in which `mount` answers it.
    private(set) var shown: RoomScene = .bedroom

    /// How far the room has travelled out of frame, in page widths: `0` is
    /// seated and `±travelDistance` is the far end of a switch. Signed, so
    /// negative is off the leading edge and positive off the trailing one.
    private(set) var slide: CGFloat = 0

    /// How solid the room is. It leaves on every switch, so the swap behind it
    /// is never drawn, and Reduce Motion takes the travel away as well and leaves
    /// this alone — a dissolve is the whole of that switch.
    private(set) var fade: Double = 1

    /// Bumped once a switch has landed, so the selection haptic rides the pixels
    /// rather than a timer running beside them.
    private(set) var settleTick = 0

    /// bumped when the pinch's band takes hold, so the soft impact lands
    /// on the instant the room stops keeping up with the fingers. Deliberately a
    /// different event from the one below, and a different feedback: this one means
    /// *push harder*, that one means *stop*, and a single haptic cannot say both.
    private(set) var pinchTick = 0

    /// bumped once the pinch has sprung the room back to the preset, so
    /// the tick lands with the framing rather than with the fingers leaving — the
    /// same argument `settleTick` makes for a switch.
    private(set) var pinchArriveTick = 0

    /// Carries the room, and so carries the rotation a drag writes.
    @ObservationIgnored private var pivot: Entity?

    /// Aims at it. Separate from the pivot because it is parentless, and because
    /// two of them cannot be live at once.
    @ObservationIgnored private var camera: Entity?

    /// The room's framing, kept so a new viewport can re-fit the camera without
    /// loading or rebuilding anything.
    @ObservationIgnored private var framing: RoomCamera?

    /// The page's size in points, and so the aspect the room is fitted to. Zero
    /// until the page has been laid out once.
    @ObservationIgnored private var viewport: CGSize = .zero

    /// The room the mounted graph actually belongs to, and `nil` until one is.
    ///
    /// Not `shown`. `shown` is what the page has *asked* for, and it is already
    /// the new room by the time `mount` is reached — so comparing against it
    /// would find the room it is being asked to mount already mounted, and no
    /// switch would ever swap anything. This is what `mount` records having done,
    /// which is the only thing that can answer "is this the room already here?".
    @ObservationIgnored private var mounted: RoomScene?

    /// The declared walls, resolved against the loaded model.
    @ObservationIgnored private var wallGroups: [RoomWallGroup] = []

    /// The room's rewards, resolved against the loaded model.
    @ObservationIgnored private var revealGroups: [RoomRevealGroup] = []

    /// Which tasks have been finished, and so which rewards are earned.
    ///
    /// Written from the completion store and read only when a room is installed
    /// or a completion lands, never per frame. Held here rather than consulted
    /// from the graph so that mounting a room — which happens off the back of a
    /// keychain read — settles on the same answer as the one already on screen.
    @ObservationIgnored private var earned: Set<CollectionTask.ID> = []

    /// Opacity last written to each wall. Seeded outside `0...1` so the first
    /// turn always writes and a freshly loaded room starts faded correctly.
    @ObservationIgnored private var wallOpacities: [Float] = []

    /// Which side of the room the camera stands on.
    @ObservationIgnored private var cameraBearing: SIMD3<Float> = SIMD3(0, 0, 1)

    /// Running rotation in radians, accumulated rather than published.
    @ObservationIgnored private var yaw: Float = 0

    /// Where the drag in progress began. Held here rather than in the gesture so
    /// that a switch — which resets `yaw` to zero for a room that is shown square
    /// to its own front — cannot leave a stale base behind for the next drag to
    /// jump from.
    @ObservationIgnored private var turnBase: Float = 0

    /// The coast a flick handed off, if one is running. Cancelled by the next
    /// drag rather than raced, so a room is only ever turned by one thing.
    @ObservationIgnored private var glide: Task<Void, Never>?

    /// Where the fingers have put the zoom, before the band has had its
    /// say. Written by the gesture and by the settle spring alike, and the only thing
    /// either of them means — `pinchScale` is what that comes out as once banded.
    ///
    /// Kept apart from the drawn zoom so the spring can overshoot without breaking
    /// the limit: the band is applied to the track on every step, so an overshoot is
    /// resisted on the way out and let go on the way back. A spring written straight
    /// to what is drawn would sail the room past its own band on a hard fling, and put
    /// the wall straight back.
    @ObservationIgnored private var pinchTrack: Float = 1

    /// the zoom actually written to the camera. Equal to `pinchTrack`
    /// between the ends of the range, so a pinch there is the fingers 1:1, which is
    /// most of what makes it feel direct.
    @ObservationIgnored private var pinchScale: Float = 1

    /// the track this pinch opened from, so each sample multiplies onto
    /// where the room already is rather than snapping to `1` and jumping. The track
    /// rather than the drawn zoom, so a pinch that grabs the room mid-settle picks up
    /// from where the settle had reached rather than from a point behind it.
    @ObservationIgnored private var pinchBase: Float = 1

    /// whether the band has announced itself since the pinch last came
    /// properly back inside the range. Re-arms it, so a pinch held on the edge ticks
    /// once rather than sixty times a second.
    @ObservationIgnored private var pinchAnnounced = false

    /// the spring back to the preset, if one is running. Cancelled by the
    /// next pinch rather than raced, so the two never both write the frame.
    @ObservationIgnored private var settleZoomTask: Task<Void, Never>?

    /// Whether the room's graph participates in the scene. Off-live pages park
    /// the whole pivot (the camera stays enabled), collapsing RealityKit's
    /// per-frame GPU work to nothing while keeping the warm asset. Stored so a
    /// load that lands while off-live starts parked.
    @ObservationIgnored private var isActive = true

    /// Every room's graph, loaded and resolved once and kept. A room that has been
    /// seen is then a graph swap rather than a load and a walk of its geometry,
    /// which is what keeps the middle of a switch invisible.
    @ObservationIgnored private var graphs: [RoomScene.ID: RoomSceneGraph] = [:]

    /// The switch in flight, if any. Superseded rather than queued, and dropped
    /// when the page goes off-live: a room nobody is looking at has no reason to
    /// keep travelling.
    @ObservationIgnored private var switchTask: Task<Void, Never>?

    /// Bumped by every `select` and every park, so a switch that has been
    /// overtaken can tell, at its next step, that it is no longer the one driving.
    @ObservationIgnored private var switchID: Int = 0

    // MARK: - Loading and mounting

    /// The graph for `scene`, resolved on first ask and kept after that, or `nil`
    /// if the room's asset is not in the bundle.
    ///
    /// The load is the only part that suspends — `Entity(named:)` is async — so
    /// the graph is built around it and every later ask is a dictionary lookup.
    /// Both halves matter for the same reason: a room that has already been seen
    /// must come back in one frame, and re-measuring thirty meshes would not.
    ///
    /// A room whose asset fails to load is not cached, so a room added to the
    /// bundle later in the same launch is still found by the next ask.
    @discardableResult
    func graph(for scene: RoomScene) async -> RoomSceneGraph? {
        if let cached = graphs[scene.id] { return cached }
        guard let model = await RoomSceneFactory.load(scene) else { return nil }
        let graph = RoomSceneFactory.resolve(scene, from: model, viewport: viewport)
        graphs[scene.id] = graph
        return graph
    }

    /// Warms every room that is not the one on screen, so the middle of a switch
    /// finds its graph already in hand.
    func prefetchOthers() async {
        for scene in RoomScene.all where scene != shown {
            await graph(for: scene)
        }
    }

    /// Puts `scene` in the scene, replacing whatever was there, and records that
    /// it is there.
    ///
    /// Called from the view on every update, so the guard is what keeps it free:
    /// the room already in the scene being `scene` is a no-op, and a room whose
    /// asset has not arrived yet is left alone until it has — at which point the
    /// next update mounts it.
    ///
    /// Entirely a lookup and two scene writes. The graph was built once when the
    /// room was loaded, so coming back to a room costs what going to it costs,
    /// and the pivot comes back carrying nothing: it is the same pivot, so the
    /// room that leaves is the room that returns, with its own lighting and its
    /// own resolved walls still attached.
    func mount(_ scene: RoomScene, in content: inout RealityViewCameraContent) {
        guard mounted != scene, let graph = graphs[scene.id] else { return }

        // The outgoing room leaves the scene before the incoming one joins it, so
        // there is never a moment with two live cameras, and the room that is
        // gone stops costing GPU work the instant it goes.
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

    // MARK: - Switching rooms

    /// Names `scene` as the room to show, and flicks the room sideways to it.
    ///
    /// A second press supersedes a switch already running rather than queueing
    /// behind it: the tab has already moved, so the room has to follow, and a
    /// switch retargets mid-travel more gracefully than it could queue.
    func select(_ scene: RoomScene, reduceMotion: Bool) {
        guard scene != selection else { return }
        selection = scene
        runSwitch(reduceMotion: reduceMotion)
    }

    /// Starts (or restarts) the switch, invalidating whichever one was running.
    private func runSwitch(reduceMotion: Bool) {
        switchID &+= 1
        let id = switchID
        switchTask?.cancel()
        switchTask = Task { await travel(id, reduceMotion: reduceMotion) }
    }

    /// The switch: out and faded, swap, back in the other direction.
    ///
    /// One loop drives it and every leg reads `selection` afresh, so nothing
    /// here has to know what a previous press intended. That is what makes the
    /// turn-around free: the resting place is `0` whichever room is there, so a
    /// press that changes the destination mid-travel simply retargets the same
    /// offset and the room carries on out the far side rather than stopping.
    ///
    /// The swap happens at the far end of the travel, where the room has faded
    /// out, so the seam between two rooms is never drawn — the fade is what hides
    /// it, which is why the travel can be a third of a page instead of a whole
    /// one. Handing over the seat is one write of `shown`, and the view's next
    /// update pass is what actually puts the other model in the scene, so the room
    /// has to be fully faded before that write.
    private func travel(_ id: Int, reduceMotion: Bool) async {
        while shown != selection || slide != 0 || fade != 1 {
            guard shown != selection else {
                // The room on screen is the one named: come to rest at the seat.
                // Both branches wrote the same two values, so this leg is an
                // ordinary gated settle rather than a hand-written pair:
                // under Reduce Motion `slide` is already `0`, so writing it
                // again is a no-op, and the loop's exit condition stays
                // provable on one path instead of two.
                await animate(UIConstants.Animation.reduceMotionGate(UIConstants.Animation.commit, reduceMotion: reduceMotion)) {
                    self.slide = 0
                    self.fade = 1
                }
                guard id == switchID else { return }
                if slide == 0, fade == 1 { settleTick &+= 1 }
                continue
            }

            // A different room is named: leave through the edge the tab moved
            // towards. Onwards leaves through the leading edge and back through
            // the trailing one, so the room always travels the way the tab went.
            let out: CGFloat = selection.order > shown.order ? -1 : 1
            // Branched rather than gated, and this is the one place in the
            // app where it has to be: under Reduce Motion the two legs change
            // *different* things, not the same things faster. A gate can
            // shorten an animation but it cannot take the movement out of one,
            // so the room fades where it stands instead of leaving — which is
            // the crossfade rung, and the right substitute for travel.
            if reduceMotion {
                await animate(UIConstants.Animation.reduced) { self.fade = 0 }
            } else {
                await animate(UIConstants.Animation.commit) {
                    self.slide = out * Self.travelDistance
                    self.fade = 0
                }
            }
            guard id == switchID else { return }

            // The incoming room has to be in hand before the seat is handed
            // over, or the swap would be a load rather than a graph change. The
            // prefetch has normally already done it, so this returns without
            // suspending.
            let incoming = await graph(for: selection)
            guard id == switchID else { return }
            guard incoming != nil else {
                // Its asset is not in the bundle. Leaving the room where it is
                // and putting the tab back on it is the only answer that keeps
                // the control and the room telling the same story.
                selection = shown
                return
            }

            // Naming the other room here is all it takes: the view reads `shown`,
            // so the swap follows on the next update pass, while the room is
            // faded out and the exchange is never seen.
            shown = selection
            if !reduceMotion {
                // The room is now the selected one, faded out on the far side,
                // about to arrive. Instant, because the halfway point of a
                // switch is a cut, not something to interpolate into.
                withoutAnimation { self.slide = -out * Self.travelDistance }
            }
        }
    }

    /// Applies `change` under `animation` and waits for it to land, so a switch
    /// reads as a straight line of steps instead of a nest of completion
    /// handlers.
    ///
    /// `completionCriteria: .logicallyComplete` rather than `.removed`, because a
    /// switch's leg is a value that is *set*, not a view that leaves: the moment
    /// SwiftUI considers the change applied is the moment the room has arrived,
    /// whereas `.removed` would hold the switch open until the animated subtree
    /// itself was torn down — for a room that is about to be swapped, that is later
    /// than the pixels.
    ///
    /// The trailing closure is the `completion`, not the change: `change` is the
    /// labelled body argument in between, so this waits for the animation to
    /// finish rather than resuming the continuation inside it.
    private func animate(_ animation: Animation, _ change: () -> Void) async {
        await withCheckedContinuation { continuation in
            withAnimation(animation, completionCriteria: .logicallyComplete, change) {
                continuation.resume()
            }
        }
    }

    /// Applies `change` with no animation at all, for the one step of a switch
    /// that has to cut.
    private func withoutAnimation(_ change: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, change)
    }

    // MARK: - The room itself

    /// Takes ownership of a freshly resolved room.
    private func install(_ graph: RoomSceneGraph) {
        framing = graph.framing
        wallGroups = graph.walls
        wallOpacities = Array(repeating: -1, count: graph.walls.count)
        revealGroups = graph.reveals
        cameraBearing = graph.cameraBearing
        // Each room is shown square to its own front: a turn belongs to the room
        // it was made in, not to the page. A drag can land before the asset does;
        // replaying the rotation rather than dropping it keeps that promise, and
        // the same write takes the base with it so the next drag starts from here.
        glide?.cancel()
        yaw = 0
        turnBase = 0
        applyOrientation()
        pivot?.isEnabled = isActive
        // The camera arrives framed by the factory, which knows the viewport but
        // not the zoom; re-writing it here means a room that mounts while a pinch
        // is in flight keeps the same zoom the one it replaced had.
        applyCameraScale()
        applyReveals()
    }

    /// Records which tasks have been finished, and shows the objects they earn.
    ///
    /// Called when a completion lands and when the page appears. Early-out when
    /// the set has not changed, so appearing twice — a page rebuilt, a scene
    /// phase bounce — costs one comparison rather than thirty writes.
    ///
    /// Writing to `isEnabled` rather than to an opacity is what makes a hidden
    /// object cost nothing: RealityKit skips a disabled subtree outright, so a
    /// room with half its rewards unearned is genuinely cheaper to draw than one
    /// with all of them.
    func setEarned(_ tasks: Set<CollectionTask.ID>) {
        guard tasks != earned else { return }
        earned = tasks
        applyReveals()
    }

    /// Puts every reward in the room into the state its task has earned.
    ///
    /// The whole set is written on every call rather than diffed, because a
    /// change to this set means at least one object has to be written anyway,
    /// and thirty boolean writes are cheaper than thirty comparisons chosen to
    /// skip them. Nothing here is observed, so no SwiftUI body is evaluated for
    /// a completion — the room gains an object the way the wall fade gains an
    /// opacity, from state the view never reads.
    private func applyReveals() {
        for group in revealGroups {
            let visible = earned.contains(group.task)
            for entity in group.entities { entity.isEnabled = visible }
        }
    }

    /// The page's size in points, and so the aspect the room is fitted to.
    ///
    /// Fitting reads the render target's aspect because the camera's scale is
    /// horizontal: what it sets is how wide the frame is, and the height is
    /// whatever that works out to. So the frame has to be fitted to the viewport
    /// it is drawn into, and re-fitted whenever that viewport changes — a
    /// rotation, a split view, a window drag — or a room that was framed for a
    /// portrait screen would be measured against a landscape one.
    ///
    /// Refitting is one write to one component; nothing is rebuilt and no model
    /// is touched.
    func setViewport(_ size: CGSize) {
        guard size != viewport, size.width > 0, size.height > 0 else { return }
        viewport = size
        applyCameraScale()
    }

    /// Writes the camera's frame, and is the only place that does.
    ///
    /// One writer because the frame answers to three independent things — the
    /// page's aspect and the pinch riding on top of it — and a path that set one while
    /// forgetting the other would leave the room drawn at a zoom nobody asked for.
    ///
    /// Divided rather than multiplied, since a larger scale is a wider frame and the
    /// pinch's factor is a magnification of the room.
    ///
    /// A no-op until the room is loaded and the page measured, which is the same
    /// condition the camera is created under anyway.
    private func applyCameraScale() {
        guard let camera,
              var component = camera.components[OrthographicCameraComponent.self],
              let framing,
              viewport.width > 0, viewport.height > 0
        else { return }
        component.scale = framing.scale(in: viewport) / pinchScale
        camera.components.set(component)
    }

    // MARK: - Pinch to zoom

    /// opens a pinch on the room's current zoom.
    ///
    /// Undoes any turn the pinch gesture got in first, which is the whole reason
    /// this is here rather than only clamping the sample. A two-finger touch on the
    /// turn handle also reaches the turn, and which of the two claims the touch
    /// first is a coin flip: when the turn wins it applies a sample or two before
    /// the pinch is recognised, so the room drifts a fraction of a degree sideways
    /// for a gesture that was meant only to zoom it. `turnBase` is where the room
    /// stood when this touch landed, so restoring it is an exact undo — and costs
    /// nothing when no turn was under way, because `turnBase` and `yaw` are then
    /// already the same number.
    ///
    /// Opening from the track rather than from what is drawn is what makes a pinch
    /// landing on a room mid-settle continuous: the settle stops where it had reached,
    /// and the fingers pick up from there rather than from a point the band was
    /// holding behind them.
    func beginPinch() {
        yaw = turnBase
        settleZoomTask?.cancel()
        settleZoomTask = nil
        pinchBase = pinchTrack
    }

    /// tracks a pinch, following the fingers exactly between the ends of
    /// the range and letting the band hold the room back outside it.
    func updatePinch(scale: Float) {
        let track = pinchBase * scale
        // Written whatever happens next: the track is where the fingers are, not what
        // is on screen, so a sample too small to draw still has to move it.
        pinchTrack = track
        let zoom = Self.bandedZoom(track)
        guard abs(zoom - pinchScale) > Self.pinchDeadband else { return }
        pinchScale = zoom
        applyCameraScale()
        announceBand(track: track)
    }

    /// announces the moment the band takes hold, once per crossing.
    ///
    /// The most important thing about a limit is being told about it, and the one
    /// moment that cannot go unnoticed is where the room stops keeping up. Fires on
    /// entering the resistance and not on leaving it: the room visibly gathering speed
    /// on the way back in is its own answer, and a second tick there would double the
    /// noise for one extra piece of information.
    ///
    /// Re-armed only by getting properly back inside rather than by clipping the edge,
    /// so a pinch resting against the limit cannot buzz.
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

    /// lets go of a pinch and springs the room back to the preset, carrying
    /// the release velocity in.
    ///
    /// Reduce Motion gets the state without the movement, which is the same call
    /// `endTurn` makes for the coast: the room still ends up at the preset, it simply
    /// arrives rather than travels there. The haptic survives either way, because
    /// Reduce Motion is about movement and not about feedback.
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

    /// springs the zoom from `track` back to the preset.
    ///
    /// The exact solution of a damped spring rather than a stepped approximation of
    /// one, in closed form: `x(t) = 1 + e^(-ζω₀t)·(A·cos(ω_d·t) + B·sin(ω_d·t))`, with
    /// `A` the distance travelled and `B` whatever makes the derivative at `t = 0`
    /// come out as `velocity`. One exponential and one cosine a step, no accumulated
    /// error, and — the reason for doing it this way — the release velocity goes in at
    /// the front rather than being faked by a curve that happens to start by moving the
    /// right way. A fling released travelling outwards keeps travelling outwards for a
    /// moment, which is the difference between a spring and a cut.
    ///
    /// Driven by the clock rather than by the step count, so a late frame shortens the
    /// wait for the next one instead of stretching the overshoot. `Date` because it is
    /// already this file's clock for gesture timing, and half a second is far too short
    /// a window for a wall-clock correction to matter.
    ///
    /// Banded on every step, which is what keeps the spring honest: an overshoot is
    /// resisted on the way out and let go on the way back, exactly as if the fingers
    /// had carried it there. Written straight to the drawn zoom it would carry the
    /// room straight through its own limit on a hard release, and put back the very
    /// wall the band exists to take away.
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

    /// puts the room exactly back on the preset and says so.
    ///
    /// The exact landing, because the loop ends when the spring's envelope is out of
    /// sight rather than when the arithmetic happens to arrive — leaving a thousandth of
    /// a zoom behind would leave the room resting a hair off its framing, and this is
    /// the one write that is guaranteed to be at rest.
    ///
    /// The tick goes here rather than to the release because this is the moment the room
    /// is back, and the same argument `settleTick` makes for a switch: it lands with the
    /// pixels arriving instead of while they are still travelling.
    private func arriveAtPreset(announces: Bool) {
        pinchTrack = 1
        pinchScale = 1
        applyCameraScale()
        if announces { pinchArriveTick &+= 1 }
        settleZoomTask = nil
    }

    /// the zoom the room is drawn at, for a track the fingers have put on
    /// `track`.
    ///
    /// Identity between the ends of the range — a pinch there is the fingers 1:1, with
    /// no smoothing and no easing, which is most of what makes it feel direct — and
    /// Apple's scroll rubber band outside it, so each end grows resistance instead of
    /// arriving. Saturating rather than clamping: the curve is asymptotic, so a limit is
    /// never actually reached and there is no point on it the fingers can feel.
    ///
    /// In log zoom, which is the axis perceived size change is linear in. Measured in
    /// plain zoom, the far end would resist more gently than the near one for no reason
    /// anyone could name except that there is more room to grow into, and the gesture
    /// would feel as though it had two different ends rather than one elastic material.
    /// The log also buys the band's ceiling for free: two touches at the same point
    /// give a magnification of zero, whose log is minus infinity — which this answers
    /// with its own asymptote instead of with a number the camera would choke on.
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

    /// how far past the edge of the range `past` log units of travel carry
    /// the room, as Apple's rubber band: `(1 − 1/(x·c/d + 1))·d` with `c` at
    /// `pinchBandGive`.
    ///
    /// Apple's own expression rather than a curve chosen to resemble it, because the
    /// shape is the platform's: it gives `c` of every point at the edge and steadily
    /// less after that, never quite reaching `d`. That is precisely the "no rigid
    /// limits" behaviour — the pull is heaviest exactly where a wall would have been,
    /// and there is nothing to hit.
    private static func bandedTravel(_ past: Float) -> Float {
        (1 - 1 / (past * pinchBandGive / pinchBandSpan + 1)) * pinchBandSpan
    }

    // MARK: - Turning

    /// Starts a drag, and reads the base the drag's offset is measured from off
    /// the room itself.
    ///
    /// The room's live orientation rather than the last yaw commanded, because
    /// the two differ in the one case that would be visible: a drag that starts
    /// while a flick is still coasting. Picking up the command instead of the
    /// coast would jump the room by however much of the glide was left.
    func beginTurn() {
        glide?.cancel()
        if let pivot {
            let turn = pivot.orientation(relativeTo: nil)
            yaw = 2 * atan2(turn.vector.y, turn.vector.w)
        }
        turnBase = yaw
    }

    /// Turns the room by `points` of horizontal travel from where the drag
    /// started, so samples cannot compound.
    ///
    /// The stage owns the points-to-radians figure rather than the gesture,
    /// because the gesture has no other reason to know it and the stage is where
    /// a flick's momentum is scaled to match.
    func turn(byPoints points: CGFloat) {
        yaw = turnBase + Float(points) * Self.radiansPerPoint
        applyOrientation()
    }

    /// Turns the room by `radians` from wherever it is now (used by
    /// accessibility).
    func turn(byRadians radians: Float) {
        yaw += radians
        turnBase = yaw
        applyOrientation()
    }

    /// Hands the room its momentum when a drag lifts, at
    /// `pointsPerSecond` of horizontal travel.
    ///
    /// A flick should carry; a placement should not. The two are told apart by
    /// the speed the finger left at, and everything else follows from that: the
    /// distance is proportional to it, so a gentle release coasts a little and
    /// letting go after a careful placement coasts not at all, and the ceiling
    /// stops a hard shove from turning the room further than a swipe in the
    /// gesture could have reached.
    ///
    /// The coast is one task stepping a fixed number of times, which costs a
    /// quaternion write and a few opacities per step from state SwiftUI never
    /// sees — so a flick is as cheap as the drag that started it.
    func endTurn(pointsPerSecond: CGFloat, reduceMotion: Bool) {
        turnBase = yaw
        guard !reduceMotion else { return }
        let carried = Float(pointsPerSecond) * Self.radiansPerPoint * Self.glideSeconds
        let target = yaw + min(max(carried, -Self.glideCeiling), Self.glideCeiling)
        guard abs(target - yaw) > 0.0005 else { return }
        glide(from: yaw, to: target)
    }

    /// Steps the room from `start` to `target` along an exponential coast.
    ///
    /// Exponential rather than eased-out-linear because it is the shape a thrown
    /// object actually has: most of the distance covered early and a long tail
    /// onto rest. Normalised over the glide's own length, so the room always
    /// arrives exactly on the target however many steps the coast took to get
    /// there.
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

    /// Normalised exponential decay from 0 to 1: `0` at rest, `1` when the
    /// coast has spent itself, and never past it.
    private static func glideCurve(_ t: Float) -> Float {
        let decay: Float = 5
        return (1 - exp(-decay * t)) / (1 - exp(-decay))
    }

    /// Parks or resumes the room's graph. No-op when unchanged, so liveness
    /// flips from the pager never touch the scene twice.
    ///
    /// Parking also abandons a switch in flight and stops any coast: the page is
    /// off screen, so the room it was heading for — and the turn nobody is
    /// watching — are not worth finishing.
    func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        pivot?.isEnabled = active
        guard !active else { return }
        glide?.cancel()
        switchID &+= 1
        switchTask?.cancel()
        // The pinch's settle is dropped along with the coast, and
        // the room goes back to the preset, because the pinch belonged to a touch on a
        // page nobody is looking at now and its leftover zoom would be the first thing
        // the returning page showed.
        settleZoomTask?.cancel()
        settleZoomTask = nil
        pinchTrack = 1
        pinchScale = 1
        applyCameraScale()
    }

    /// Current rotation, wrapped into `0..<360` so it stays short however far
    /// the room has been turned. For accessibility only.
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

    /// Re-aims the camera at the room as it stands turned right now.
    ///
    /// The framing is measured once, square to the room's front, but a room is not
    /// a symmetric box: turning it carries its silhouette across the frame while
    /// the pivot sits still, so an aim measured at rest leaves the room drifting
    /// off-centre as it turns — up to 12 points at the worst angle on the Kitchen
    /// and the same order on the other two. Re-aiming for the yaw in front of it is
    /// what makes "centred" true at every angle rather than only at rest.
    ///
    /// Written in the same breath as the rotation and from state SwiftUI never
    /// sees, so a drag sample still reaches no body at all. It carries no animation
    /// of its own either: the pan is part of the drag, and anything easing it
    /// would be a second source fighting the finger for the same value.
    ///
    /// The transform only. `applyCameraScale` owns the frame's size and this never
    /// touches it, so a turn cannot disturb the zoom a pinch left behind.
    private func applyCameraPose() {
        guard let camera, let framing else { return }
        let pose = framing.pose(yaw: yaw)
        camera.look(at: pose.aim, from: pose.position, relativeTo: nil)
    }

    /// Fades every wall by how far the turn has brought it in front of the
    /// camera.
    ///
    /// Opacity is a plain function of the turn — no timer, no per-frame clock,
    /// nothing carried between samples — so the walls move in lockstep with the
    /// drag and cannot cut. The `smoothstep` flattens the curve at both ends,
    /// which is what makes a wall arrive at invisible, and at opaque, with no
    /// step at either threshold.
    ///
    /// A room that declares no walls resolves to no groups here and so writes
    /// nothing, which is why an empty list is a room whose walls simply do not
    /// fade rather than a room without the machinery.
    private func applyWallFade(_ turn: simd_quatf) {
        for index in wallGroups.indices {
            // Cosine of the angle between where this wall now points and where
            // the camera is: positive when the wall has come between the two.
            let facingCamera = simd_dot(turn.act(wallGroups[index].facing), cameraBearing)
            let opacity = 1 - Self.smoothstep((facingCamera + Self.fadeBand) / (2 * Self.fadeBand))
            guard abs(opacity - wallOpacities[index]) > Self.fadeDeadband else { continue }
            wallOpacities[index] = opacity
            for entity in wallGroups[index].entities {
                // Set, never just written: these nodes arrive out of the USDZ
                // carrying no opacity component at all, so mutating a missing
                // one does nothing and the wall never fades.
                entity.components.set(OpacityComponent(opacity: opacity))
            }
        }
    }

    /// Hermite ramp from 0 to 1 over `t`, clamped at both ends.
    private static func smoothstep(_ t: Float) -> Float {
        let x = min(max(t, 0), 1)
        return x * x * (3 - 2 * x)
    }
}
