import SwiftUI
import UIKit

/// One blob character: field speed, wobble amount, size fraction.
private struct BreathParams {
    var speed: Double
    var displacement: Double
    var radius: Double
}

private enum BreathStates {
    static let neutral = BreathParams(speed: 0.5, displacement: 0.15, radius: 0.25)
    static let a = BreathParams(speed: 0.8, displacement: 0.30, radius: 0.30)
    static let b = BreathParams(speed: 1.3, displacement: 0.50, radius: 0.15)
}

/// Breathe page: the neutral resting blob, draggable.
/// A still hold plays ticks → pause → thump, then morphs to excited + state A.
/// Letting go starts the breathing loop (4 s A→B, 7 s dwell, 8 s B→A).
/// Holding again at any point reverses back to the separate neutral state.
struct BreatheView: View {
    @Environment(BreathingState.self) private var breathing
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset = CGSize.zero
    @State private var isExcited = false
    @State private var speed = BreathStates.neutral.speed
    @State private var displacement = BreathStates.neutral.displacement
    @State private var radiusFraction = BreathStates.neutral.radius

    @State private var atB = false
    @State private var displacementDuration = 0.25
    @State private var radiusDuration = 0.25
    @State private var speedDuration = 0.25
    @State private var fingerDown = false
    @State private var holdTask: Task<Void, Never>?
    @State private var cycleTask: Task<Void, Never>?
    @State private var awaitingRelease = false
    @State private var progressStart: Date? = nil
    @State private var progressDuration = 4.0
    /// 0 = blob follows the finger 1:1, 100 = blob stays pinned.
    private let damping = 80.0
    /// Movement beyond this means it was a drag, not a hold.
    private static let moveThreshold = 12.0
    private static let morphDuration = 0.25

    /// Shared generators — created once (Apple HIG).
    private let tick = UIImpactFeedbackGenerator(style: .medium)
    private let thump = UIImpactFeedbackGenerator(style: .heavy)

    var body: some View {
        GeometryReader { proxy in
            let minDimension = min(proxy.size.width, proxy.size.height)
            let radius = minDimension * radiusFraction
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
                    morphDuration: reduceMotion ? 0.15 : Self.morphDuration,
                    displacementDuration: displacementDuration,
                    radiusDuration: radiusDuration,
                    speed: reduceMotion ? 0 : speed,
                    speedDuration: speedDuration,
                    blur: 25,
                    rimWidth: isExcited ? 1.4 : 0.7,
                    cometWidth: 1.5,
                    progressStart: progressStart,
                    progressDuration: progressDuration
                )
                .offset(offset)
                .allowsHitTesting(false)
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
                                if hypot(value.translation.width, value.translation.height) > Self.moveThreshold {
                                    // It was a drag — the hold sequence never runs.
                                    cancelHold()
                                }
                                let t = value.translation
                                offset = CGSize(width: t.width * followFactor, height: t.height * followFactor)
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
        .accessibilityLabel("Breathe")
    }

    /// Damping 0 → finger and blob move 1:1; 100 → blob stays pinned.
    /// Cosine ease gives a smooth curve with zero slope at both ends.
    private var followFactor: Double {
        0.5 * (1.0 + cos(.pi * damping / 100.0))
    }

    /// Retargets every continuous parameter at once. Tint, wobble, and size
    /// ease on the render clock; speed is integrated, so it bends smoothly
    /// by construction. One synchronous commit — the journeys retarget together.
    private func goTo(speed: Double, displacement: Double, radius: Double, excited: Bool, tempoDuration: Double, wobbleDuration: Double, sizeDuration: Double) {
        speedDuration = tempoDuration
        displacementDuration = wobbleDuration
        radiusDuration = sizeDuration
        self.speed = speed
        self.displacement = displacement
        radiusFraction = radius
        isExcited = excited
    }

    // MARK: - Still-hold sequence

    /// Neutral → 10 accelerating ticks (0.5 s) → 0.5 s pause → thump, and
    /// state flips exactly on the thump → excited + A. Excited → the mirror
    /// → neutral state, killing the cycle. Nothing changes before the thump,
    /// so pre-thump cancels revert nothing.
    private func startHold() {
        holdTask?.cancel()
        tick.prepare()
        thump.prepare()
        let forward = !isExcited
        holdTask = Task {
            await playTicks(ascending: forward)
            if Task.isCancelled { return }
            try? await Task.sleep(for: .seconds(0.5))
            if Task.isCancelled { return }
            thump.impactOccurred()
            if forward {
                atB = false
                goTo(speed: BreathStates.a.speed, displacement: BreathStates.a.displacement, radius: BreathStates.a.radius, excited: true, tempoDuration: Self.morphDuration, wobbleDuration: Self.morphDuration, sizeDuration: Self.morphDuration)
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
                goTo(speed: BreathStates.neutral.speed, displacement: BreathStates.neutral.displacement, radius: BreathStates.neutral.radius, excited: false, tempoDuration: Self.morphDuration, wobbleDuration: Self.morphDuration, sizeDuration: Self.morphDuration)
                breathing.isBreathing = false
                Focus.visible(.ambient)
            }
            holdTask = nil
        }
    }

    /// Geometric tick train over exactly 0.5 s. Forward accelerates and
    /// brightens; reverse is the mirror — decelerating and softening.
    /// State flips at the thump that follows, never before.
    private func playTicks(ascending: Bool) async {
        let count = 10
        let ratio = ascending ? 0.85 : 1.0 / 0.85
        let total = ascending
            ? (1.0 - pow(ratio, Double(count))) / (1.0 - ratio)
            : (pow(ratio, Double(count)) - 1.0) / (ratio - 1.0)
        for i in 0..<count {
            if Task.isCancelled { return }
            let progress = Double(i) / Double(count - 1)
            tick.impactOccurred(intensity: ascending ? 0.4 + 0.6 * progress : 1.0 - 0.6 * progress)
            try? await Task.sleep(for: .seconds(0.5 * pow(ratio, Double(i)) / total))
        }
    }

    private func cancelHold() {
        holdTask?.cancel()
        holdTask = nil
    }

    // MARK: - Breathing loop: 4 s A→B, 7 s dwell, 8 s B→A

    private func startCycle() {
        cycleTask?.cancel()
        cycleTask = Task {
            while true {
                if Task.isCancelled { return }
                atB = true
                progressStart = .now
                progressDuration = 4
                goTo(speed: BreathStates.b.speed, displacement: BreathStates.b.displacement, radius: BreathStates.b.radius, excited: true, tempoDuration: 4, wobbleDuration: 4, sizeDuration: 4)
                try? await Task.sleep(for: .seconds(4))
                if Task.isCancelled { return }
                progressStart = .now
                progressDuration = 7
                try? await Task.sleep(for: .seconds(7))
                if Task.isCancelled { return }
                atB = false
                progressStart = .now
                progressDuration = 8
                goTo(speed: BreathStates.a.speed, displacement: BreathStates.a.displacement, radius: BreathStates.a.radius, excited: true, tempoDuration: 8, wobbleDuration: 8, sizeDuration: 8)
                try? await Task.sleep(for: .seconds(8))
            }
        }
    }

    /// Release hands the flick velocity to the spring, projected onto the
    /// return direction (fraction of remaining travel per second, clamped).
    /// A near-still finger settles critically damped instead.
    private func settleOffsetToZero(velocity: CGSize) {
        let distance = hypot(offset.width, offset.height)
        guard distance > 0.5 else {
            withAnimation(releaseSpring(velocity: 0)) { offset = .zero }
            return
        }
        let projected = -(velocity.width * offset.width + velocity.height * offset.height)
            / (distance * distance)
        let handoff = hypot(velocity.width, velocity.height) < 100
            ? 0
            : min(max(projected, -6), 6)
        withAnimation(releaseSpring(velocity: handoff)) { offset = .zero }
    }

    private func releaseSpring(velocity: Double) -> Animation {
        UIConstants.Animation.motionGate(
            velocity == 0
                ? .spring(.snappy(duration: 0.35))
                : .interpolatingSpring(duration: 0.38, bounce: 0.15, initialVelocity: velocity),
            reduceMotion: reduceMotion
        )
    }
}

#Preview {
    BreatheView()
        .environment(BreathingState())
}
