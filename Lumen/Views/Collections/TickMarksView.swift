import SwiftUI

// MARK: - Tick Marks

struct TickMarksView: View {
    let rotation: Double
    let radius: CGFloat
    let tickWidth: CGFloat
    let tickHeight: CGFloat

    private let count = Int(360.0 / Layout.tickSpacing)

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(.white)
                    .frame(width: tickWidth, height: tickHeight)
                    .offset(y: -radius + tickHeight + 2)
                    .rotationEffect(.degrees(Double(index) * Layout.tickSpacing))
            }
        }
        .rotationEffect(.degrees(rotation))
    }
}
