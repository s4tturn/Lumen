import SwiftUI

// MARK: - Setup-only PRNG (never runs per-frame)

/// Deterministic 64-bit generator. Used once at init to derive wave
/// parameters from the seed; the frame loop only evaluates sines.
private struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}

// MARK: - Engine

/// Procedural fluid blob: N nested layers inside a fixed max radius.
///
/// Layout rule: `maxRadius / layers` is the smallest ring; ring i fills
/// `i × quotient`, so the outermost always lands exactly on maxRadius no
/// matter how many layers exist. Add layers later by bumping one number.
///
/// Motion never loops: every wave's period is a power of the golden ratio,
/// so the combined period is astronomically long — the outline is unique
/// forever, with no noise tables or per-frame randomness.
///
/// Cost per layer per frame: samples × waves sine calls + samples × passes
/// blends. Everything else is precomputed once at init.
struct BlobEngine {
    private struct Wave {
        var frequency: Double
        var amplitude: Double
        var phase: Double
        var speed: Double
    }

    private let layers: [[Wave]]
    private let samples: Int

    static let maxLayers = 12

    init(seed: UInt64 = 0x11E9A9, wavesPerLayer: Int = 6, samples: Int = 160) {
        self.samples = samples
        // Shared base frequencies keep layers rhyming; per-layer phases,
        // jittered amplitudes, and scaled speeds keep them distinct.
        let base = (0..<wavesPerLayer).map { 2.0 + Double($0) }
        self.layers = (0..<Self.maxLayers).map { index in
            var rng = SplitMix64(seed: seed ^ (UInt64(index) &+ 1) &* 0x9E3779B97F4A7C15)
            var waves = base.enumerated().map { k, frequency in
                Wave(
                    frequency: frequency,
                    amplitude: pow(frequency, -1.65) * (0.7 + 0.6 * rng.unit()),
                    phase: rng.unit() * 2 * .pi,
                    // Periods spread 3–32 s on irrational ratios: visibly
                    // alive at every scale, never repeating together.
                    speed: (2 * .pi / (1.1 * pow(1.618, frequency)))
                        * (rng.next() & 1 == 0 ? 1 : -1)
                        * (1 + 0.5 * rng.unit())
                )
            }
            let total = waves.reduce(0) { $0 + $1.amplitude }
            for i in waves.indices { waves[i].amplitude /= total }
            return waves
        }
    }

    /// Closed smooth path for ring `index` (0 = smallest) of `count` rings
    /// filling `maxRadius`. Displacement is a fraction of radius; smoothing
    /// is Laplacian passes — one number controls all of it.
    func path(
        index: Int,
        count: Int,
        center: CGPoint,
        maxRadius: CGFloat,
        displacement: Double,
        smoothing: Int,
        time: Double
    ) -> Path {
        let target = maxRadius * CGFloat(index + 1) / CGFloat(count)
        var radii = [Double](repeating: 0, count: samples)
        for i in 0..<samples {
            let angle = Double(i) / Double(samples) * 2 * .pi
            var sum = 0.0
            for wave in layers[index] {
                sum += wave.amplitude * sin(wave.frequency * angle + wave.speed * time + wave.phase)
            }
            radii[i] = 1 + displacement * sum
        }
        // Area preservation: normalize by the mean so wobble never reads as
        // size change, then melt jaggies — sum-preserving on a closed loop.
        let mean = radii.reduce(0, +) / Double(samples)
        for i in radii.indices { radii[i] = radii[i] / mean * target }
        for _ in 0..<smoothing {
            var next = radii
            for i in radii.indices {
                let avg = (radii[(i - 1 + samples) % samples] + radii[(i + 1) % samples]) * 0.5
                next[i] = radii[i] + 0.5 * (avg - radii[i])
            }
            radii = next
        }
        let points = radii.enumerated().map { i, r in
            let angle = Double(i) / Double(samples) * 2 * .pi
            return CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
        }
        // Smooth closed curve through the points via midpoint quadratics.
        var path = Path()
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) * 0.5, y: (a.y + b.y) * 0.5)
        }
        path.move(to: mid(points[samples - 1], points[0]))
        for i in 0..<samples {
            path.addQuadCurve(to: mid(points[i], points[(i + 1) % samples]), control: points[i])
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Reusable view

/// Renders the blob. Every parameter is a plain value read fresh each frame,
/// so continuous ones (radius, displacement, opacity, color) animate gradually
/// with a plain `withAnimation` from the caller; counts (layers, smoothing)
/// switch instantly. Depth comes from stacking translucent fills — no blur.
struct BlobView: View {
    var layers = 5
    var maxRadius: CGFloat = 180
    var displacement = 0.16
    var smoothing = 4
    var color = Color.white
    var opacity = 0.5
    /// Field playback rate. 0 freezes. Changes glide — no jumps.
    var speed = 1.0
    /// Per-layer feather. 0 skips the offscreen blur pass entirely.
    var blur: CGFloat = 0
    /// Solid white rimlight on the outermost ring. 0 disables it.
    var rimWidth: CGFloat = 0

    @State private var engine = BlobEngine()
    /// Accumulated field time: scaled by speed each frame, so moving the
    /// speed slider bends the motion instead of teleporting the field.
    @State private var fieldTime = 0.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                guard size.width > 0, size.height > 0 else { return }
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let count = min(max(layers, 1), BlobEngine.maxLayers)
                // Painter's order, outside in: translucency accumulates
                // toward the core.
                for index in (0..<count).reversed() {
                    let ring = engine.path(
                        index: index,
                        count: count,
                        center: center,
                        maxRadius: maxRadius,
                        displacement: displacement,
                        smoothing: smoothing,
                        time: fieldTime
                    )
                    // The outermost ring stays crisp at any setting — it
                    // defines the silhouette, blur melts only inner layers.
                    if blur > 0, index < count - 1 {
                        context.drawLayer { soft in
                            soft.addFilter(.blur(radius: blur))
                            soft.fill(ring, with: .color(color.opacity(opacity)))
                        }
                    } else {
                        context.fill(ring, with: .color(color.opacity(opacity)))
                    }
                    if index == count - 1, rimWidth > 0 {
                        context.stroke(ring, with: .color(.white), lineWidth: rimWidth)
                    }
                }
            }
            .onChange(of: timeline.date) { old, new in
                fieldTime += max(0, new.timeIntervalSince(old)) * speed
            }
        }
        .accessibilityHidden(true)
    }
}
