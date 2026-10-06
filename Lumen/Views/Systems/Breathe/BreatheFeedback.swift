import CoreHaptics
import UIKit

// MARK: - Feedback

/// The feel of the Breathe page's still-hold: a continuous hum that climbs and
/// then falls silent, and one thump out of that silence.
///
/// Both live behind one reference type so the whole gesture's haptics are
/// resources rather than view state. A generator is expensive to build and is
/// meant to be kept — Apple's guidance is to create it once, near where it is
/// used, and prepare it immediately before firing — so owning them from a
/// single object that outlives any one `BreatheView` is what keeps a re-created
/// view from quietly dropping its feedback on the floor.
final class BreathFeedback {
    /// The discrete hit. It is the only single impact left in the app: both
    /// holds ramp and both fall silent, so this is the only moment in the
    /// sequence that lands as one hit.
    private let thump = UIImpactFeedbackGenerator(style: .heavy)
    /// The continuous hum either side of it.
    private let ramp = HoldRamp()

    /// Warms both up ahead of the touch. Starting a haptic engine costs real
    /// time, and a ramp that loses its opening frames to it stops being gradual.
    /// Safe to call more than once.
    func prepare() {
        thump.prepare()
        ramp.prepare()
    }

    /// Arms the thump. Called on touch-down rather than at the moment of the
    /// hit, so the engine has the whole hold to be ready by.
    func arm() {
        thump.prepare()
    }

    /// Begins the hum from wherever the finger went down, in whichever
    /// direction the hold is headed.
    func ramp(direction: HoldRamp.Direction) {
        ramp.start(direction: direction)
    }

    /// Cuts the hum dead, leaving the silence the thump is meant to land in.
    func stopRamp() {
        ramp.stop()
    }

    /// Fires the hit.
    func impact() {
        thump.impactOccurred()
    }
}

// MARK: - Ramp

/// The entrance hold's continuous haptic: a hum that swells through the hold and
/// then stops, so the thump that arms the blob lands out of silence rather than
/// out of the ramp.
///
/// CoreHaptics because nothing in UIKit plays continuous haptics, let alone
/// shapes one over time. The whole escalation is a single pattern with its
/// curves baked in, which is also what makes abandoning a hold free — stopping
/// is one `cancel`, and `BreatheView` carries on as if the ramp had never been
/// asked for.
///
/// Every failure here is silent by design. No haptics on the hardware, or an
/// engine that won't start, leaves the blob quiet and the rest of the sequence
/// intact: the thump still marks the moment, and the thump is the part that
/// carries the meaning.
///
/// The values below were chosen by ear against a throwaway tuner, so they are
/// decisions rather than defaults. Nothing writes them any more.
final class HoldRamp {
    /// Which way the hold is headed. The two ramps are one gesture in opposite
    /// directions, so this decides only which end of each curve is the start —
    /// never the timing, which is shared, so both holds stay a predictable
    /// second long and end on the same thump.
    enum Direction {
        case enter
        case exit
    }

    /// How the climb is shaped over the ramp's duration. Parameter curves
    /// interpolate *linearly between control points*, so these are piecewise
    /// lines and the shape is exactly the points — more points would track a
    /// true curve more closely, but five is already finer than the hand can
    /// resolve.
    ///
    /// Every point is normalised: 0...1 through the ramp, and 0...1 of the way
    /// from this ramp's start value to its end value. So a shape stays a shape
    /// at any pair of endpoints, and the endpoints stay independent of it.
    enum Shape: String {
        /// Two points, one straight line. Honest, and slightly mechanical — it
        /// reads as a machine counting up.
        case linear
        /// Most of the climb in the first third, then a long flat tail. Reads
        /// as eager rather than tense.
        case eager
        /// Barely moves for two thirds, then arrives all at once. Reads as
        /// patient, and gives the thump a real payoff to land on.
        case patient
        /// Eases in and eases out, sampled off a smoothstep. The most
        /// expensive-feeling of the four, and the one this ramp uses.
        case smooth

        /// Normalised `(time, value)` control points. Value is a fraction of the
        /// span between the start and end values, so 0.5 is halfway up the
        /// climb however far apart those two are.
        var points: [(time: Double, value: Double)] {
            switch self {
            case .linear:
                [(0, 0), (1, 1)]
            case .eager:
                [(0, 0), (0.13, 0.6), (0.26, 0.85), (0.5, 0.96), (1, 1)]
            case .patient:
                [(0, 0), (0.5, 0.12), (0.72, 0.3), (0.88, 0.62), (1, 1)]
            case .smooth:
                [(0, 0), (0.25, 0.156), (0.5, 0.5), (0.75, 0.844), (1, 1)]
            }
        }

        /// The points for one direction. Mirroring *both* axes is what makes the
        /// exit the same gesture run backwards rather than merely a swap of
        /// endpoints: reversing time alone would leave the shape climbing the
        /// same way on the way down.
        ///
        /// The S-curve is self-mirroring, so its exit is identical to its
        /// entrance. The other three are not, and would otherwise leave the way
        /// they arrived.
        func points(for direction: Direction) -> [(time: Double, value: Double)] {
            guard direction == .exit else { return points }
            return points.reversed().map { (time: 1 - $0.time, value: 1 - $0.value) }
        }
    }

    /// How long the hum climbs for. Spent out of `BreatheView`'s fixed one-second
    /// commitment, which keeps the thump a predictable one second away however
    /// this changes.
    static let rampDuration: TimeInterval = 0.75

    /// Strength at t=0. Low enough that the hold arrives rather than announces
    /// itself, which is what the shape below is for.
    private static let startIntensity: Float = 0.25
    /// Strength at the end of the ramp. This is the value at a single instant —
    /// the event stops there, so the peak is never held. Well under full, so the
    /// thump that follows reads as a separate event rather than the ramp's
    /// conclusion.
    private static let endIntensity: Float = 0.50
    /// Warmth at t=0: 0 is a soft rumble, 1 a hard buzz. Independent of
    /// intensity, and not a better/worse axis. Zero keeps the opening broad and
    /// body-like, so the buzz that arrives later is a change of texture and not
    /// just more of the same.
    private static let startSharpness: Float = 0
    /// Warmth at the end. What decides whether the ramp arrives as a swell or as
    /// something insistent, and the single biggest lever on how the thump lands
    /// out of it.
    private static let endSharpness: Float = 0.75
    /// How the climb is distributed across the ramp.
    private static let shape: Shape = .smooth

    /// Whether the event holds at full strength between its attack and its
    /// decay, or spends its whole duration on the envelope. Sustained, so the
    /// envelope is attack in and release out, and `decayTime` is never read.
    private static let sustained = true
    /// How long the envelope takes to reach full strength.
    ///
    /// Apple's documentation is not self-consistent about the unit here — the
    /// AHAP reference calls all three "the amount of time" over 0...1, while
    /// `releaseTime`'s own page calls its value seconds. These were settled by
    /// ear against a tuner spanning the device's reported range, which is a more
    /// trustworthy answer than either page.
    private static let attackTime: Float = 0.50
    /// How long a sustained event takes to fade to zero once its duration has
    /// elapsed.
    ///
    /// Currently unreachable: `BreatheView` ends the ramp by cancelling the
    /// player the moment `rampDuration` elapses, which cuts any release short.
    /// The value is what was chosen, and the truncation is a deliberate one —
    /// see `stop()`.
    private static let releaseTime: Float = 0.50
    /// How long an unsustained envelope takes to fall back to zero, from inside
    /// the event's own duration. Inert while `sustained` is true, since a
    /// sustained event never reads it. Kept so the two envelope modes stay
    /// symmetrical and flipping `sustained` is the only edit needed.
    private static let decayTime: Float = 0

    /// Not view state — the engine and its player are resources, and observing
    /// them would imply a view ever depends on them, which none does.
    private var engine: CHHapticEngine?
    private var player: (any CHHapticAdvancedPatternPlayer)?

    /// Gate every entry point on this. Simulator reports no haptic interface,
    /// which is exactly the case where the ramp has to quietly do nothing.
    static var isSupported: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    /// The engine, created and configured on first ask.
    private func readyEngine() -> CHHapticEngine? {
        if let engine { return engine }
        guard let created = try? CHHapticEngine() else { return nil }
        created.isAutoShutdownEnabled = true
        // The system shuts an idle engine down whenever it likes, and a hold
        // that opens in dead air reads as a late start rather than a soft one.
        // Bring it straight back. Weak, or the engine's own handler keeps it
        // alive forever.
        created.resetHandler = { [weak created] in try? created?.start() }
        engine = created
        return created
    }

    /// Spins the engine up ahead of the touch — starting one costs real time,
    /// and a ramp that loses its opening frames to it stops being gradual.
    /// Safe to call more than once.
    func prepare() {
        guard Self.isSupported, let engine = readyEngine() else { return }
        try? engine.start()
    }

    /// Begins the ramp from wherever the finger went down, in whichever direction
    /// the hold is headed. A call while one is already running is ignored, so a
    /// new hold never stacks hums.
    func start(direction: Direction) {
        guard Self.isSupported, player == nil, let engine = readyEngine() else { return }
        do {
            try engine.start()
            let player = try engine.makeAdvancedPlayer(with: Self.makePattern(direction: direction))
            try player.start(atTime: CHHapticTimeImmediate)
            self.player = player
        } catch {
            // Nothing to recover. The sequence treats the ramp as advisory.
            self.player = nil
        }
    }

    /// Cuts the hum dead. Called at the end of the ramp, and on every way out of
    /// the hold, so lifting a finger mid-hum is immediate rather than gradual.
    ///
    /// The silence this leaves is load-bearing — it is what the thump lands in,
    /// and a `releaseTime` fade would fill the gap back in just as the thump
    /// arrived. That is why the cancel is a hard stop at `rampDuration` and the
    /// release is never heard.
    func stop() {
        // `cancel()` throws only on a player the system has already torn down,
        // which is precisely the case where there is nothing left to silence.
        try? player?.cancel()
        player = nil
    }

    /// One continuous event, shaped by two curves across that event's own
    /// duration. The curves are the same shape, applied to two different spans.
    ///
    /// The exit is the entrance run backwards: it leaves at the entrance's peak
    /// and arrives at its floor, sharp-to-soft as well as loud-to-quiet. That is
    /// what makes unwinding read as the reverse of committing rather than as a
    /// second, unrelated flourish, and it is why no separate set of exit levels
    /// exists to drift out of step with the entrance's.
    ///
    /// The advanced player is not a detail: parameter curves are a capability
    /// the standard player doesn't have, and it would play the entire ramp at
    /// the event's opening intensity — a flat hum that happens to last the right
    /// length, which is exactly the failure that wouldn't be obvious in a
    /// screenshot.
    private static func makePattern(direction: Direction) throws -> CHHapticPattern {
        let entering = direction == .enter
        let intensity = entering ? (startIntensity, endIntensity) : (endIntensity, startIntensity)
        let sharpness = entering ? (startSharpness, endSharpness) : (endSharpness, startSharpness)
        let shape = shape.points(for: direction)

        /// The same shape walked across one parameter's span. Both ramps get one
        /// of these, so they can never drift apart in shape — only in where they
        /// start and stop.
        func curve(_ id: CHHapticDynamicParameter.ID, _ span: (Float, Float)) -> CHHapticParameterCurve {
            CHHapticParameterCurve(
                parameterID: id,
                controlPoints: shape.map { point in
                    .init(
                        relativeTime: point.time * rampDuration,
                        value: lerp(span.0, span.1, point.value)
                    )
                },
                relativeTime: 0
            )
        }
        return try CHHapticPattern(
            events: [
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    // The event's own intensity and sharpness are the *identities*
                    // for the two curves, not the ramp's starting point. A control
                    // curve composes with them rather than replacing them, and the
                    // two compose differently: intensity multiplies, sharpness
                    // adds. So 1.0 and 0.0 here make the curves absolute, which is
                    // what makes the levels above mean what they say. Repeating
                    // the start values here instead would play the ramp at
                    // `start * curve` — at a start of 0.25 that would open at
                    // 0.06 and never exceed 0.13.
                    //
                    // The three envelope times are the same kind of static, written
                    // out explicitly so the pattern is fully determined and zero
                    // unambiguously means "no envelope" rather than "whatever the
                    // engine would have defaulted to".
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0),
                        CHHapticEventParameter(parameterID: .sustained, value: sustained ? 1 : 0),
                        CHHapticEventParameter(parameterID: .attackTime, value: attackTime),
                        CHHapticEventParameter(parameterID: .decayTime, value: decayTime),
                        CHHapticEventParameter(parameterID: .releaseTime, value: releaseTime)
                    ],
                    relativeTime: 0,
                    duration: rampDuration
                )
            ],
            parameterCurves: [
                curve(.hapticIntensityControl, intensity),
                curve(.hapticSharpnessControl, sharpness)
            ]
        )
    }

    /// Normalised 0...1 position between two endpoints.
    private static func lerp(_ from: Float, _ to: Float, _ t: Double) -> Float {
        Float(Double(from) + t * (Double(to) - Double(from)))
    }
}