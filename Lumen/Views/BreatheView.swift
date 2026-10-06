import SwiftUI

private struct BreathParams {
    var speed: Double
    var displacement: Double
}

private enum BreathStates {
    static let neutral = BreathParams(speed: 0.5, displacement: 0.15)
    static let a = BreathParams(speed: 0.8, displacement: 0.30)
    static let b = BreathParams(speed: 1.3, displacement: 0.50)
}

struct BreatheView: View {

    var isLive: Bool = true

    @Environment(BreathingState.self) private var breathing
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset = CGSize.zero
    @State private var isExcited = false
    @State private var speed = BreathStates.neutral.speed
    @State private var displacement = BreathStates.neutral.displacement
    @State private var radiusFraction = UIConstants.Breathe.breatheRestingSize

    @State private var prompt = BreathPrompt.resting

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

    private static let followFactor: Double = 0.5 * (1.0 + cos(.pi * 80.0 / 100.0))
    private static let morphDuration = 0.25

    private static let pressedSize: CGFloat = 0.8

    private static let holdDuration: TimeInterval = 1.0

    @State private var feedback = BreathFeedback()

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

                .equatable()
                .offset(offset)
                .allowsHitTesting(false)

                BreathPromptView(prompt: prompt)
                    .offset(
                        x: offset.width,
                        y: offset.height - UIConstants.Breathe.breathePromptAnchor
                    )
            }

            .overlay(
                Color.clear
                    .frame(width: radius * 2.8, height: radius * 2.8)
                    .contentShape(Circle())

                    .debugSurfaceBorder(Circle())
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .local)
                            .onChanged { value in
                                if !fingerDown {
                                    fingerDown = true
                                    startHold()
                                }

                                let t = value.translation
                                offset = CGSize(
                                    width: t.width * Self.followFactor,
                                    height: t.height * Self.followFactor
                                )
                            }
                            .onEnded {
                                fingerDown = false
                                cancelHold()

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

    private func startHold() {
        holdTask?.cancel()
        feedback.arm()
        let forward = !isExcited

        withAnimation(pressSpring) { pressScale = Self.pressedSize }
        feedback.ramp(direction: forward ? .enter : .exit)
        holdTask = Task {

            try? await Task.sleep(for: .seconds(HoldRamp.rampDuration))
            if Task.isCancelled { return }
            feedback.stopRamp()
            try? await Task.sleep(for: .seconds(max(0, Self.holdDuration - HoldRamp.rampDuration)))
            if Task.isCancelled { return }
            feedback.impact()

            withAnimation(pressSpring) { pressScale = 1 }
            if forward {
                goTo(
                    speed: BreathStates.a.speed,
                    displacement: BreathStates.a.displacement,
                    radius: UIConstants.Breathe.breatheExhaleSize,
                    excited: true,
                    tempoDuration: Self.morphDuration,
                    wobbleDuration: Self.morphDuration,
                    sizeDuration: Self.morphDuration
                )

                breathing.isBreathing = true
                Focus.hide(.ambient)
                awaitingRelease = true
            } else {
                cycleTask?.cancel()
                cycleTask = nil
                awaitingRelease = false
                progressStart = nil

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

        feedback.stopRamp()
        withAnimation(pressSpring) { pressScale = 1 }
    }

    private func startCycle() {
        let inhale = UIConstants.Breathe.breatheInhaleDuration
        let hold = UIConstants.Breathe.breatheHoldDuration
        let exhale = UIConstants.Breathe.breatheExhaleDuration
        cycleTask?.cancel()
        cycleTask = Task {
            var coached = 0
            while true {
                if Task.isCancelled { return }
                prompt = .inhale

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

                coached += 1
                if coached == UIConstants.Breathe.breathePromptCycles {
                    Focus.hide(.prompt)
                }
            }
        }
    }

    private func settleOffsetToZero(velocity: CGSize) {
        let distance = hypot(offset.width, offset.height)
        guard distance > 0.5 else {
            withAnimation(release(0)) { offset = .zero }
            return
        }
        let projected = -(velocity.width * offset.width + velocity.height * offset.height)
            / (distance * distance)

        let handoff = hypot(velocity.width, velocity.height) < 100 ? 0 : projected
        withAnimation(release(handoff)) { offset = .zero }
    }

    private func release(_ initialVelocity: Double) -> Animation {
        UIConstants.Animation.releaseSpring(initialVelocity: initialVelocity, reduceMotion: reduceMotion)
    }
}

#Preview {
    BreatheView()
        .environment(BreathingState())
}
