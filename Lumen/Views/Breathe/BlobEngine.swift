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

    /// Smoothed absolute radii for ring `index` (0 = smallest) of `count`
    /// rings filling `maxRadius`. Shared by the full path and the progress
    /// arc so both follow the identical outline.
    func ringRadii(
        index: Int,
        count: Int,
        maxRadius: CGFloat,
        displacement: Double,
        smoothing: Int,
        time: Double
    ) -> [Double] {
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
        return radii
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
        let radii = ringRadii(
            index: index,
            count: count,
            maxRadius: maxRadius,
            displacement: displacement,
            smoothing: smoothing,
            time: time
        )
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

// MARK: - Journey

/// Eased travel from one value to another, evaluated per frame on the render
/// clock. Retargeting mid-flight bends from the live presented value, so
/// intermediates are guaranteed — no animation transaction involved.
private struct Journey {
    private var from: Double
    private var to: Double
    private var start = Date.distantPast
    private var duration = 1.0

    init(_ value: Double = 0) {
        from = value
        to = value
    }

    mutating func retarget(to target: Double, duration: Double, now: Date) {
        from = value(now: now)
        to = target
        start = now
        self.duration = duration
    }

    func value(now: Date) -> Double {
        guard duration > 0 else { return to }
        let t = now.timeIntervalSince(start) / duration
        if t >= 1 { return to }
        if t <= 0 { return from }
        return from + (to - from) * (0.5 - 0.5 * cos(.pi * t))
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
    var excited = Color(red: 0.69, green: 0.32, blue: 0.87)
    /// How far the excited tint reaches from white toward `excited`.
    var excitedBlend = 1.0
    /// Tint target, set instantly by the parent. The presented value eases
    /// toward it on the render clock below, so the morph is a pure function
    /// of time and can never jump regardless of which context flips this.
    var excitedMix = 0.0
    /// How long the ease toward a new tint takes.
    var morphDuration = 1.0
    var displacementDuration = 1.0
    var radiusDuration = 1.0
    /// Field playback rate target. Eased on the render clock like the rest,
    /// so state changes sweep the tempo instead of switching it.
    var speed = 1.0
    var speedDuration = 1.0
    /// Per-layer feather. 0 skips the offscreen blur pass entirely.
    var blur: CGFloat = 0
    /// Rim target on the outermost ring: plain solid rim when neutral, 2×
    /// progress ring when excited. 0 disables it.
    var rimWidth: CGFloat = 0
    /// Comet stroke width. Eased like everything else.
    var cometWidth: CGFloat = 1.4
    /// Cycle leg the rim progress tracks: exact head = (now - start) /
    /// duration. Nil while not cycling (neutral, armed) — plain rim instead.
    var progressStart: Date? = nil
    var progressDuration = 4.0

    @State private var engine = BlobEngine()
    /// Accumulated field time: scaled by speed each frame, so moving the
    /// speed slider bends the motion instead of teleporting the field.
    @State private var fieldTime = 0.0
    // One journey per eased parameter. Retargeting mid-flight bends from
    // the live presented value — no jumps, ever.
    @State private var mixJourney = Journey()
    @State private var displacementJourney = Journey()
    @State private var radiusJourney = Journey()
    @State private var speedJourney = Journey()
    @State private var rimJourney = Journey()
    @State private var cometJourney = Journey()
    /// True once a leg begins via switch (not the first leg, not re-entry).
    /// Gates the post-switch half of the tail window below.
    @State private var didSwitch = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                guard size.width > 0, size.height > 0 else { return }
                let now = timeline.date
                let excitedTarget = Self.tint(UIColor(color), UIColor(excited), excitedBlend)
                let tint = Self.tint(UIColor(color), excitedTarget, mixJourney.value(now: now))
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let count = min(max(layers, 1), BlobEngine.maxLayers)
                let presentedRadius = CGFloat(radiusJourney.value(now: now))
                let presentedDisplacement = displacementJourney.value(now: now)
                let rimW = CGFloat(rimJourney.value(now: now))
                let cometW = CGFloat(cometJourney.value(now: now))
                // Painter's order, outside in: translucency accumulates
                // toward the core.
                for index in (0..<count).reversed() {
                    let ring = engine.path(
                        index: index,
                        count: count,
                        center: center,
                        maxRadius: presentedRadius,
                        displacement: presentedDisplacement,
                        smoothing: smoothing,
                        time: fieldTime
                    )
                    if blur > 0, index < count - 1 {
                        context.drawLayer { soft in
                            soft.addFilter(.blur(radius: blur))
                            soft.fill(ring, with: .color(Color(tint).opacity(opacity)))
                        }
                    } else {
                        context.fill(ring, with: .color(Color(tint).opacity(opacity)))
                    }
                    // Original white rim: always on, never moves.
                    if index == count - 1 {
                        context.stroke(ring, with: .color(.white), lineWidth: 0.7)
                    }
                }
                // Comet: bright tail along the outline itself, round caps,
                // transparent everywhere else — no track. Head is exact phase
                // progress; tail drains across the boundary (see tailFraction).
                // It lives and dies by the excited tint: fully melted into
                // blur at neutral, crisp when excited.
                let mix = mixJourney.value(now: now)
                if mix > 0.001, rimW > 0 {
                    let ringBlur = (1 - mix) * 20
                    if ringBlur > 0.5 { context.addFilter(.blur(radius: ringBlur)) }
                    let intro: Double
                    if let start = progressStart, !didSwitch {
                        intro = min(max(now.timeIntervalSince(start) / 0.5, 0), 1)
                    } else {
                        intro = 1
                    }
                    let radii = engine.ringRadii(
                        index: count - 1,
                        count: count,
                        maxRadius: presentedRadius,
                        displacement: presentedDisplacement,
                        smoothing: smoothing,
                        time: fieldTime
                    )
                    if let arc = Self.arcPath(
                        center: center,
                        radii: radii,
                        head: headFraction(now: now),
                        tail: tailFraction(now: now)
                    ) {
                        context.stroke(
                            arc,
                            with: .color(Color(tint).opacity(intro)),
                            style: StrokeStyle(lineWidth: cometW, lineCap: .round, lineJoin: .round)
                        )
                    }
                }
            }
            .onChange(of: timeline.date) { old, new in
                fieldTime += max(0, new.timeIntervalSince(old)) * speedJourney.value(now: new)
            }
            .onChange(of: speed) { _, target in
                speedJourney.retarget(to: target, duration: speedDuration, now: .now)
            }
            .onChange(of: excitedMix) { _, target in
                mixJourney.retarget(to: target, duration: morphDuration, now: .now)
            }
            .onChange(of: displacement) { _, target in
                displacementJourney.retarget(to: target, duration: displacementDuration, now: .now)
            }
            .onChange(of: maxRadius) { _, target in
                radiusJourney.retarget(to: Double(target), duration: radiusDuration, now: .now)
            }
            .onChange(of: rimWidth) { _, target in
                rimJourney.retarget(to: Double(target), duration: morphDuration, now: .now)
            }
            .onChange(of: cometWidth) { _, target in
                cometJourney.retarget(to: Double(target), duration: morphDuration, now: .now)
            }
            .onChange(of: progressStart) { old, new in
                if old != nil { didSwitch = true }
                if new == nil { didSwitch = false }
            }
        }
        .accessibilityHidden(true)
        .onAppear {
            // Anchor journeys so the first frame renders current values.
            mixJourney = Journey(excitedMix)
            displacementJourney = Journey(displacement)
            radiusJourney = Journey(Double(maxRadius))
            speedJourney = Journey(speed)
            rimJourney = Journey(Double(rimWidth))
            cometJourney = Journey(Double(cometWidth))
        }
    }

    /// Exact leg progress 0→1. The head never lags, eases, or jumps.
    private func headFraction(now: Date) -> Double {
        guard let start = progressStart else { return 0 }
        return min(max(now.timeIntervalSince(start) / progressDuration, 0), 1)
    }

    /// Tail choreography. Intro (first leg only): sweeps forward to meet the
    /// head exactly at 0.5 s, so the ring grows in instead of popping on.
    /// Then parked at the meeting point until 0.5 s before the leg ends,
    /// when it drains anchor → 0.5; the post-switch half runs 0.5 → 1 over
    /// the next leg's first 0.5 s (1 s total), parks at 1 ≡ 0, restarts.
    /// Seamless at every join by construction.
    private func tailFraction(now: Date) -> Double {
        guard let start = progressStart else { return 0 }
        let elapsed = now.timeIntervalSince(start)
        if !didSwitch, elapsed < 0.5 {
            return headFraction(now: now) * Self.ease(elapsed / 0.5)
        }
        // Parked anchor: the intro meeting point on leg one, else 0.
        let anchor = didSwitch ? 0 : 0.5 / progressDuration
        // Post-switch half: 0.5 → 1 over the first 0.5 s of the new leg.
        if didSwitch, elapsed < 0.5 {
            return 0.5 + 0.5 * Self.ease(max(elapsed, 0) / 0.5)
        }
        // Pre-switch half: anchor → 0.5 over the last 0.5 s of this leg.
        let remaining = progressDuration - elapsed
        if remaining < 0.5, remaining >= 0 {
            return anchor + (0.5 - anchor) * Self.ease((0.5 - remaining) / 0.5)
        }
        return anchor
    }

    private static func ease(_ t: Double) -> Double {
        0.5 - 0.5 * cos(.pi * min(max(t, 0), 1))
    }

    /// Dense polyline along the outline from tail, forward `total` of the
    /// ring (wrapping through 0), sampled from the top, clockwise. The
    /// radius lookup is mapped onto the outline's native sample angles
    /// (sample i sits at angle i/n·2π; progress starts at the top), so every
    /// point lands on the edge itself — at 240 segments the chord deviation
    /// is far sub-pixel.
    private static func arcPath(center: CGPoint, radii: [Double], head: Double, tail: Double) -> Path? {
        var total = head - tail
        if total < 0 { total += 1 }
        guard total > 0.002 else { return nil }
        let n = radii.count
        var path = Path()
        let steps = 240
        for k in 0...steps {
            let f = tail + total * Double(k) / Double(steps)
            let w = f - floor(f)
            let shifted = w - 0.25 - floor(w - 0.25)
            let pos = shifted * Double(n)
            let i0 = Int(pos) % n
            let i1 = (i0 + 1) % n
            let fr = pos - floor(pos)
            let r = radii[i0] + (radii[i1] - radii[i0]) * fr
            let a = -Double.pi / 2 + f * 2 * Double.pi
            let p = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
            if k == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        return path
    }

    private static func tint(_ a: UIColor, _ b: UIColor, _ t: Double) -> UIColor {
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return UIColor(
            red: ar + (br - ar) * CGFloat(t),
            green: ag + (bg - ag) * CGFloat(t),
            blue: ab + (bb - ab) * CGFloat(t),
            alpha: 1
        )
    }

}
