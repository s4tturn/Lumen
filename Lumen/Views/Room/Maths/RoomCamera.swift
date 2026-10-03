import Foundation
import RealityKit

/// The room's fixed isometric orthographic camera, and the size the room is
/// drawn at.
///
/// Every framing value is derived from the loaded model's own bounds, so the
/// room fits itself to whatever geometry the asset ships with and needs no
/// tuning when that changes. Only the pitch and yaw are authored: together they
/// put the camera on the room's diagonal, which is what makes the view read as
/// isometric rather than as a photograph.
struct RoomCamera {
    /// Downward tilt, in radians — `atan(1 / √2)`, the true isometric angle.
    static let pitch: Float = 35.264 * Float.pi / 180

    /// Azimuth, in radians. 45° looks along the room's diagonal, so the two
    /// visible walls meet on a centred vertical edge.
    static let yaw: Float = 45 * Float.pi / 180

    /// How much larger the room is drawn than its real size.
    static let modelScale: Float = 2.5

    /// The share of the viewport the room is framed to fill.
    static let framingFraction: Float = 0.5

    /// Near plane. Fixed and very close: the camera never approaches the
    /// geometry, so a small value only buys depth precision.
    static let near: Float = 0.01

    /// Centre of the room in world space.
    let center: SIMD3<Float>

    /// Axis-aligned size of the room in world space.
    let extents: SIMD3<Float>

    init(center: SIMD3<Float>, extents: SIMD3<Float>) {
        self.center = center
        self.extents = extents
    }

    init(bounds: BoundingBox) {
        self.init(center: bounds.center, extents: bounds.extents)
    }

    /// The room's ground footprint, corner to corner — the width of the square
    /// its walls sit on. Taken instead of `extents.x` because the room is seen
    /// diagonally, where the diagonal is what has to fit on screen.
    var footprint: Float {
        (extents.x + extents.z) / Float(2).squareRoot()
    }

    /// Orthographic width, measured horizontally. Scales with the room's own
    /// size so a bigger asset fills the same share of the viewport, and takes
    /// the wider of footprint and height because the room is wider than it is
    /// tall from any angle this camera can reach.
    var scale: Float {
        Self.modelScale * Self.framingFraction * max(footprint, extents.y)
    }

    /// Longest edge of the room.
    var maxExtent: Float {
        max(extents.x, extents.y, extents.z)
    }

    /// How far back the camera sits. Twice the longest edge clears the room
    /// from every direction while keeping near and far planes well apart.
    var standoff: Float {
        maxExtent * 2
    }

    /// Far plane, with room to spare over the standoff.
    var far: Float {
        max(maxExtent, 1) * 8
    }

    /// Calibration lift, in world units: how far above the pivot the camera
    /// aims.
    ///
    /// Aiming exactly at the pivot renders the room high on device: shifting
    /// the room down 40 and shifting the camera up 40 (orientation frozen in
    /// both cases) center it identically — and that test also confirms this
    /// camera is the one the view renders from, since moving it moves pixels.
    /// So the camera looks 40 above the room's middle. Eye and aim rise
    /// together, which is a pure translation of the whole camera: the
    /// isometric pitch and yaw are untouched, and the pivot stays through the
    /// room's middle, so turning still spins in place.
    ///
    /// The 40 is measured on device, not derived: dial it with the debug camera
    /// slider and bake the refined value here. If a re-exported asset moves it,
    /// that slider is the instrument — do not touch the angles themselves.
    /// TEMP-BASELINE: zeroed for the model-only test. See calibration note
    /// below; restore to the measured value if the test shows the offset is
    /// still needed.
    static let calibrationLift: Float = 0

    /// Camera position in world space: `standoff` away from the room's centre,
    /// on the diagonal defined by `pitch` and `yaw`, raised by
    /// `calibrationLift` to match the raised aim.
    var position: SIMD3<Float> {
        let distance = standoff
        let horizontal = distance * cos(Self.pitch)
        return center + SIMD3(
            horizontal * cos(Self.yaw),
            distance * sin(Self.pitch) + Self.calibrationLift,
            horizontal * sin(Self.yaw)
        )
    }

    /// Builds the camera entity. The camera is parentless, so aiming it in
    /// world space is its final placement. Eye and aim are lifted together, so
    /// the orientation is exactly the unlifted isometric one.
    func makeEntity() -> Entity {
        var component = OrthographicCameraComponent()
        component.near = Self.near
        component.far = far
        component.scale = scale
        component.scaleDirection = .horizontal

        let entity = Entity()
        entity.components.set(component)
        entity.look(at: center + SIMD3(0, Self.calibrationLift, 0), from: position, relativeTo: nil)
        return entity
    }
}
