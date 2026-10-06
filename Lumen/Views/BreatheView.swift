import SwiftUI

/// One blob character: field speed and wobble amount. Size and leg lengths
/// live in `UIConstants.Breathe`, which owns the whole breath vocabulary.
private struct BreathParams {
    var speed: Double
    var displacement: Double
}

private enum BreathStates {
    static let neutral = BreathParams(speed: 0.5, displacement: 0.15)
    static let a = BreathParams(speed: 0.8, displacement: 0.30)
    static let b = BreathParams(speed: 1.3, displacement: 0.50)
}

/// Breathe page: the neutral resting blob, draggable.
/// Touching it at all tenses it to 80% under the finger, and the blob
/// rubberbands under a moving finger from that same touch — holding and
/// dragging are one gesture, not a choice between two. Holding still ramps a
/// continuous hum over 0.75 s, falls silent for 0.25 s, and thumps — one
/// second in, and the state flips on the thump to excited + A. Letting go
/// before that costs nothing. Letting go after it starts the breathing loop
/// (inhale → hold → exhale; leg lengths and sizes all live in
/// `UIConstants.Breathe`), which spells the phase as a word above the blob for
/// the first `breathePromptCycles` cycles and then focuses it back out. The
/// blob keeps the middle of the screen and the word sits above it, anchored
/// to it. Holding again at any point reverses back out on the same ramp run
/// backwards, and kills the cycle.
struct BreatheView: View {
    /// Mirrors the pager's liveness: the blob runs only while settled here or
    /// the drag is headed here.
    var isLive: Bool = true

    @Environment(BreathingState.self) private var breathing
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset = CGSize.zero
    @State private var isExcited = false
    @State private var speed = BreathStates.neutral.speed
    @State private var displacement = BreathStates.neutral.displacement
    @State private var radiusFraction = UIConstants.Breathe.breatheRestingSize

    @State private var atB = false
    @State private var prompt = BreathPrompt.resting
    /// How much of its size the blob keeps while a finger is on it — 1 when
    /// untouched. A multiplier on the radius rather than a size of its own, so
    /// it composes with the breathing cycle instead of fighting it: a hold
    /// started mid-exhale tenses from wherever the cycle has got to, and
    /// letting go hands the size straight back.
    @State private var pressScale: CGFloat = 1
    @State private var displacementDuration = 0.25
    @State private var radiusDuration = 0.25
    @State private var speedDuration = 0.25
    @State private var fingerDown = false
    @State private var holdTask: Task<Void, Never>?
    @State private var cycleTask: Task<Void, Never>?
    @State private var awaitingRelease = false
    @State private var progressStart: Date? = nil
    @State private var progressDuration = UIConstants.Breathe.breatheInhaleDuration
    /// How much of its own travel the blob keeps under the finger — 0 moves it
    /// 1:1 with the finger, 100 leaves it pinned. A cosine ease, precomputed:
    /// the constant is fixed, so the `cos` is paid once rather than per drag
    /// sample, and the curve is flat at both ends so nothing snaps.
    private static let followFactor: Double = 0.5 * (1.0 + cos(.pi * 80.0 / 100.0))
    private static let morphDuration = 0.25
    /// How small the blob draws under a finger. Applied to whatever size it
    /// currently is, so it reads as this blob holding itself in rather than
    /// some other size being swapped in.
    private static let pressedSize: CGFloat = 0.8
    /// The whole entrance commitment, however it is split: ramp, then silence,
    /// then thump. Fixed, so tuning the ramp trades it against the silence
    /// rather than making the hold longer or shorter. Read the remainder as
    /// `holdDuration - ramp.rampDuration`; a ramp that fills the whole
    /// commitment leaves no gap, which is a legitimate thing to hear.
    private static let holdDuration: TimeInterval = 1.0

    /// The gesture's haptics, owned once so a re-created view keeps them:
    /// a generator is built to be kept, not rebuilt.
    @State private var feedback = BreathFeedback()

    /// The blob tenses and lets go on the commit character rather than the morph
    /// one — this is the touch answering back, and it should read as immediate.
    private var pressSpring: Animation {
        UIConstants.Animation.reduceMotionGate(UIConstants.Animation.commit, reduceMotion: reduceMotion)
    }

    var body: some View {
        GeometryReader { proxy in
            let minDimension = min(proxy.size.width, proxy.size.height)
            let radius = minDimension * radiusFraction * pressScale
            ZStack {
                Color.black.ignoresSafeArea()
                BlobView(
                    layers: 5,
                    maxRadius: radius,
                    displacement: displacement,
                    opacity: 0.5,
                    excited: .white,
                    excitedBlend: 1.0,
                    excitedMix: isExcited ? 1.0 : 0.0,
                    morphDuration: reduceMotion ? UIConstants.Animation.reducedDuration : Self.morphDuration,
                    displacementDuration: displacementDuration,
                    radiusDuration: radiusDuration,
                    speed: reduceMotion ? 0 : speed,
                    speedDuration: speedDuration,
                    blur: UIConstants.Breathe.breatheLayerBlur,
                    rimWidth: isExcited ? 1.4 : 0.7,
                    cometWidth: UIConstants.Breathe.breatheTimerWidth,
                    progressStart: progressStart,
                    progressDuration: progressDuration,
                    isLive: isLive
                )
                // The drag writes `offset` on every sample, which re-renders this
                // page — but the offset is applied outside the equality check, so
                // a move that leaves the blob's own parameters alone skips its
                // body entirely instead of rebuilding the canvas hierarchy. The
                // picture is identical either way; only the work differs.
                .equatable()
                .offset(offset)
                .allowsHitTesting(false)
                // Anchored to the blob, not the screen: the same translation the
                // blob gets, plus a fixed lift off its centre. The blob keeps the
                // middle of the screen to itself, so the word sits above it at
                // the derived distance however it is dragged.
                BreathPromptView(prompt: prompt)
                    .offset(
                        x: offset.width,
                        y: offset.height - UIConstants.Breathe.breathePromptAnchor
                    )
            }
            // The hitbox lives in the overlay: it can overflow the page as
            // the blob grows without ever contributing to layout size, and
            // the clip bounds both its rendering and its touches. The blob
            // itself only ever draws — offset never affects layout either.
            .overlay(
                Color.clear
                    .frame(width: radius * 2.8, height: radius * 2.8)
                    .contentShape(Circle())
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .local)
                            .onChanged { value in
                                if !fingerDown {
                                    fingerDown = true
                                    startHold()
                                }
                                // Dragging and holding are the same gesture here,
                                // not a choice between two. The hold is already
                                // running, so the blob rubberbands under a moving
                                // finger without disturbing the sequence — and
                                // keeps doing so once the thump has armed it, for
                                // as long as the finger stays down.
                                let t = value.translation
                                offset = CGSize(
                                    width: t.width * Self.followFactor,
                                    height: t.height * Self.followFactor
                                )
                            }
                            .onEnded {
                                fingerDown = false
                                cancelHold()
                                // The cycle only ever starts on release.
                                if awaitingRelease {
                                    awaitingRelease = false
                                    startCycle()
                                }
                                settleOffsetToZero(velocity: $0.velocity)
                            }
                    )
            )
            .clipped()
        }
        .background(.black)
        .onAppear { feedback.prepare() }
        .accessibilityLabel("Breathe")
    }

    /// Retargets every continuous parameter at once. Tint, wobble, and size
    /// ease on the render clock; speed is integrated, so it bends smoothly
    /// by construction. One synchronous commit — the journeys retarget together.
    private func goTo(
        speed: Double,
        displacement: Double,
        radius: CGFloat,
        excited: Bool,
        tempoDuration: Double,
        wobbleDuration: Double,
        sizeDuration: Double
    ) {
        speedDuration = tempoDuration
        displacementDuration = wobbleDuration
        radiusDuration = sizeDuration
        self.speed = speed
        self.displacement = displacement
        radiusFraction = radius
        isExcited = excited
    }

    // MARK: - Still-hold sequence

    /// Either way: the blob tenses, a continuous hum ramps (0.75 s), 0.25 s of
    /// silence, then the thump — and the state flips exactly on the thump. The
    /// exit runs the same ramp inverted, so unwinding is the entrance backwards
    /// rather than a separate gesture. Nothing changes before the thump, so
    /// pre-thump cancels revert nothing but the hum and the tension.
    private func startHold() {
        holdTask?.cancel()
        feedback.arm()
        let forward = !isExcited
        // A touch tenses the blob whichever way the hold is headed — the haptic
        // is what says which one this is, not the size.
        withAnimation(pressSpring) { pressScale = Self.pressedSize }
        feedback.ramp(direction: forward ? .enter : .exit)
        holdTask = Task {
            // The pattern runs the whole ramp itself; the task owns only the
            // silence after it, so the thump lands out of quiet. The remainder
            // of the one-second commitment is the silence, and it is the same
            // length in both directions — so the thump always lands one second
            // in, and reversing out is timed exactly like committing.
            try? await Task.sleep(for: .seconds(HoldRamp.rampDuration))
            if Task.isCancelled { return }
            feedback.stopRamp()
            try? await Task.sleep(for: .seconds(max(0, Self.holdDuration - HoldRamp.rampDuration)))
            if Task.isCancelled { return }
            feedback.impact()
            // The thump lets go as well as puffing out, so the size it lands on
            // is the real one and not 80% of it. Both directions do this, which
            // is why it sits above the fork.
            withAnimation(pressSpring) { pressScale = 1 }
            if forward {
                atB = false
                goTo(
                    speed: BreathStates.a.speed,
                    displacement: BreathStates.a.displacement,
                    radius: UIConstants.Breathe.breatheExhaleSize,
                    excited: true,
                    tempoDuration: Self.morphDuration,
                    wobbleDuration: Self.morphDuration,
                    sizeDuration: Self.morphDuration
                )
                // Excited owns the screen: ambient hides via focus, paging
                // locks and other pages go hit-test/a11y-dark via isBreathing
                // (offscreen pages are already stripped in PageView).
                breathing.isBreathing = true
                Focus.hide(.ambient)
                awaitingRelease = true
            } else {
                cycleTask?.cancel()
                cycleTask = nil
                awaitingRelease = false
                atB = false
                progressStart = nil
                // Recede on the way out too, and blank the word so the next
                // session's first word is a change and cascades in fresh.
                Focus.hide(.prompt)
                prompt = .resting
                goTo(
                    speed: BreathStates.neutral.speed,
                    displacement: BreathStates.neutral.displacement,
                    radius: UIConstants.Breathe.breatheRestingSize,
                    excited: false,
                    tempoDuration: Self.morphDuration,
                    wobbleDuration: Self.morphDuration,
                    sizeDuration: Self.morphDuration
                )
                breathing.isBreathing = false
                Focus.visible(.ambient)
            }
            holdTask = nil
        }
    }

    private func cancelHold() {
        holdTask?.cancel()
        holdTask = nil
        // Lifting early costs nothing but the tension: the hum stops where it
        // is, and the blob lets itself back out to the size it was.
        feedback.stopRamp()
        withAnimation(pressSpring) { pressScale = 1 }
    }

    // MARK: - Breathing loop: inhale → hold → exhale

    private func startCycle() {
        let inhale = UIConstants.Breathe.breatheInhaleDuration
        let hold = UIConstants.Breathe.breatheHoldDuration
        let exhale = UIConstants.Breathe.breatheExhaleDuration
        cycleTask?.cancel()
        cycleTask = Task {
            var coached = 0
            while true {
                if Task.isCancelled { return }
                atB = true
                prompt = .inhale
                // The word has to exist before the layer materializes, or the
                // prompt focuses in empty — hence here rather than on the thump,
                // which would hold a blank word for as long as the finger is down.
                if coached == 0 { Focus.visible(.prompt) }
                progressStart = .now
                progressDuration = inhale
                goTo(
                    speed: BreathStates.b.speed,
                    displacement: BreathStates.b.displacement,
                    radius: UIConstants.Breathe.breatheInhaleSize,
                    excited: true,
                    tempoDuration: inhale,
                    wobbleDuration: inhale,
                    sizeDuration: inhale
                )
                try? await Task.sleep(for: .seconds(inhale))
                if Task.isCancelled { return }
                prompt = .hold
                progressStart = .now
                progressDuration = hold
                try? await Task.sleep(for: .seconds(hold))
                if Task.isCancelled { return }
                atB = false
                prompt = .exhale
                progressStart = .now
                progressDuration = exhale
                goTo(
                    speed: BreathStates.a.speed,
                    displacement: BreathStates.a.displacement,
                    radius: UIConstants.Breathe.breatheExhaleSize,
                    excited: true,
                    tempoDuration: exhale,
                    wobbleDuration: exhale,
                    sizeDuration: exhale
                )
                try? await Task.sleep(for: .seconds(exhale))
                if Task.isCancelled { return }
                // Counted after the exhale, so the word stays up for the whole
                // of the final coached cycle and recedes at the seam.
                coached += 1
                if coached == UIConstants.Breathe.breathePromptCycles {
                    Focus.hide(.prompt)
                }
            }
        }
    }

    /// Release hands the flick velocity to the spring, projected onto the
    /// return direction (fraction of remaining travel per second). A
    /// near-still finger hands over nothing and settles on the tap band.
    private func settleOffsetToZero(velocity: CGSize) {
        let distance = hypot(offset.width, offset.height)
        guard distance > 0.5 else {
            withAnimation(release(0)) { offset = .zero }
            return
        }
        let projected = -(velocity.width * offset.width + velocity.height * offset.height)
            / (distance * distance)
        // Under ~100pt/s the finger was not going anywhere, so there is no
        // velocity worth handing over and the spring settles on the tap band.
        // The clamp on the way in belongs to the shared spring.
        let handoff = hypot(velocity.width, velocity.height) < 100 ? 0 : projected
        withAnimation(release(handoff)) { offset = .zero }
    }

    /// The release spring, shared with the collections wheel: one spring and one
    /// velocity clamp, so a flick lands the same however it was thrown.
    private func release(_ initialVelocity: Double) -> Animation {
        UIConstants.Animation.releaseSpring(initialVelocity: initialVelocity, reduceMotion: reduceMotion)
    }
}

#Preview {
    BreatheView()
        .environment(BreathingState())
}
