import SwiftUI

struct DotMatrixPressKey: EnvironmentKey {
    static let defaultValue: (Bool) -> Void = { _ in }
}

extension EnvironmentValues {
    var onDotMatrixPress: (Bool) -> Void {
        get { self[DotMatrixPressKey.self] }
        set { self[DotMatrixPressKey.self] = newValue }
    }
}

struct HomeView: View {
    @Environment(\.onDotMatrixPress) private var onDotMatrixPress
    @State private var isPressing = false
    @State private var pressStartTime: TimeInterval = 0
    @State private var releaseStartTime: TimeInterval = 0

    // Growth: smooth with barely-perceptible settle, organic deceleration
    private let growthSpring = Spring(duration: 0.55, bounce: 0.05)
    // Release: faster return, slight physical bounce on settle
    private let releaseSpring = Spring(duration: 0.4, bounce: 0.08)
    private static let holdDelay: TimeInterval = 0.15
    private static let maxScale: CGFloat = 1.5

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let scale = animatedScale(at: time)
            let spacing = UIConstants.DotMatrix.dotSpacing

            Canvas<EmptyView>(opaque: true, rendersAsynchronously: true, renderer: { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let maxRadius = size.height / 2 + 2 * spacing
                let numRings = max(1, Int(maxRadius / spacing))

                // Slower wave for more meditative rhythm
                let waveSpeed = max(0.8, Double(numRings) / 6.0)
                // Longer quiet pause between ripples
                let cycleDuration = Double(numRings) / waveSpeed + 0.8
                let cycleTime = time.truncatingRemainder(dividingBy: cycleDuration)
                let wavePosition = cycleTime * waveSpeed

                // Fade-in envelope: hides the cycle reset by starting invisible
                // at wavePosition=0, reaching full strength over ~2 rings of travel
                let waveFadeIn = min(1.0, wavePosition / 2.0)

                for ring in 1...numRings {
                    let radius = CGFloat(ring) * spacing
                    let dotCount = 5 * ring
                    let dotCountF = CGFloat(dotCount)
                    // 25% slower rotation for calmer idle motion
                    let rotation = CGFloat(time * UIConstants.DotMatrix.rotationSpeed * Double(ring - 1))

                    let ringDist = abs(wavePosition - Double(ring))
                    // Slightly wider spread for softer glow transition
                    let ripple = max(0.0, exp(-ringDist * ringDist * UIConstants.DotMatrix.waveSpread)) * waveFadeIn
                    let dotSize = (UIConstants.DotMatrix.dotSize + ripple * UIConstants.DotMatrix.rippleScale) * scale

                    let shading = GraphicsContext.Shading.color(
                        .sRGB, red: 1, green: 1, blue: 1,
                        opacity: UIConstants.DotMatrix.baseOpacity + UIConstants.DotMatrix.activeOpacity * ripple
                    )

                    let halfDot = dotSize / 2
                    let angleStep = 2.0 * .pi / dotCountF
                    let baseOffset = -CGFloat.pi / 2

                    var ringPath = Path()
                    for i in 0..<dotCount {
                        let totalAngle = CGFloat(i) * angleStep + baseOffset + rotation
                        let dx = center.x + radius * cos(totalAngle)
                        let dy = center.y + radius * sin(totalAngle)
                        ringPath.addEllipse(in: CGRect(
                            x: dx - halfDot,
                            y: dy - halfDot,
                            width: dotSize,
                            height: dotSize
                        ))
                    }

                    context.fill(ringPath, with: shading)
                }
            })
        }
        .onLongPressGesture(
            minimumDuration: 0.15,
            pressing: { pressing in
                isPressing = pressing
                onDotMatrixPress(pressing)
                if pressing {
                    pressStartTime = Date().timeIntervalSinceReferenceDate
                } else {
                    releaseStartTime = Date().timeIntervalSinceReferenceDate
                }
            },
            perform: {}
        )
        .background(Color.black)
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            RadialGradient(
                colors: [.clear, .black],
                center: .bottom,
                startRadius: UIConstants.General.screenWidth * 0.25,
                endRadius: UIConstants.General.screenWidth * 0.7
            )
            .frame(height: UIConstants.General.screenHeight * 0.35)
            .ignoresSafeArea()
        }
        .overlay(alignment: .bottom) {
            RadialGradient(
                colors: [.clear, .black],
                center: .top,
                startRadius: UIConstants.General.screenWidth * 0.25,
                endRadius: UIConstants.General.screenWidth * 0.7
            )
            .frame(height: UIConstants.General.screenHeight * 0.35)
            .ignoresSafeArea()
        }
    }

    private func animatedScale(at time: TimeInterval) -> CGFloat {
        if isPressing {
            let elapsed = time - pressStartTime
            guard elapsed > Self.holdDelay else { return 1.0 }
            // Spring-based growth: organic deceleration, gradual settling
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
            // velocity, settles back to 1.0 with slight physical bounce
            return CGFloat(releaseSpring.value(
                fromValue: scaleAtRelease,
                toValue: 1.0,
                initialVelocity: velocityAtRelease,
                time: elapsedSinceRelease
            ))
        }
    }
}

#Preview {
    HomeView()
}
