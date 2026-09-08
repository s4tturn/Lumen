import SwiftUI

// MARK: - Procedural fluid-blob field
//
// The outline is a continuous, time-evolving random field over angle — not a
// circle with a few named sine waves added. A fixed root seed deterministically
// generates all field parameters once (Fourier coefficients, phases, speeds,
// directions, noise domains, angular warp); every frame then evaluates smooth
// continuous functions of (angle, time), so consecutive frames are always
// related and never jitter. No randomness happens inside the frame loop.

/// Deterministic 64-bit PRNG (SplitMix64). Used once at setup to derive every
/// field parameter from a seed. Never used per-frame.
struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        // Avoid the degenerate all-zero stream.
        self.state = seed &+ 0x9E3779B97F4A7C15
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Uniform value in [0, 1).
    mutating func nextUnit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    mutating func nextUnit(from lower: Double, to upper: Double) -> Double {
        lower + nextUnit() * (upper - lower)
    }

    mutating func nextSign() -> Double {
        next() & 1 == 0 ? 1.0 : -1.0
    }

    /// Deterministically shuffles an array in place.
    mutating func shuffle<T>(_ values: inout [T]) {
        guard values.count > 1 else { return }
        for i in stride(from: values.count - 1, through: 1, by: -1) {
            let j = Int(next() % UInt64(i + 1))
            values.swapAt(i, j)
        }
    }
}

/// 2D value noise on an integer lattice with quintic fade. Sampled on the unit
/// circle ((cos θ, sin θ) scaled by cycle count), so the field joins seamlessly
/// at θ = 0 / 2π, and drifted through 2D space over time so the noise reads as
/// a moving field rather than a pattern sliding along the outline.
struct LatticeNoise2D {
    private let seed: UInt64

    init(seed: UInt64) {
        self.seed = seed
    }

    private func lattice(_ ix: Int, _ iy: Int) -> Double {
        var h = UInt64(bitPattern: Int64(ix &* 374761393 &+ iy &* 668265263))
        h &+= seed &+ 0x9E3779B97F4A7C15
        h = (h ^ (h >> 30)) &* 0xBF58476D1CE4E5B9
        h = (h ^ (h >> 27)) &* 0x94D049BB133111EB
        h ^= h >> 31
        return Double(h >> 11) / Double(1 << 53) * 2.0 - 1.0
    }

    func noise(x: Double, y: Double) -> Double {
        let xi = Int(floor(x))
        let yi = Int(floor(y))
        let xf = x - floor(x)
        let yf = y - floor(y)
        // Quintic fade for smooth derivatives at lattice boundaries.
        let u = xf * xf * xf * (xf * (xf * 6.0 - 15.0) + 10.0)
        let v = yf * yf * yf * (yf * (yf * 6.0 - 15.0) + 10.0)
        let aa = lattice(xi, yi)
        let ba = lattice(xi + 1, yi)
        let ab = lattice(xi, yi + 1)
        let bb = lattice(xi + 1, yi + 1)
        return aa + (ba - aa) * u + (ab - aa) * v + (aa - ba - ab + bb) * u * v
    }
}

// MARK: - Configuration

/// Every artistic tuning knob in one place. No magic numbers elsewhere.
struct BlobConfiguration {
    var sampleCount = 160
    var fourierComponentCount = 12
    /// Amplitude falloff exponent: A_k ∝ k^-alpha.
    var falloffExponent = 1.65
    /// Soft saturation bound on total deformation (fraction of radius).
    var maximumDeformation = 0.18
    /// Relative noise-octave weights (macro / medium / fine).
    var noiseWeights = (macro: 1.0, medium: 0.40, fine: 0.12)
    /// Noise cycles around the circumference per octave. Integers keep the seam closed.
    var noiseCycles = (macro: 2.0, medium: 5.0, fine: 11.0)
    /// Overall noise contribution relative to the Fourier field.
    var noiseAmplitude = 0.35
    /// Subtle slide of deformation features around the outline, in radians.
    var angularWarpAmount = 0.05
    /// Two-term global breathing: amplitudes and angular speeds.
    var breathing = (b1: 0.02, w1: 0.45, b2: 0.008, w2: 0.45 * 1.41421356237)
    /// Hard floor on radius after normalization (fraction of target).
    var minimumRadiusFraction = 0.80
    /// Geometric smoothing passes: each pass pulls every sample toward its
    /// neighbors, melting jagged edges into curves. 0 = raw field outline.
    var smoothingPasses = 3
    /// Second-derivative safety net per relaxation pass (fraction of target radius).
    var curvatureLimit = 0.05

    static var `default`: BlobConfiguration { BlobConfiguration() }
}

// MARK: - Deformation field

/// One randomized Fourier wave: irregular frequency, jittered amplitude,
/// random phase, incommensurate speed, random travel direction.
private struct BlobWave {
    let frequency: Double
    let amplitude: Double
    let phase: Double
    let speed: Double
    let direction: Double
}

private struct WarpComponent {
    let frequency: Double
    let amplitude: Double
    let phase: Double
    let speed: Double
    let direction: Double
}

private struct NoiseOctave {
    let cycles: Double
    let amplitude: Double
    let driftRadius: Double
    let driftSpeed: Double
    let driftPhase: Double
    let noise: LatticeNoise2D
}

/// A complete multi-scale deformation field for one contour layer.
struct BlobField {
    private let waves: [BlobWave]
    private let warpA: WarpComponent
    private let warpB: WarpComponent
    private let octaves: [NoiseOctave]
    private let maximumDeformation: Double
    let deformationScale: Double

    /// Shared base frequencies from the root seed so layers rhyme; every other
    /// parameter is derived per-layer for related-but-distinct motion.
    static func baseFrequencies(rootSeed: UInt64, count: Int) -> [Int] {
        var rng = SplitMix64(seed: rootSeed ^ 0xB10B5EED)
        var pool = [2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 15, 17, 19]
        rng.shuffle(&pool)
        return Array(pool.prefix(count)).sorted()
    }

    init(
        seed: UInt64,
        baseFrequencies: [Int],
        configuration: BlobConfiguration,
        deformationScale: Double
    ) {
        var rng = SplitMix64(seed: seed)
        self.deformationScale = deformationScale
        self.maximumDeformation = configuration.maximumDeformation

        // Incommensurate speed multipliers give the combination an extremely
        // long apparent period — no recognizable loop.
        var multipliers = [1.0, 1.41421356237, 1.61803398875, 1.73205080757, 1.57079632679, 2.2360679775]
        rng.shuffle(&multipliers)

        // Amplitude ∝ k^-α with per-component jitter, normalized to sum 1.
        var rawAmplitudes: [Double] = baseFrequencies.map { k in
            pow(Double(k), -configuration.falloffExponent) * rng.nextUnit(from: 0.7, to: 1.3)
        }
        let total = rawAmplitudes.reduce(0, +)
        rawAmplitudes = rawAmplitudes.map { $0 / total }

        self.waves = zip(baseFrequencies, rawAmplitudes).enumerated().map { index, pair in
            let (k, amp) = pair
            // Speed band follows spatial scale: broad shapes drift over
            // 10–30 s, medium bulges over 4–10 s, fine detail over 1.5–4 s.
            let period: Double
            if k <= 5 {
                period = rng.nextUnit(from: 10.0, to: 30.0)
            } else if k <= 10 {
                period = rng.nextUnit(from: 4.0, to: 10.0)
            } else {
                period = rng.nextUnit(from: 1.5, to: 4.0)
            }
            return BlobWave(
                frequency: Double(k),
                amplitude: amp,
                phase: rng.nextUnit(from: 0, to: 2 * .pi),
                speed: (2 * .pi / period) * multipliers[index % multipliers.count],
                direction: rng.nextSign()
            )
        }

        func makeWarp(frequencies: [Int]) -> WarpComponent {
            WarpComponent(
                frequency: Double(frequencies[Int(rng.next() % UInt64(frequencies.count))]),
                amplitude: configuration.angularWarpAmount * 0.5,
                phase: rng.nextUnit(from: 0, to: 2 * .pi),
                speed: (2 * .pi / rng.nextUnit(from: 8.0, to: 24.0))
                    * multipliers[Int(rng.next() % UInt64(multipliers.count))],
                direction: rng.nextSign()
            )
        }
        self.warpA = makeWarp(frequencies: [2, 3])
        self.warpB = makeWarp(frequencies: [2, 3, 4])

        let weights = configuration.noiseWeights
        let cycles = configuration.noiseCycles
        let octaveSpecs = [
            (cycles.macro, weights.macro),
            (cycles.medium, weights.medium),
            (cycles.fine, weights.fine),
        ]
        self.octaves = octaveSpecs.enumerated().map { index, spec in
            NoiseOctave(
                cycles: spec.0,
                amplitude: spec.1 * configuration.noiseAmplitude,
                driftRadius: rng.nextUnit(from: 0.15, to: 0.45),
                driftSpeed: (2 * .pi / rng.nextUnit(from: 12.0, to: 36.0))
                    * multipliers[(index + 2) % multipliers.count],
                driftPhase: rng.nextUnit(from: 0, to: 2 * .pi),
                noise: LatticeNoise2D(seed: rng.next())
            )
        }
    }

    /// Combined deformation as a fraction of radius. Continuous in both angle
    /// and time: every term is a sine or smooth noise sample.
    func deformation(angle: Double, time: Double) -> Double {
        let warped = angle
            + warpA.amplitude * sin(warpA.frequency * angle + warpA.direction * warpA.speed * time + warpA.phase)
            + warpB.amplitude * sin(warpB.frequency * angle + warpB.direction * warpB.speed * time + warpB.phase)

        var sum = 0.0
        for wave in waves {
            sum += wave.amplitude
                * sin(wave.frequency * warped + wave.direction * wave.speed * time + wave.phase)
        }

        var detail = 0.0
        let c = cos(warped)
        let s = sin(warped)
        for octave in octaves {
            let dx = octave.driftRadius * cos(octave.driftSpeed * time + octave.driftPhase)
            let dy = octave.driftRadius * sin(octave.driftSpeed * 1.27 * time + octave.driftPhase * 1.7)
            detail += octave.amplitude * octave.noise.noise(
                x: (c + dx) * octave.cycles,
                y: (s + dy) * octave.cycles
            )
        }

        // Graceful saturation, then a controlled maximum deformation.
        return tanh(sum + detail) * maximumDeformation * deformationScale
    }
}

// MARK: - Generator (math → points → path)

/// Evaluates a field into closed, smoothed contours. Owns the pipeline:
/// deform → mean-normalize (area preservation) → curvature guard → breathe → path.
struct BlobGenerator {
    let field: BlobField
    let configuration: BlobConfiguration

    func points(
        center: CGPoint,
        targetRadius: Double,
        time: Double,
        breathing: Double,
        energy: Double = 1.0
    ) -> [CGPoint] {
        let count = configuration.sampleCount
        var radii = [Double](repeating: 0, count: count)
        for i in 0..<count {
            let theta = Double(i) / Double(count) * 2 * .pi
            // Energy scales the deformation amplitude: higher energy reads as
            // wobblier and more alive. Bounded by tanh upstream, so no blowup.
            radii[i] = 1.0 + field.deformation(angle: theta, time: time) * energy
        }

        // Area preservation: normalize by the mean before applying breathing,
        // so the shape can change dramatically without changing overall size.
        let mean = radii.reduce(0, +) / Double(count)
        let floor = configuration.minimumRadiusFraction * targetRadius
        let step = configuration.curvatureLimit * targetRadius
        for i in 0..<count {
            radii[i] = radii[i] / mean * targetRadius * breathing
        }

        // Geometric smoothing: Laplacian passes pull every sample toward the
        // average of its neighbors, turning jagged polylines into curves.
        // Sum-preserving on a closed loop, so area stays constant.
        for _ in 0..<configuration.smoothingPasses {
            var next = radii
            for i in 0..<count {
                let avg = (radii[(i - 1 + count) % count] + radii[(i + 1) % count]) * 0.5
                next[i] = radii[i] + 0.5 * (avg - radii[i])
            }
            radii = next
        }

        // Curvature guard: two relaxation passes cap local second differences
        // so randomness can never spike a hook or cusp.
        for _ in 0..<2 {
            var next = radii
            for i in 0..<count {
                let avg = (radii[(i - 1 + count) % count] + radii[(i + 1) % count]) * 0.5
                next[i] = min(max(radii[i], avg - step), avg + step)
            }
            radii = next
        }

        return radii.enumerated().map { i, r in
            let theta = Double(i) / Double(count) * 2 * .pi
            let clamped = max(r, floor)
            return CGPoint(x: center.x + cos(theta) * clamped, y: center.y + sin(theta) * clamped)
        }
    }

    /// Closed centripetal Catmull-Rom → cubic Bézier. Cyclic indexing keeps the
    /// 0°/360° seam tangent-continuous; the centripetal form avoids overshoot
    /// and loops on unevenly spaced points.
    func smoothClosedPath(through points: [CGPoint]) -> Path {
        var path = Path()
        let n = points.count
        guard n > 2 else { return path }
        path.move(to: points[0])
        for i in 0..<n {
            let p0 = points[(i - 1 + n) % n]
            let p1 = points[i]
            let p2 = points[(i + 1) % n]
            let p3 = points[(i + 2) % n]
            let t0: Double = 0
            let t1 = t0 + pow(hypot(p1.x - p0.x, p1.y - p0.y), 0.5)
            let t2 = t1 + pow(hypot(p2.x - p1.x, p2.y - p1.y), 0.5)
            let t3 = t2 + pow(hypot(p3.x - p2.x, p3.y - p2.y), 0.5)
            let d20 = t2 - t0
            let d31 = t3 - t1
            let d21 = t2 - t1
            let m1: CGPoint
            let m2: CGPoint
            if d20 < 1e-6 || d31 < 1e-6 || d21 < 1e-6 {
                // Degenerate spacing: fall back to uniform tangents.
                m1 = CGPoint(x: (p2.x - p0.x) / 2, y: (p2.y - p0.y) / 2)
                m2 = CGPoint(x: (p3.x - p1.x) / 2, y: (p3.y - p1.y) / 2)
            } else {
                m1 = CGPoint(x: (p2.x - p0.x) * (d21 / d20), y: (p2.y - p0.y) * (d21 / d20))
                m2 = CGPoint(x: (p3.x - p1.x) * (d21 / d31), y: (p3.y - p1.y) * (d21 / d31))
            }
            path.addCurve(
                to: p2,
                control1: CGPoint(x: p1.x + m1.x / 3, y: p1.y + m1.y / 3),
                control2: CGPoint(x: p2.x - m2.x / 3, y: p2.y - m2.y / 3)
            )
        }
        path.closeSubpath()
        return path
    }

    func path(
        center: CGPoint,
        targetRadius: Double,
        time: Double,
        breathing: Double,
        energy: Double = 1.0
    ) -> Path {
        smoothClosedPath(through: points(
            center: center,
            targetRadius: targetRadius,
            time: time,
            breathing: breathing,
            energy: energy
        ))
    }
}

// MARK: - Interior bands

/// One horizontal band with its own wave character, so the six bands read as
/// distinct embedded currents rather than identical sine copies.
struct BlobBand {
    let verticalFraction: Double
    let tilt: Double
    let amp1: Double
    let freq1: Double
    let phase1: Double
    let speed1: Double
    let amp2: Double
    let freq2: Double
    let phase2: Double
    let speed2: Double
    let warpAmp: Double
    let warpScale: Double
    let warpSeed: Double
}

// MARK: - Scene (one root seed → a family of related layers)

/// Owns every generator from a single root seed: shared base frequencies keep
/// the layers' motion related, per-layer derived seeds keep it distinct, and
/// inner layers deform progressively less so the center stays calm.
struct BlobScene {
    struct Layer {
        let generator: BlobGenerator
        let inset: Double
        let color: Color
    }

    let outer: BlobGenerator
    let layers: [Layer]
    let bands: [BlobBand]
    let bandNoise: LatticeNoise2D
    let configuration: BlobConfiguration

    /// Hierarchical seeds: every layer derives from the root, never independent.
    static func derivedSeed(root: UInt64, index: Int) -> UInt64 {
        var rng = SplitMix64(seed: root ^ (UInt64(index) &+ 1) &* 0x9E3779B97F4A7C15)
        return rng.next()
    }

    init(rootSeed: UInt64, configuration: BlobConfiguration = .default) {
        self.configuration = configuration
        let base = BlobField.baseFrequencies(
            rootSeed: rootSeed,
            count: configuration.fourierComponentCount
        )
        func generator(index: Int, scale: Double) -> BlobGenerator {
            BlobGenerator(
                field: BlobField(
                    seed: Self.derivedSeed(root: rootSeed, index: index),
                    baseFrequencies: base,
                    configuration: configuration,
                    deformationScale: scale
                ),
                configuration: configuration
            )
        }
        self.outer = generator(index: 0, scale: 1.0)
        let specs: [(inset: Double, scale: Double, color: Color)] = [
            (0.82, 0.75, .white.opacity(0.5)),
            (0.64, 0.60, .white.opacity(0.5)),
            (0.46, 0.50, .white.opacity(0.5)),
            (0.30, 0.35, .white.opacity(0.5)),
        ]
        self.layers = specs.enumerated().map { position, spec in
            Layer(generator: generator(index: position + 1, scale: spec.scale), inset: spec.inset, color: spec.color)
        }

        var rng = SplitMix64(seed: rootSeed ^ 0xBA9D5EED)
        let tilts = [-0.12, 0.10, -0.06, 0.05, 0.14, -0.10]
        self.bands = (0..<6).map { band in
            BlobBand(
                verticalFraction: Double(band) / 5.0,
                tilt: tilts[band],
                amp1: rng.nextUnit(from: 6.0, to: 14.0),
                freq1: rng.nextUnit(from: 0.5, to: 1.2),
                phase1: rng.nextUnit(from: 0, to: 2 * .pi),
                speed1: rng.nextSign() * (2 * .pi / rng.nextUnit(from: 5.0, to: 14.0)),
                amp2: rng.nextUnit(from: 2.0, to: 6.0),
                freq2: rng.nextUnit(from: 1.5, to: 3.0),
                phase2: rng.nextUnit(from: 0, to: 2 * .pi),
                speed2: rng.nextSign() * (2 * .pi / rng.nextUnit(from: 2.5, to: 7.0)),
                warpAmp: rng.nextUnit(from: 3.0, to: 8.0),
                warpScale: rng.nextUnit(from: 0.008, to: 0.02),
                warpSeed: Double(band) * 17.0 + 3.0
            )
        }
        self.bandNoise = LatticeNoise2D(seed: rng.next())
    }

    /// Shared two-term global breathing applied after area normalization.
    func breathing(time: Double) -> Double {
        let b = configuration.breathing
        return 1.0 + b.b1 * sin(b.w1 * time) + b.b2 * sin(b.w2 * time + 1.1)
    }
}
