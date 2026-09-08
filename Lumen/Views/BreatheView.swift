import SwiftUI

/// Breathe page: the white resting blob, draggable, with tuning sliders.
/// Blob character lives in `BlobView` — tune it there.
struct BreatheView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset = CGSize.zero
    /// 0 = blob follows the finger 1:1, 100 = blob stays pinned.
    private let damping = 80.0

    var body: some View {
        GeometryReader { proxy in
            let minDimension = min(proxy.size.width, proxy.size.height)
            let radius = minDimension * 0.30
            ZStack {
                Color.black.ignoresSafeArea()
                BlobView(
                    layers: 5,
                    maxRadius: radius,
                    displacement: 0.10,
                    speed: reduceMotion ? 0 : 0.5,
                    blur: 20,
                    rimWidth: 0.5
                )
                .offset(offset)
                .allowsHitTesting(false)

                Color.clear
                    .frame(width: radius * 2.8, height: radius * 2.8)
                    .contentShape(Circle())
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .local)
                            .onChanged {
                                let t = $0.translation
                                offset = CGSize(width: t.width * followFactor, height: t.height * followFactor)
                            }
                            .onEnded { settleOffsetToZero(velocity: $0.velocity) }
                    )

            }
        }
        .background(.black)
        .accessibilityLabel("Breathe")
    }

    /// Damping 0 → finger and blob move 1:1; 100 → blob stays pinned.
    /// Cosine ease gives a smooth curve with zero slope at both ends.
    private var followFactor: Double {
        0.5 * (1.0 + cos(.pi * damping / 100.0))
    }

    /// Release hands the flick velocity to the spring, projected onto the
    /// return direction (fraction of remaining travel per second, clamped).
    /// A near-still finger settles critically damped instead.
    private func settleOffsetToZero(velocity: CGSize) {
        let distance = hypot(offset.width, offset.height)
        guard distance > 0.5 else {
            withAnimation(releaseSpring(velocity: 0)) { offset = .zero }
            return
        }
        let projected = -(velocity.width * offset.width + velocity.height * offset.height)
            / (distance * distance)
        let handoff = hypot(velocity.width, velocity.height) < 100
            ? 0
            : min(max(projected, -6), 6)
        withAnimation(releaseSpring(velocity: handoff)) { offset = .zero }
    }

    private func releaseSpring(velocity: Double) -> Animation {
        UIConstants.Animation.motionGate(
            velocity == 0
                ? .spring(.snappy(duration: 0.35))
                : .interpolatingSpring(duration: 0.38, bounce: 0.15, initialVelocity: velocity),
            reduceMotion: reduceMotion
        )
    }
}

#Preview {
    BreatheView()
}
