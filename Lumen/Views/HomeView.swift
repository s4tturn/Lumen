import SwiftUI

struct HomeView: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas<EmptyView>(opaque: true, rendersAsynchronously: true, renderer: { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let spacing: CGFloat = 44
                let maxRadius = size.height / 2 + 2 * spacing
                let numRings = max(1, Int(maxRadius / spacing))

                let waveSpeed = max(1.0, Double(numRings - 1) / 5.0)
                let cycleDuration = Double(numRings) / waveSpeed + 0.5
                let cycleTime = time.truncatingRemainder(dividingBy: cycleDuration)
                let wavePosition = cycleTime * waveSpeed

                for ring in 1...numRings {
                    let radius = CGFloat(ring) * spacing
                    let dotCount = 5 * ring
                    let rotation = time * 0.04 * Double(ring - 1)

                    let ringDist = abs(wavePosition - Double(ring))
                    let ripple = max(0.0, exp(-ringDist * ringDist * 0.6))
                    let dotSize = UIConstants.DotMatrix.dotSize + ripple * UIConstants.DotMatrix.rippleScale

                    let shading = GraphicsContext.Shading.color(
                        .sRGB, red: 1, green: 1, blue: 1,
                        opacity: 0.25 + 0.75 * ripple
                    )

                    var ringContext = context
                    ringContext.translateBy(x: center.x, y: center.y)
                    ringContext.rotate(by: Angle(radians: rotation))

                    for i in 0..<dotCount {
                        let angle = CGFloat(i) / CGFloat(dotCount) * 2 * .pi - .pi / 2
                        let x = radius * cos(angle)
                        let y = radius * sin(angle)
                        ringContext.fill(
                            Path(ellipseIn: CGRect(
                                x: x - dotSize / 2,
                                y: y - dotSize / 2,
                                width: dotSize,
                                height: dotSize
                            )),
                            with: shading
                        )
                    }
                }
            })
        }
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
}

#Preview {
    HomeView()
}
