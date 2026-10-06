import SwiftUI

// MARK: - Constants

/// Dot-matrix look constants, owned by this file.
private enum DotMatrixConstants {
    static let dotSize: CGFloat = 10

    /// How far the wave pushes a dot outward along its own bearing, at the
    /// crest, in points of extra diameter. Divided by `dotSize` in `draw` to
    /// get the ring's scale, so `1` is 1.1×.
    ///
    /// Read as a ring count rather than as a size: the push is radial, so it
    /// grows with the ring. `1` carries the middle of the field one ring spacing
    /// outward at the crest — ring 10 sits at 440pt and moves to 484pt, exactly
    /// one ring's worth — while the innermost ring, at one spacing, moves well
    /// under one. That is why this reads as displacement and not as growth.
    static let displacement: CGFloat = 1

    /// How large a dot becomes, on its own, at the crest. The growth half of
    /// the wave, entirely separate from the displacement above.
    ///
    /// `1.5` is a 10pt dot reaching 15pt.
    static let crestScale: CGFloat = 1.5

    static let dotSpacing: CGFloat = 44
    static let rotationSpeed: Double = 0.03
    static let baseOpacity: Double = 0.25
    static let activeOpacity: Double = 0.75
}

// MARK: - View

/// The dot-matrix ripple field: concentric rings of dots on black with a
/// ripple wave travelling outward from the center.
///
/// Immediate-mode `Canvas` is the right tool (Sosumi: Canvas supports rich
/// dynamic 2D drawing via `GraphicsContext`; TimelineView redraws its content
/// on a schedule): one drawing pass per frame instead of hundreds of dot
/// subviews, which would blow the per-view memory/identity budget
/// (swiftui-design-principles widget budget, swiftui-pro performance).
struct DotMatrixView: View {
    /// Whether the ripple may run. Off-live pages hold a still frame, so the
    /// display link stops instead of redrawing a blurred page nobody can see.
    /// Phase derives from the timeline date, so resume causes no jump.
    var isLive: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Reduce Motion branches at the view level (liquid-glass-motion
        // reduce-motion): looping ambient motion is skipped, not slowed.
        // The gated-out TimelineView stops the display-link entirely instead
        // of redrawing an identical frozen frame at 120Hz.
        if reduceMotion {
            Canvas(opaque: true, rendersAsynchronously: false) { context, size in
                DotMatrixField.drawStatic(context: context, size: size)
            }
            // The field's own frame — safe-area-respecting, the
            // centre the wave ripples from.
            .debugSurfaceBorder()
            .accessibilityHidden(true)
        } else {
            TimelineView(.animation(minimumInterval: nil, paused: !isLive)) { timeline in
                Canvas(opaque: true, rendersAsynchronously: true) { context, size in
                    DotMatrixField.draw(
                        context: context,
                        size: size,
                        time: timeline.date.timeIntervalSinceReferenceDate
                    )
                }
                .debugSurfaceBorder()
                .accessibilityHidden(true)
            }
        }
    }
}

// MARK: - Field

/// Pure immediate-mode renderer for the dot-matrix ripple.
///
/// Performance: the field is drawn from a cached path per ring, so a frame is
/// one transform and one fill per ring — no per-frame path building and no
/// per-frame trig. Rings whose dots fall entirely off screen are never drawn.
/// Deliberately no glow: each ring is one crisp fill, and the wave reads
/// through the dot's own size, its distance from the centre, and its opacity.
enum DotMatrixField {
    /// Every ring's dots, built exactly once and centred on the origin at the
    /// base dot size. A frame then places, spins, and swells these by transform
    /// rather than re-deriving thousands of ellipses.
    ///
    /// The ring field is sized for the tallest window Lumen can occupy so the
    /// cache stays valid as the app is resized on iPad / iPhone Mirroring in
    /// iOS 27. The actual ring count drawn each frame is derived from the live
    /// canvas `size` inside `draw`, not from this snapshot.
    static let ringPaths: [Path] = {
        let spacing = DotMatrixConstants.dotSpacing
        let dotSize = DotMatrixConstants.dotSize
        let halfDot = dotSize / 2
        let maxFieldHeight: CGFloat = 3000
        let maxRings = max(1, Int((maxFieldHeight / 2 + 2 * spacing) / spacing))
        // First dot straight up, so every ring starts on the same bearing.
        let base = -CGFloat.pi / 2
        return (1...maxRings).map { ring in
            let radius = CGFloat(ring) * spacing
            // Dot count and angular step are constant per ring.
            let count = 5 * ring
            let angleStep = 2.0 * .pi / CGFloat(count)
            return Path { path in
                for i in 0..<count {
                    let angle = CGFloat(i) * angleStep + base
                    path.addEllipse(in: CGRect(
                        x: radius * cos(angle) - halfDot,
                        y: radius * sin(angle) - halfDot,
                        width: dotSize,
                        height: dotSize
                    ))
                }
            }
        }
    }()

    /// Frozen field for Reduce Motion: base-opacity dots, no wave, no
    /// rotation. A frozen mid-crest would hold the ripple's peak statically;
    /// the base state carries no vestibular trigger at all.
    static func drawStatic(context: GraphicsContext, size: CGSize) {
        draw(context: context, size: size, time: 0, frozen: true)
    }

    /// - Parameter frozen: Draw the base state with no wave, for Reduce Motion.
    static func draw(
        context: GraphicsContext,
        size: CGSize,
        time: TimeInterval,
        frozen: Bool = false
    ) {
        let constants = DotMatrixConstants.self
        let spacing = constants.dotSpacing
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        // The wave is paced across the full ring field (including the two
        // rings that land just off screen), keeping the ripple's rhythm and
        // fade-in identical on every device.
        let waveRingCount = max(1, Int((size.height / 2 + 2 * spacing) / spacing))
        // Slower wave for more meditative rhythm.
        let waveSpeed = max(0.8, Double(waveRingCount) / 6.0)
        // Longer quiet pause between ripples.
        let cycleDuration = Double(waveRingCount) / waveSpeed + 0.8
        let cycleTime = time.truncatingRemainder(dividingBy: cycleDuration)
        let wavePosition = frozen ? -Double(waveRingCount) : cycleTime * waveSpeed

        // Fade-in envelope: hides the cycle reset by starting invisible
        // at wavePosition=0, reaching full strength over ~2 rings of travel.
        // Frozen (negative position) clamps to zero ripple everywhere.
        let waveFadeIn = max(0.0, min(1.0, wavePosition / 2.0))

        // Draw only rings whose dots can appear on screen. Corner dots past
        // height/2 are intentionally left undrawn, matching the original
        // field's circular falloff into the vignette.
        let drawRingCount = min(max(1, Int((size.height / 2) / spacing)), ringPaths.count)

        for ring in 1...drawRingCount {
            // Calm idle rotation; static when frozen.
            let rotation = frozen ? 0 : CGFloat(time * constants.rotationSpeed * Double(ring - 1))
            let ringDist = abs(wavePosition - Double(ring))
            // Gaussian falloff width — inlined (not in UIConstants by design).
            let ripple = frozen ? 0 : max(0.0, exp(-ringDist * ringDist * 0.55)) * waveFadeIn

            // Rotate the whole ring about the center with a context transform
            // instead of re-deriving every dot's angle, and displace it the
            // same way: the scale is uniform, so the dots stay circular and
            // each moves out along its own bearing. A ring the wave has not
            // reached displaces by exactly 1 and skips the transform.
            var ringContext = context
            ringContext.translateBy(x: center.x, y: center.y)
            ringContext.rotate(by: .radians(rotation))
            let displaced = 1 + ripple * constants.displacement / constants.dotSize
            if displaced != 1 { ringContext.scaleBy(x: displaced, y: displaced) }

            // The dot's own size, and it is a separate animation from the
            // displacement above: this reaches `crestScale` of the resting dot
            // however far the displacement has carried it.
            //
            // A second `scaleBy` cannot do it — two uniform scales about one
            // point are just one scale, so growth and displacement would
            // multiply and neither would be reachable on its own. Stroking the
            // same cached path can, because a stroke of width `w` covers the
            // band from `dotSize - w` to `dotSize + w`, so unioned with the
            // fill below it is one solid dot of `dotSize + w` grown about the
            // dot's own centre rather than about the field's. One extra call
            // per ring, and none at all on a ring the wave has not reached.
            //
            // Divided by the displacement because this width is inside the
            // transform: what lands on screen is the stroke times the
            // displacement, and the dot's final size is what is specified.
            let diameter = constants.dotSize * (1 + ripple * (constants.crestScale - 1))
            let growth = max(0, diameter / displaced - constants.dotSize)
            let path = ringPaths[ring - 1]
            // One shading for both passes, so the fill and the stroke that
            // fattens it cannot disagree at the seam.
            let shading = GraphicsContext.Shading.color(
                .white.opacity(constants.baseOpacity + constants.activeOpacity * ripple)
            )
            ringContext.fill(path, with: shading)
            if growth > 0 { ringContext.stroke(path, with: shading, lineWidth: growth) }
        }
    }
}

// MARK: - Vignette

/// Around-view vignette: a single centered radial falloff, clear in the
/// middle dissolving to black at the edges.
///
/// This replaces the old pair of top/bottom veils with one surface that dims
/// all four edges and corners, so the matrix reads as a pool of light
/// falling off into the black base. The internal `GeometryReader` sizes the
/// radii from the live frame (clear zone from the short edge, falloff to the
/// farthest corner), so the falloff lands identically on any device, window
/// size, or mirroring session — and it evaluates once per layout, never per
/// animation frame.
///
/// Restraint note (swiftui-design-principles): this is the one decorative
/// layer on this page, in the page's own black — no new hue, no border, no
/// card. Opacity roles are two: transparent middle, opaque edge.
struct DotMatrixVignette: View {
    var body: some View {
        GeometryReader { proxy in
            let shortEdge = min(proxy.size.width, proxy.size.height)
            let farCorner = hypot(proxy.size.width, proxy.size.height) / 2
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: .black.opacity(0), location: 0),
                    .init(color: .black.opacity(0), location: 0.45),
                    .init(color: .black.opacity(0.55), location: 0.75),
                    .init(color: .black, location: 1),
                ]),
                center: .center,
                startRadius: shortEdge * 0.28,
                endRadius: farCorner
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview("Matrix") {
    DotMatrixView()
        .background { Color.black }
}

#Preview("Vignette") {
    ZStack {
        Color.gray
        DotMatrixVignette()
    }
}
