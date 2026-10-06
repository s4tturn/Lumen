import SwiftUI

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

final class BlobField {

    var time = 0.0

    var didSwitch = false

    private(set) var outer: [Double]

    var radii: [Double]
    var scratch: [Double]

    init(samples: Int = BreatheEngine.defaultSamples) {
        outer = [Double](repeating: 0, count: samples)
        radii = [Double](repeating: 0, count: samples)
        scratch = [Double](repeating: 0, count: samples)
    }

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

struct BlobView: View {
    var layers = 5
    var maxRadius: CGFloat = 180
    var displacement = 0.16
    var smoothing = 4
    var color = Color.white
    var opacity = 0.5
    var excited = Color(red: 0.69, green: 0.32, blue: 0.87)

    var excitedBlend = 1.0

    var excitedMix = 0.0

    var morphDuration = 1.0
    var displacementDuration = 1.0
    var radiusDuration = 1.0

    var speed = 1.0
    var speedDuration = 1.0

    var blur: CGFloat = 0

    var rimWidth: CGFloat = 0

    var cometWidth: CGFloat = 1.4

    var progressStart: Date? = nil
    var progressDuration = 4.0

    var isLive: Bool = true

    @State private var engine = BreatheEngine()
    @State private var field = BlobField()

    @State private var mixJourney = Journey()
    @State private var displacementJourney = Journey()
    @State private var radiusJourney = Journey()
    @State private var speedJourney = Journey()
    @State private var rimJourney = Journey()
    @State private var cometJourney = Journey()

    var body: some View {

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

                let fill = GraphicsContext.Shading.color(Self.srgb(tint).opacity(opacity))
                let rim = CGFloat(rimJourney.value(now: now))

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

                    if index == count - 1 {
                        context.stroke(ring, with: .color(.white), lineWidth: 0.7)
                    }
                }

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

            mixJourney = Journey(excitedMix)
            displacementJourney = Journey(displacement)
            radiusJourney = Journey(Double(maxRadius))
            speedJourney = Journey(speed)
            rimJourney = Journey(Double(rimWidth))
            cometJourney = Journey(Double(cometWidth))
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
            rimJourney.retarget(to: target, duration: morphDuration, now: .now)
        }
        .onChange(of: cometWidth) { _, target in
            cometJourney.retarget(to: target, duration: morphDuration, now: .now)
        }
        .onChange(of: progressStart) { old, new in

            if old != nil { field.didSwitch = true }
            if new == nil { field.didSwitch = false }
        }
    }

    private func headFraction(now: Date) -> Double {
        guard let start = progressStart else { return 0 }
        return min(max(now.timeIntervalSince(start) / progressDuration, 0), 1)
    }

    private func tailFraction(now: Date) -> Double {
        guard let start = progressStart else { return 0 }
        let elapsed = now.timeIntervalSince(start)
        if !field.didSwitch, elapsed < 0.5 {
            return headFraction(now: now) * Self.ease(elapsed / 0.5)
        }

        let anchor = field.didSwitch ? 0 : 0.5 / progressDuration

        if field.didSwitch, elapsed < 0.5 {
            return 0.5 + 0.5 * Self.ease(max(elapsed, 0) / 0.5)
        }

        let remaining = progressDuration - elapsed
        if remaining < 0.5, remaining >= 0 {
            return anchor + (0.5 - anchor) * Self.ease((0.5 - remaining) / 0.5)
        }
        return anchor
    }

    private static func ease(_ t: Double) -> Double {
        0.5 - 0.5 * cos(.pi * min(max(t, 0), 1))
    }

    private static func components(of color: Color) -> SIMD3<Double> {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD3(Double(r), Double(g), Double(b))
    }

    private static func srgb(_ c: SIMD3<Double>) -> Color {
        Color(.sRGB, red: c.x, green: c.y, blue: c.z)
    }
}

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
