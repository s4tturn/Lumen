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

    private static let delay: TimeInterval = 0.15
    private static let animDuration: TimeInterval = 0.6

    private static func easeInOut(_ t: CGFloat) -> CGFloat {
        t < 0.5 ? 2 * t * t : 1 - 2 * (1 - t) * (1 - t)
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let scale = animatedScale(at: time)
            let spacing: CGFloat = 44

            Canvas<EmptyView>(opaque: true, rendersAsynchronously: true, renderer: { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let maxRadius = size.height / 2 + 2 * spacing
                let numRings = max(1, Int(maxRadius / spacing))

                let waveSpeed = max(1.0, Double(numRings - 1) / 5.0)
                let cycleDuration = Double(numRings) / waveSpeed + 0.5
                let cycleTime = time.truncatingRemainder(dividingBy: cycleDuration)
                let wavePosition = cycleTime * waveSpeed

                for ring in 1...numRings {
                    let radius = CGFloat(ring) * spacing
                    let dotCount = 5 * ring
                    let dotCountF = CGFloat(dotCount)
                    let rotation = CGFloat(time * 0.04 * Double(ring - 1))

                    let ringDist = abs(wavePosition - Double(ring))
                    let ripple = max(0.0, exp(-ringDist * ringDist * 0.6))
                    let dotSize = (UIConstants.DotMatrix.dotSize + ripple * UIConstants.DotMatrix.rippleScale) * scale

                    let shading = GraphicsContext.Shading.color(
                        .sRGB, red: 1, green: 1, blue: 1,
                        opacity: 0.25 + 0.75 * ripple
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
            let holdDuration = CGFloat(time - pressStartTime)
            let adjusted = max(0, holdDuration - CGFloat(Self.delay))
            let progress = max(0, min(adjusted / CGFloat(Self.animDuration), 1))
            let eased = Self.easeInOut(progress)
            return 1.0 + 0.5 * eased
        } else {
            let releasedDuration = CGFloat(time - releaseStartTime)
            let holdDuration = CGFloat(releaseStartTime - pressStartTime)

            if holdDuration <= CGFloat(Self.delay) {
                return 1.0
            }

            let growthAdjusted = max(0, holdDuration - CGFloat(Self.delay))
            let growthProgress = max(0, min(growthAdjusted / CGFloat(Self.animDuration), 1))
            let growthEased = Self.easeInOut(growthProgress)
            let scaleAtRelease = 1.0 + 0.5 * growthEased

            let reverseProgress = max(0, min(releasedDuration / CGFloat(Self.animDuration), 1))
            let reverseEased = Self.easeInOut(reverseProgress)
            return scaleAtRelease + (1.0 - scaleAtRelease) * reverseEased
        }
    }
}

#Preview {
    HomeView()
}
