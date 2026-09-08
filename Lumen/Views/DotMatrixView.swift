import SwiftUI

/// The dot-matrix ripple field: concentric rings of dots on black with a
/// ripple wave travelling outward from the center.
///
/// Immediate-mode `Canvas` is the right tool (Sosumi: Canvas supports rich
/// dynamic 2D drawing via `GraphicsContext`; TimelineView redraws its content
/// on a schedule): one drawing pass per frame instead of hundreds of dot
/// subviews, which would blow the per-view memory/identity budget
/// (swiftui-design-principles widget budget, swiftui-pro performance).
/// Dot-matrix look constants, owned by this file.
private enum DotMatrixConstants {
    static let dotSize: CGFloat = 10
    static let rippleScale: CGFloat = 9
    static let dotSpacing: CGFloat = 44
    static let rotationSpeed: Double = 0.03
    static let baseOpacity: Double = 0.25
    static let activeOpacity: Double = 0.75
}

struct DotMatrixView: View {
    /// Extra dot diameter (pt) at the wave crest.
    var rippleScale: CGFloat = DotMatrixConstants.rippleScale

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
            .accessibilityHidden(true)
        } else {
            TimelineView(.animation) { timeline in
                Canvas(opaque: true, rendersAsynchronously: false) { context, size in
                    DotMatrixField.draw(
                        context: context,
                        size: size,
                        time: timeline.date.timeIntervalSinceReferenceDate,
                        rippleScale: rippleScale
                    )
                }
                .accessibilityHidden(true)
            }
        }
    }
}

/// Pure immediate-mode renderer for the dot-matrix ripple.
///
/// Performance: per-frame trig is eliminated by precomputing each ring's unit
/// offsets once and rotating whole rings with a cheap context transform.
/// Rings whose dots fall entirely off screen are never drawn. Deliberately
/// no glow: each ring is one crisp fill, and the wave reads through size
/// (`rippleScale`, tunable via the DEBUG slider) and opacity alone.
enum DotMatrixField {
    /// Unit-circle offsets for every ring. Dot count and angular step are
    /// constant per ring, so this is computed exactly once, up front.
    ///
    /// The ring field is sized for the tallest window Lumen can occupy so the
    /// cache stays valid as the app is resized on iPad / iPhone Mirroring in
    /// iOS 27. The actual ring count drawn each frame is derived from the live
    /// canvas `size` inside `draw`, not from this snapshot.
    static let ringOffsets: [[CGPoint]] = {
        let spacing = DotMatrixConstants.dotSpacing
        let maxFieldHeight: CGFloat = 3000
        let maxRings = max(1, Int((maxFieldHeight / 2 + 2 * spacing) / spacing))
        return (1...maxRings).map { ring in
            let count = 5 * ring
            let angleStep = 2.0 * .pi / CGFloat(count)
            let base = -CGFloat.pi / 2
            return (0..<count).map { i in
                let angle = CGFloat(i) * angleStep + base
                return CGPoint(x: cos(angle), y: sin(angle))
            }
        }
    }()

    /// Frozen field for Reduce Motion: base-opacity dots, no wave, no
    /// rotation. A frozen mid-crest would hold the ripple's peak statically;
    /// the base state carries no vestibular trigger at all.
    static func drawStatic(context: GraphicsContext, size: CGSize) {
        draw(context: context, size: size, time: 0, frozen: true)
    }

    static func draw(context: GraphicsContext, size: CGSize, time: TimeInterval, rippleScale: CGFloat = DotMatrixConstants.rippleScale, frozen: Bool = false) {
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
        let drawRingCount = min(max(1, Int((size.height / 2) / spacing)), ringOffsets.count)

        for ring in 1...drawRingCount {
            let radius = CGFloat(ring) * spacing
            // Calm idle rotation; static when frozen.
            let rotation = frozen ? 0 : CGFloat(time * constants.rotationSpeed * Double(ring - 1))

            let ringDist = abs(wavePosition - Double(ring))
            // Gaussian falloff width — inlined (not in UIConstants by design).
            let ripple = frozen ? 0 : max(0.0, exp(-ringDist * ringDist * 0.55)) * waveFadeIn
            let dotSize = constants.dotSize + ripple * rippleScale
            let halfDot = dotSize / 2

            // Rotate the whole ring about the center with a context transform
            // instead of re-deriving every dot's angle.
            var ringContext = context
            ringContext.translateBy(x: center.x, y: center.y)
            ringContext.rotate(by: .radians(rotation))
            ringContext.translateBy(x: -center.x, y: -center.y)

            // No glow: each ring is a single crisp fill. Opacity alone
            // carries the wave (base → active), size carries the swell.
            let corePath = Path { path in
                for offset in ringOffsets[ring - 1] {
                    path.addEllipse(in: CGRect(
                        x: center.x + radius * offset.x - halfDot,
                        y: center.y + radius * offset.y - halfDot,
                        width: dotSize,
                        height: dotSize
                    ))
                }
            }
            ringContext.fill(
                corePath,
                with: .color(.white.opacity(constants.baseOpacity + constants.activeOpacity * Double(ripple)))
            )
        }
    }
}

#Preview {
    DotMatrixView()
        .background { Color.black }
}
