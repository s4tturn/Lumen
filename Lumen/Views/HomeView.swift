import SwiftUI

struct HomeView: View {
    @State private var isPressing = false
    @State private var pressStartTime: TimeInterval = 0
    @State private var releaseStartTime: TimeInterval = 0
    @GestureState private var longPress = false

    // Growth uses Apple's `smooth` spring: critically damped, zero bounce.
    // A press carries no momentum, so per HIG ("Designing Fluid Interfaces",
    // WWDC18) it should not overshoot; 0.55s mirrors the ambient layer's own
    // `.subdued` settle so the matrix grows in step with it.
    private let growthSpring = Spring.smooth(duration: 0.55, extraBounce: 0)
    // Release uses Apple's `snappy` spring: its small amount of bounce (base
    // 0.15) rewards the momentum of the finger lifting — the one case HIG
    // prescribes overshoot — and 0.4s mirrors the ambient layer's `.visible`
    // snap back, keeping the return responsive.
    private let releaseSpring = Spring.snappy(duration: 0.4, extraBounce: 0)
    // One long-press beat before growth begins. 0.15s sits at the edge of
    // perceived immediacy (~200ms), so the press still feels instant while
    // letting the touch ground itself before the matrix swells.
    private static let holdDelay: TimeInterval = 0.15
    private static let maxScale: CGFloat = 1.5

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let scale = animatedScale(at: time)

                Canvas(opaque: true, rendersAsynchronously: true) { context, size in
                    DotMatrixRenderer.draw(context: context, size: size, time: time, scale: scale)
                }
            }
            .gesture(
                LongPressGesture(minimumDuration: 0.15)
                    .updating($longPress) { _, state, _ in state = true }
            )
            .onChange(of: longPress) { _, pressing in
                isPressing = pressing
                if pressing {
                    pressStartTime = Date().timeIntervalSinceReferenceDate
                } else {
                    releaseStartTime = Date().timeIntervalSinceReferenceDate
                }
            }
            .accessibilityHint("Press and hold to activate")
            .background(Color.black)
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                RadialGradient(
                    colors: [.clear, .black],
                    center: .bottom,
                    startRadius: width * 0.25,
                    endRadius: width * 0.7
                )
                .frame(height: height * 0.35)
                .ignoresSafeArea()
            }
            .overlay(alignment: .bottom) {
                RadialGradient(
                    colors: [.clear, .black],
                    center: .top,
                    startRadius: width * 0.25,
                    endRadius: width * 0.7
                )
                .frame(height: height * 0.35)
                .ignoresSafeArea()
            }
        }
    }

    private func animatedScale(at time: TimeInterval) -> CGFloat {
        if isPressing {
            let elapsed = time - pressStartTime
            guard elapsed > Self.holdDelay else { return 1.0 }
            // Spring-based growth: organic deceleration, no overshoot.
            return CGFloat(growthSpring.value(
                fromValue: 1.0,
                toValue: Double(Self.maxScale),
                initialVelocity: 0,
                time: elapsed - Self.holdDelay
            ))
        } else {
            let elapsedSinceRelease = time - releaseStartTime
            let holdDuration = releaseStartTime - pressStartTime

            guard holdDuration > Self.holdDelay else { return 1.0 }

            // Snapshot spring state at moment of release
            let growthElapsed = holdDuration - Self.holdDelay
            let scaleAtRelease = growthSpring.value(
                fromValue: 1.0,
                toValue: Double(Self.maxScale),
                initialVelocity: 0,
                time: growthElapsed
            )
            let velocityAtRelease = growthSpring.velocity(
                fromValue: 1.0,
                toValue: Double(Self.maxScale),
                initialVelocity: 0,
                time: growthElapsed
            )
            // Release with velocity preservation: spring continues from current
            // velocity and settles back to 1.0 with a slight physical bounce.
            return CGFloat(releaseSpring.value(
                fromValue: scaleAtRelease,
                toValue: 1.0,
                initialVelocity: velocityAtRelease,
                time: elapsedSinceRelease
            ))
        }
    }
}

/// Pure immediate-mode renderer for the dot-matrix ripple.
///
/// Performance: per-frame trig is eliminated by precomputing each ring's unit
/// offsets once and rotating whole rings with a cheap context transform.
/// Rings whose dots fall entirely off screen are never drawn, and each ring's
/// path is built once and reused for its Gaussian glow layer.
private struct DotMatrixRenderer {
    /// Unit-circle offsets for every ring. Dot count and angular step are
    /// constant per ring, so this is computed exactly once, up front.
    ///
    /// The ring field is sized for the tallest window Lumen can occupy so the
    /// cache stays valid as the app is resized on iPad / iPhone Mirroring in
    /// iOS 27. The actual ring count drawn each frame is derived from the live
    /// canvas `size` inside `draw`, not from this snapshot.
    static let ringOffsets: [[CGPoint]] = {
        let constants = UIConstants.DotMatrix.self
        let maxFieldHeight: CGFloat = 3000
        let maxRings = max(1, Int((maxFieldHeight / 2 + 2 * constants.dotSpacing) / constants.dotSpacing))
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

    static func draw(context: GraphicsContext, size: CGSize, time: TimeInterval, scale: CGFloat) {
        let constants = UIConstants.DotMatrix.self
        let spacing = constants.dotSpacing
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        // The wave is paced across the full ring field (including the two
        // rings that land just off screen), keeping the ripple's rhythm and
        // fade-in identical to the original on every device.
        let waveRingCount = max(1, Int((size.height / 2 + 2 * spacing) / spacing))
        // Slower wave for more meditative rhythm
        let waveSpeed = max(0.8, Double(waveRingCount) / 6.0)
        // Longer quiet pause between ripples
        let cycleDuration = Double(waveRingCount) / waveSpeed + 0.8
        let cycleTime = time.truncatingRemainder(dividingBy: cycleDuration)
        let wavePosition = cycleTime * waveSpeed

        // Fade-in envelope: hides the cycle reset by starting invisible
        // at wavePosition=0, reaching full strength over ~2 rings of travel
        let waveFadeIn = min(1.0, wavePosition / 2.0)

        // Draw only rings whose dots can actually appear on screen.
        let drawRingCount = min(max(1, Int((size.height / 2) / spacing)), ringOffsets.count)

        for ring in 1...drawRingCount {
            let radius = CGFloat(ring) * spacing
            // 25% slower rotation for calmer idle motion
            let rotation = CGFloat(time * constants.rotationSpeed * Double(ring - 1))

            let ringDist = abs(wavePosition - Double(ring))
            // Slightly wider spread for softer glow transition
            let ripple = max(0.0, exp(-ringDist * ringDist * constants.waveSpread)) * waveFadeIn
            let dotSize = (constants.dotSize + ripple * constants.rippleScale) * scale
            let halfDot = dotSize / 2

            // Build the ring path once from cached offsets; reuse it for both
            // the glow layer and the final pass.
            let ringPath = Path { path in
                for offset in ringOffsets[ring - 1] {
                    path.addEllipse(in: CGRect(
                        x: center.x + radius * offset.x - halfDot,
                        y: center.y + radius * offset.y - halfDot,
                        width: dotSize,
                        height: dotSize
                    ))
                }
            }

            // Genuine Gaussian glow: dots drawn into a blurred transparency layer
            if ripple > 0.05 {
                let glowShading = GraphicsContext.Shading.color(
                    .sRGB, red: 1, green: 1, blue: 1,
                    opacity: Double(ripple) * constants.glowOpacity
                )
                context.drawLayer { ctx in
                    ctx.addFilter(.blur(radius: constants.glowRadius * ripple))
                    ctx.translateBy(x: center.x, y: center.y)
                    ctx.rotate(by: .radians(rotation))
                    ctx.translateBy(x: -center.x, y: -center.y)
                    ctx.fill(ringPath, with: glowShading)
                }
            }

            let shading = GraphicsContext.Shading.color(
                .sRGB, red: 1, green: 1, blue: 1,
                opacity: constants.baseOpacity + constants.activeOpacity * ripple
            )

            // Rotate the whole ring about the center with a context transform
            // instead of re-deriving every dot's angle.
            var ringContext = context
            ringContext.translateBy(x: center.x, y: center.y)
            ringContext.rotate(by: .radians(rotation))
            ringContext.translateBy(x: -center.x, y: -center.y)
            ringContext.fill(ringPath, with: shading)
        }
    }
}

#Preview {
    HomeView()
}
