import SwiftUI

private enum DotMatrixConstants {
    static let dotSize: CGFloat = 10

    static let displacement: CGFloat = 1

    static let crestScale: CGFloat = 1.5

    static let dotSpacing: CGFloat = 44
    static let rotationSpeed: Double = 0.03
    static let baseOpacity: Double = 0.25
    static let activeOpacity: Double = 0.75
}

struct DotMatrixView: View {

    var isLive: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {

        if reduceMotion {
            Canvas(opaque: true, rendersAsynchronously: false) { context, size in
                DotMatrixField.drawStatic(context: context, size: size)
            }

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

enum DotMatrixField {

    static let ringPaths: [Path] = {
        let spacing = DotMatrixConstants.dotSpacing
        let dotSize = DotMatrixConstants.dotSize
        let halfDot = dotSize / 2
        let maxFieldHeight: CGFloat = 3000
        let maxRings = max(1, Int((maxFieldHeight / 2 + 2 * spacing) / spacing))

        let base = -CGFloat.pi / 2
        return (1...maxRings).map { ring in
            let radius = CGFloat(ring) * spacing

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

    static func drawStatic(context: GraphicsContext, size: CGSize) {
        draw(context: context, size: size, time: 0, frozen: true)
    }

    static func draw(
        context: GraphicsContext,
        size: CGSize,
        time: TimeInterval,
        frozen: Bool = false
    ) {
        let constants = DotMatrixConstants.self
        let spacing = constants.dotSpacing
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        let waveRingCount = max(1, Int((size.height / 2 + 2 * spacing) / spacing))

        let waveSpeed = max(0.8, Double(waveRingCount) / 6.0)

        let cycleDuration = Double(waveRingCount) / waveSpeed + 0.8
        let cycleTime = time.truncatingRemainder(dividingBy: cycleDuration)
        let wavePosition = frozen ? -Double(waveRingCount) : cycleTime * waveSpeed

        let waveFadeIn = max(0.0, min(1.0, wavePosition / 2.0))

        let drawRingCount = min(max(1, Int((size.height / 2) / spacing)), ringPaths.count)

        for ring in 1...drawRingCount {

            let rotation = frozen ? 0 : CGFloat(time * constants.rotationSpeed * Double(ring - 1))
            let ringDist = abs(wavePosition - Double(ring))

            let ripple = frozen ? 0 : max(0.0, exp(-ringDist * ringDist * 0.55)) * waveFadeIn

            var ringContext = context
            ringContext.translateBy(x: center.x, y: center.y)
            ringContext.rotate(by: .radians(rotation))
            let displaced = 1 + ripple * constants.displacement / constants.dotSize
            if displaced != 1 { ringContext.scaleBy(x: displaced, y: displaced) }

            let diameter = constants.dotSize * (1 + ripple * (constants.crestScale - 1))
            let growth = max(0, diameter / displaced - constants.dotSize)
            let path = ringPaths[ring - 1]

            let shading = GraphicsContext.Shading.color(
                .white.opacity(constants.baseOpacity + constants.activeOpacity * ripple)
            )
            ringContext.fill(path, with: shading)
            if growth > 0 { ringContext.stroke(path, with: shading, lineWidth: growth) }
        }
    }
}

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
