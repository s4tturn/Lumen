import SwiftUI

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

#Preview {
    ZStack {
        Color.gray
        DotMatrixVignette()
    }
}
