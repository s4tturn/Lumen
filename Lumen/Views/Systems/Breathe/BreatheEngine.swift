import SwiftUI

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

final class BreatheEngine {

    private struct Wave {

        var frequency: Double

        var amplitude: Double

        var phase: Double
        var speed: Double
    }

    private let layers: [[Wave]]

    private let waveSines: [Double]

    private let waveCosines: [Double]

    private let circle: [SIMD2<Double>]

    let samples: Int

    static let defaultSamples = 96

    static let maxLayers = 12

    init(seed: UInt64 = 0x11E9A9, wavesPerLayer: Int = 6, samples: Int = BreatheEngine.defaultSamples) {
        self.samples = samples

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

            var total: Double = 0
            for sample in 0..<n { total += out[sample] }
            let target: Double = Double(maxRadius) * Double(index + 1) / Double(count)
            let gain: Double = target * Double(n) / total
            for sample in 0..<n { out[sample] *= gain }
        }

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

        if passes % 2 == 1 { swap(&radii, &scratch) }
    }

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

    @inline(__always)
    private func point(_ sample: Int, radii: [Double], center: CGPoint) -> CGPoint {
        let offset = circle[sample]
        return CGPoint(
            x: center.x + offset.x * radii[sample],
            y: center.y + offset.y * radii[sample]
        )
    }

    @inline(__always)
    private func rim(progress: Double, radii: [Double], center: CGPoint) -> CGPoint {

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
