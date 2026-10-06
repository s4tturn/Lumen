import SwiftUI

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

    @inline(__always)
    mutating func retarget(to target: Double, duration: Double, now: Date) {
        from = value(now: now)
        to = target
        start = now
        self.duration = duration
    }

    @inline(__always)
    func value(now: Date) -> Double {
        guard duration > 0 else { return to }
        let t = now.timeIntervalSince(start) / duration
        if t >= 1 { return to }
        if t <= 0 { return from }
        return from + (to - from) * (0.5 - 0.5 * cos(.pi * t))
    }
}

// MARK: - Field

/// What the canvas reads and writes every frame, and what must not be published
/// to SwiftUI when it changes.
///
/// The clock and the tail's own state live here rather than in `@State` because
/// nothing outside the drawing closure ever reads them: publishing either would
/// invalidate the view every frame to inform a view the timeline is already
/// redrawing. The radius buffers are scratch that lives here for the same
/// lifetime, so a frame allocates nothing.
final class BlobField {
    /// Accumulated field time: scaled by speed each frame, so moving the
    /// speed slider bends the motion instead of teleporting the field.
    var time = 0.0

    /// True once a leg begins via switch (not the first leg, not re-entry).
    /// Gates the post-switch half of the tail window.
    var didSwitch = false

    /// The outermost ring's radii for the frame being drawn, kept past the pass
    /// that measured them so the comet is stroked along the very edge it was
    /// measured on rather than on a second, slightly different reading of it.
    ///
    /// Two buffers handed back and forth by `measureOuterRing` rather than one
    /// copied into the other: `ringRadii` writes its whole output before anyone
    /// reads it, so which of the two holds last frame's numbers is never
    /// load-bearing — and the copy it replaced was ninety-six doubles onto the
    /// heap, on every frame, for the life of the session.
    private(set) var outer: [Double]

    /// Radii for the ring being drawn, and its neighbour in the smoothing
    /// passes. Both sized once, so no frame grows an array.
    var radii: [Double]
    var scratch: [Double]

    init(samples: Int = BreatheEngine.defaultSamples) {
        outer = [Double](repeating: 0, count: samples)
        radii = [Double](repeating: 0, count: samples)
        scratch = [Double](repeating: 0, count: samples)
    }

    /// Measures the outermost ring and keeps it, which is what the comet and the
    /// rim are drawn from.
    func measureOuterRing(
        _ engine: BreatheEngine,
        count: Int,
        maxRadius: CGFloat,
        displacement: Double,
        smoothing: Int
    ) {
        engine.ringRadii(
            index: count - 1,
            count: count,
            maxRadius: maxRadius,
            displacement: displacement,
            smoothing: smoothing,
            time: time,
            into: &radii,
            scratch: &scratch
        )
        swap(&outer, &radii)
    }

    /// Measures one inner ring, which nothing needs to keep.
    func measureRing(
        _ engine: BreatheEngine,
        index: Int,
        count: Int,
        maxRadius: CGFloat,
        displacement: Double,
        smoothing: Int
    ) {
        engine.ringRadii(
            index: index,
            count: count,
            maxRadius: maxRadius,
            displacement: displacement,
            smoothing: smoothing,
            time: time,
            into: &radii,
            scratch: &scratch
        )
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
    /// Whether the field may run. Off-live pages hold a still frame: the
    /// display link stops, and the field's clock accumulates from timeline dates
    /// so the paused gap contributes no delta and resume causes no jump.
    var isLive: Bool = true

    @State private var engine = BreatheEngine()
    @State private var field = BlobField()
    // One journey per eased parameter. Retargeting mid-flight bends from
    // the live presented value — no jumps, ever.
    @State private var mixJourney = Journey()
    @State private var displacementJourney = Journey()
    @State private var radiusJourney = Journey()
    @State private var speedJourney = Journey()
    @State private var rimJourney = Journey()
    @State private var cometJourney = Journey()

    var body: some View {
        // The two tint endpoints are resolved out here, above the timeline, so
        // the frame loop inherits three plain numbers. It used to bridge `Color`
        // to `UIColor` and back four times a frame to perform two lerps; the
        // nesting bought nothing but the bridging, because lerping once by the
        // product of the two factors lands on exactly the same colour.
        let base = Self.components(of: color)
        let target = base + (Self.components(of: excited) - base) * excitedBlend
        return TimelineView(.animation(minimumInterval: nil, paused: !isLive)) { timeline in
            Canvas(opaque: true, rendersAsynchronously: true) { context, size in
                guard size.width > 0, size.height > 0 else { return }
                let now = timeline.date
                let mix = mixJourney.value(now: now)
                let tint = base + (target - base) * mix
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let count = min(max(layers, 1), BreatheEngine.maxLayers)
                let radius = CGFloat(radiusJourney.value(now: now))
                let ripple = displacementJourney.value(now: now)
                let comet = CGFloat(cometJourney.value(now: now))
                // Every ring is filled with the same colour at the same alpha,
                // so the shading is built once rather than per layer.
                let fill = GraphicsContext.Shading.color(Self.srgb(tint).opacity(opacity))
                let rim = CGFloat(rimJourney.value(now: now))

                // Painter's order, outside in: translucency accumulates
                // toward the core.
                for index in (0..<count).reversed() {
                    if index == count - 1 {
                        field.measureOuterRing(
                            engine, count: count, maxRadius: radius,
                            displacement: ripple, smoothing: smoothing
                        )
                    } else {
                        field.measureRing(
                            engine, index: index, count: count, maxRadius: radius,
                            displacement: ripple, smoothing: smoothing
                        )
                    }
                    let ring = engine.outline(
                        index == count - 1 ? field.outer : field.radii, center: center
                    )
                    if blur > 0, index < count - 1 {
                        context.drawLayer { soft in
                            soft.addFilter(.blur(radius: blur))
                            soft.fill(ring, with: fill)
                        }
                    } else {
                        context.fill(ring, with: fill)
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
                // blur at neutral, crisp when excited, and stroked along the
                // outer ring the pass above has already measured.
                if mix > 0.001, rim > 0 {
                    let softened = (1 - mix) * 20
                    if softened > 0.5 { context.addFilter(.blur(radius: softened)) }
                    let intro: Double
                    if let start = progressStart, !field.didSwitch {
                        intro = min(max(now.timeIntervalSince(start) / 0.5, 0), 1)
                    } else {
                        intro = 1
                    }
                    if let arc = engine.arc(
                        center: center,
                        radii: field.outer,
                        head: headFraction(now: now),
                        tail: tailFraction(now: now)
                    ) {
                        context.stroke(
                            arc,
                            with: .color(Self.srgb(tint).opacity(intro)),
                            style: StrokeStyle(lineWidth: comet, lineCap: .round, lineJoin: .round)
                        )
                    }
                }
            }
            .onChange(of: timeline.date) { old, new in
                field.time += max(0, new.timeIntervalSince(old)) * speedJourney.value(now: new)
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
        // Hoisted out of the timeline on purpose. These seven inputs move on
        // user actions, never on the render clock, and from inside the closure
        // they were torn down and re-registered every single frame to observe
        // nothing at all.
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
            rimJourney.retarget(to: target, duration: morphDuration, now: .now)
        }
        .onChange(of: cometWidth) { _, target in
            cometJourney.retarget(to: target, duration: morphDuration, now: .now)
        }
        .onChange(of: progressStart) { old, new in
            // A leg already running has been superseded: remember it, so the
            // tail knows which half of its choreography it is in.
            if old != nil { field.didSwitch = true }
            if new == nil { field.didSwitch = false }
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
        if !field.didSwitch, elapsed < 0.5 {
            return headFraction(now: now) * Self.ease(elapsed / 0.5)
        }
        // Parked anchor: the intro meeting point on leg one, else 0.
        let anchor = field.didSwitch ? 0 : 0.5 / progressDuration
        // Post-switch half: 0.5 → 1 over the first 0.5 s of the new leg.
        if field.didSwitch, elapsed < 0.5 {
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

    /// sRGB components of a colour, as plain numbers. The frame loop is
    /// arithmetic only; this is where the colour-space work happens, once per
    /// body pass instead of once per frame.
    private static func components(of color: Color) -> SIMD3<Double> {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD3(Double(r), Double(g), Double(b))
    }

    /// Rebuilds a colour from components lerped in the canvas. Matches the old
    /// `Color(UIColor(…))` round trip exactly: the tint carried alpha 1, and
    /// opacity is applied separately by the caller.
    private static func srgb(_ c: SIMD3<Double>) -> Color {
        Color(.sRGB, red: c.x, green: c.y, blue: c.z)
    }
}

/// The blob's inputs are all plain values, so a body pass that would produce the
/// identical picture can be skipped outright — which is what `.equatable()` at
/// the call site relies on when the surrounding page churns its drag offset.
///
/// Written by hand because `@State` cannot synthesise: the engine, the field and
/// the six journeys are mutable boxes the caller never sees, and comparing them
/// would defeat the point of the check.
extension BlobView: Equatable {
    static func == (a: BlobView, b: BlobView) -> Bool {
        a.layers == b.layers
            && a.maxRadius == b.maxRadius
            && a.displacement == b.displacement
            && a.smoothing == b.smoothing
            && a.color == b.color
            && a.opacity == b.opacity
            && a.excited == b.excited
            && a.excitedBlend == b.excitedBlend
            && a.excitedMix == b.excitedMix
            && a.morphDuration == b.morphDuration
            && a.displacementDuration == b.displacementDuration
            && a.radiusDuration == b.radiusDuration
            && a.speed == b.speed
            && a.speedDuration == b.speedDuration
            && a.blur == b.blur
            && a.rimWidth == b.rimWidth
            && a.cometWidth == b.cometWidth
            && a.progressStart == b.progressStart
            && a.progressDuration == b.progressDuration
            && a.isLive == b.isLive
    }
}
