import SwiftUI

// MARK: - Setup-only PRNG (never runs per-frame)

/// Deterministic 64-bit generator. Used once at init to derive wave
/// parameters from the seed; the frame loop only reads tables.
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
/// A class that owns its buffers and has every trigonometric fact it will ever
/// need already in it, because this is the one thing in the app that runs for
/// every frame of a session. A ring's outline is a sum over its waves of
/// `amplitude · sin(ωθ + φ)`, and the addition identity splits that into an angle
/// the ring owns and an angle the clock owns: `sin(ωθ)·cos φ + cos(ωθ)·sin φ`. The
/// first half is tabulated once, at init, because only the ring's geometry decides
/// it; the second is two calls per wave per frame and no more. What used to be
/// some three thousand `sin` calls a frame is now a multiply-add over a table,
/// and no frame allocates at all.
final class BreatheEngine {
    /// One wave of one ring.
    private struct Wave {
        /// Turns around the ring. Integer by construction, so the ring closes
        /// on itself exactly.
        var frequency: Double

        /// Share of the ring's displacement this wave accounts for. A ring's
        /// amplitudes sum to one, which is what makes the area normalisation
        /// below a division by something very near one.
        var amplitude: Double

        /// Where this wave starts and how fast it runs, both in radians.
        var phase: Double
        var speed: Double
    }

    /// The rings' waves, ring by ring.
    private let layers: [[Wave]]

    /// `sin(ωθ)` for every wave at every sample, as one flat run:
    /// `wave * samples + sample`. Its `cos` twin is `waveCosines`.
    ///
    /// Two contiguous runs rather than one interleaved run of pairs. The frame
    /// loop walks a whole ring's worth of one table at a time, so each pass reads
    /// memory straight through and the compiler is free to vectorise it; an
    /// interleaved run would straddle every read by a step of two and leave the
    /// pass scalar. The arithmetic is unchanged — the same table, the same
    /// `sin(ωθ)·cos φ + cos(ωθ)·sin φ`, only laid out so it can be read at speed.
    private let waveSines: [Double]

    /// `cos(ωθ)` for every wave at every sample, laid out exactly as `waveSines`.
    private let waveCosines: [Double]

    /// The unit circle once: `[sample]` of `(cos θ, sin θ)`.
    ///
    /// Every point the blob puts on screen sits on this, so it is read rather
    /// than computed — the outline and the comet's arc are both walked with it,
    /// between two neighbours when they want a point the ring does not have.
    private let circle: [SIMD2<Double>]

    /// Samples around a ring. Every ring's and every radius buffer's length.
    let samples: Int

    /// Samples around a ring, for a caller that needs its buffers sized before
    /// it has an engine to ask. The value `init` defaults to.
    static let defaultSamples = 96

    static let maxLayers = 12

    init(seed: UInt64 = 0x11E9A9, wavesPerLayer: Int = 6, samples: Int = BreatheEngine.defaultSamples) {
        self.samples = samples

        // Shared base frequencies keep layers rhyming; per-layer phases,
        // jittered amplitudes, and scaled speeds keep them distinct.
        let base = (0..<wavesPerLayer).map { 2.0 + Double($0) }
        var layers: [[Wave]] = []
        var sines: [Double] = []
        var cosines: [Double] = []
        sines.reserveCapacity(Self.maxLayers * wavesPerLayer * samples)
        cosines.reserveCapacity(Self.maxLayers * wavesPerLayer * samples)

        for index in 0..<Self.maxLayers {
            var rng = SplitMix64(seed: seed ^ (UInt64(index) &+ 1) &* 0x9E3779B97F4A7C15)
            var waves = base.map { frequency in
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
            for wave in waves.indices {
                waves[wave].amplitude /= total
                for sample in 0..<samples {
                    let angle = Double(sample) / Double(samples) * 2 * .pi
                    sines.append(sin(waves[wave].frequency * angle))
                    cosines.append(cos(waves[wave].frequency * angle))
                }
            }
            layers.append(waves)
        }

        self.layers = layers
        self.waveSines = sines
        self.waveCosines = cosines
        self.circle = (0..<samples).map { sample in
            let angle = Double(sample) / Double(samples) * 2 * .pi
            return SIMD2(cos(angle), sin(angle))
        }
    }

    /// One ring's radii for a frame, written into `radii`.
    ///
    /// Area preservation: normalize by the mean so wobble never reads as a size
    /// change, then melt jaggies — sum-preserving on a closed loop, so the area
    /// the normalization established survives.
    ///
    /// `scratch` is the buffer the smoothing passes alternate with, borrowed
    /// rather than allocated: a frame's scratch is two arrays the caller already
    /// owns instead of one per Laplacian pass. The passes hand the buffers back
    /// by swapping rather than by copying, so an odd pass count costs the same as
    /// an even one — assigning the finished buffer back would deep-copy ninety-six
    /// doubles onto the heap on every frame it happened to.
    func ringRadii(
        index: Int,
        count: Int,
        maxRadius: CGFloat,
        displacement: Double,
        smoothing: Int,
        time: Double,
        into radii: inout [Double],
        scratch: inout [Double]
    ) {
        let ring = layers[index]
        let n = samples
        let sines = waveSines
        let cosines = waveCosines
        radii.withUnsafeMutableBufferPointer { out in
            for sample in 0..<n { out[sample] = 1 }
            // One wave at a time, across the whole ring: the phase is the same
            // for every sample, so its two calls are made once per wave rather
            // than once per sample, and what is left is a multiply-add into the
            // buffer already holding the ring.
            for wave in ring.indices {
                let phase: Double = ring[wave].speed * time + ring[wave].phase
                let phaseCosine: Double = cos(phase)
                let phaseSine: Double = sin(phase)
                let scale: Double = displacement * ring[wave].amplitude
                let at = wave * n
                for sample in 0..<n {
                    let tabulated: Double = sines[at + sample] * phaseCosine
                        + cosines[at + sample] * phaseSine
                    out[sample] += scale * tabulated
                }
            }
            // The mean, as a divisor: the ring's total over its sample count, so
            // every radius is scaled by the same factor and the ring's area is
            // what the caller asked for however hard it is being wobbled.
            var total: Double = 0
            for sample in 0..<n { total += out[sample] }
            let target: Double = Double(maxRadius) * Double(index + 1) / Double(count)
            let gain: Double = target * Double(n) / total
            for sample in 0..<n { out[sample] *= gain }
        }

        // Each pass moves every sample half the way toward the mean of its two
        // neighbours, alternating buffers so a pass never reads what it is
        // writing.
        let passes = max(smoothing, 0)
        var (from, to) = (radii, scratch)
        for _ in 0..<passes {
            for sample in radii.indices {
                let before = sample == 0 ? samples - 1 : sample - 1
                let after = sample + 1 == samples ? 0 : sample + 1
                let average = (from[before] + from[after]) * 0.5
                to[sample] = from[sample] + 0.5 * (average - from[sample])
            }
            swap(&from, &to)
        }
        // An odd number of passes leaves the answer in the scratch buffer, so the
        // two trade places rather than the answer being copied home. Both buffers
        // are scratch — `ringRadii` writes `radii` from scratch on every call, so
        // which of them holds last pass's values is never load-bearing.
        if passes % 2 == 1 { swap(&radii, &scratch) }
    }

    /// The closed outline of a ring, from its radii.
    ///
    /// A smooth closed curve through the points via midpoint quadratics: each
    /// segment starts and ends at the midpoint of two samples and bows through
    /// the sample between them, so every sample is on the curve and no two
    /// segments meet at an angle.
    func outline(_ radii: [Double], center: CGPoint) -> Path {
        var path = Path()
        let first = point(0, radii: radii, center: center)
        let last = point(samples - 1, radii: radii, center: center)
        path.move(to: CGPoint(x: (first.x + last.x) * 0.5, y: (first.y + last.y) * 0.5))
        for sample in 0..<samples {
            let here = point(sample, radii: radii, center: center)
            let next = point(sample + 1 == samples ? 0 : sample + 1, radii: radii, center: center)
            path.addQuadCurve(
                to: CGPoint(x: (here.x + next.x) * 0.5, y: (here.y + next.y) * 0.5),
                control: here
            )
        }
        path.closeSubpath()
        return path
    }

    /// Dense polyline along the outline from tail, forward `total` of the
    /// ring (wrapping through 0), sampled from the top, clockwise. The radius
    /// lookup is mapped onto the outline's native sample angles — sample `i`
    /// sits at `i/n·2π`, and progress starts at the top — so every point lands
    /// on the edge itself rather than on a circle near it.
    ///
    /// `nil` when there is nothing to draw: a tail that has caught the head has
    /// no arc between them, and asking for one would stroke a dot.
    func arc(center: CGPoint, radii: [Double], head: Double, tail: Double) -> Path? {
        let total = head >= tail ? head - tail : head - tail + 1
        guard total > 0.002 else { return nil }
        var path = Path()
        path.move(to: rim(progress: tail, radii: radii, center: center))
        for step in 1...240 {
            path.addLine(to: rim(
                progress: tail + total * Double(step) / 240,
                radii: radii,
                center: center
            ))
        }
        return path
    }

    /// A point on a ring, off the unit circle.
    @inline(__always)
    private func point(_ sample: Int, radii: [Double], center: CGPoint) -> CGPoint {
        let offset = circle[sample]
        return CGPoint(
            x: center.x + offset.x * radii[sample],
            y: center.y + offset.y * radii[sample]
        )
    }

    /// A point `progress` of the way round a ring, measured clockwise from
    /// straight up, which is the direction the rim reads as progress. Wraps at a
    /// whole turn, and sits between two samples where the ring does not have the
    /// angle asked for.
    @inline(__always)
    private func rim(progress: Double, radii: [Double], center: CGPoint) -> CGPoint {
        // Sample zero is a quarter turn clockwise of the top, so the top is a
        // quarter turn before it. Progress may run past a whole turn, and a whole
        // turn is where progress lands again, so the angle is wrapped first.
        let turned = progress - 0.25
        let at = (turned - turned.rounded(.down)) * Double(samples)
        let lower = Int(at) % samples
        let fraction = at - at.rounded(.down)
        let upper = lower + 1 == samples ? 0 : lower + 1
        let offset = circle[lower] + (circle[upper] - circle[lower]) * fraction
        let radius = radii[lower] + (radii[upper] - radii[lower]) * fraction
        return CGPoint(x: center.x + offset.x * radius, y: center.y + offset.y * radius)
    }
}
