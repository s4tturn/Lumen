import SwiftUI
import UIKit

/// Which size destination currently owns the blob radius. Used so size-slider
/// edits retarget live only when their value is the one in force.
private enum CycleSegment {
    case idle
    case arriving
    case inhale
    case hold
    case exhale
}

struct BreatheView: View {
    @Environment(BreathingState.self) private var breathing
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var blobOffset = CGSize.zero
    @State private var isHeld = false
    @State private var fingerDown = false
    @State private var exceededThreshold = false
    @State private var expansion = 1.0
    @State private var purpleMix = 0.0
    /// Explicit radius state machine, as a fraction of the min dimension.
    /// Driven by arrivals and the 4-7-8 cycle — never sampled from a clock.
    @State private var blobSize = 0.30
    @State private var breathEnergy = 1.25
    @State private var segment: CycleSegment = .idle
    @State private var whiteSize = 0.30
    @State private var purpleBaseSize = 0.36
    @State private var purpleHoldSize = 0.31
    @State private var hapticTask: Task<Void, Never>?
    @State private var pressTask: Task<Void, Never>?
    @State private var cycleTask: Task<Void, Never>?
    private let damping = 85.0
    /// Stillness window before a touch counts as a hold rather than a swipe.
    private static let longPressDelay = 0.35
    /// Movement beyond this cancels the hold path — it was a drag, not a press.
    private static let moveThreshold = 12.0
    /// The purple crossfade duration; the cycle only starts once it has landed.
    private static let arrivalDuration = 2.0

    // Deterministic scene: fixed root seed, full geometric smoothing.
    private var scene: BlobScene {
        var configuration = BlobConfiguration.default
        configuration.smoothingPasses = 6
        return BlobScene(rootSeed: 0x11E9A9, configuration: configuration)
    }

    /// Damping 0 → finger and blob move 1:1; 100 → blob stays pinned.
    /// Cosine ease gives a smooth curve with zero slope at both ends.
    private var followFactor: Double {
        0.5 * (1.0 + cos(.pi * damping / 100.0))
    }

    /// Session energy, faded by the purple crossfade so exits glide home.
    /// White baseline is 1; purple never drops below 1.25.
    private var energy: Double {
        1.0 + (breathEnergy - 1.0) * purpleMix
    }

    private func spring(_ duration: TimeInterval) -> Animation {
        UIConstants.Animation.motionGate(
            .spring(duration: duration, bounce: 0),
            reduceMotion: reduceMotion
        )
    }

    /// Slow crossfade for the white↔purple session shift — gentle, not a snap.
    private func gentleShift() -> Animation {
        UIConstants.Animation.motionGate(
            .easeInOut(duration: Self.arrivalDuration),
            reduceMotion: reduceMotion
        )
    }

    /// A touch becomes a hold only if the finger stays put past the long-press
    /// window. Any real movement first means it was a drag: the hold path
    /// (expansion, haptics, session entry/exit) never engages.
    private func engage() {
        pressTask = nil
        guard !isHeld else { return }
        isHeld = true
        if breathing.isBreathing {
            startExitSequence()
        } else {
            withAnimation(spring(1.0)) { expansion = 1.2 }
            startEntrySequence()
        }
    }

    /// Movement beyond the threshold mid-hold aborts the hold: sequences stop
    /// and an uncommitted expansion relaxes. A live breathing session survives
    /// (it only ends via a still exit hold), holding 1.2×.
    private func abortHold() {
        pressTask?.cancel()
        pressTask = nil
        isHeld = false
        stopHaptics()
        if !breathing.isBreathing {
            withAnimation(spring(1.0)) { expansion = 1.0 }
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let blobRadius = min(proxy.size.width, proxy.size.height) * blobSize
            ZStack {
                Color.black.ignoresSafeArea()
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    Canvas { context, size in
                        let now = timeline.date.timeIntervalSinceReferenceDate
                        let time = reduceMotion ? 0.0 : now
                        Self.draw(
                            context: &context,
                            size: size,
                            time: time,
                            scene: scene,
                            purpleMix: purpleMix,
                            blobSize: blobSize,
                            energy: energy
                        )
                    }
                }
                .accessibilityHidden(true)
                .offset(blobOffset)
                .scaleEffect(expansion)

                // Circular hitbox around the blob. Drags track 1:1 with no
                // animation context; release hands off to a spring.
                Color.clear
                    .frame(width: blobRadius * 2.8, height: blobRadius * 2.8)
                    .contentShape(Circle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !fingerDown {
                                    fingerDown = true
                                    exceededThreshold = false
                                    pressTask?.cancel()
                                    pressTask = Task {
                                        try? await Task.sleep(
                                            for: .seconds(Self.longPressDelay)
                                        )
                                        guard !Task.isCancelled else { return }
                                        await MainActor.run {
                                            guard !Task.isCancelled,
                                                  fingerDown,
                                                  !exceededThreshold
                                            else { return }
                                            engage()
                                        }
                                    }
                                }
                                let moved = hypot(
                                    value.translation.width,
                                    value.translation.height
                                ) > Self.moveThreshold
                                if moved {
                                    exceededThreshold = true
                                    if pressTask != nil || isHeld {
                                        abortHold()
                                    }
                                }
                                let raw = CGSize(
                                    width: value.translation.width * followFactor,
                                    height: value.translation.height * followFactor
                                )
                                blobOffset = Self.rubberband(raw, max: blobRadius)
                            }
                            .onEnded { _ in
                                fingerDown = false
                                pressTask?.cancel()
                                pressTask = nil
                                isHeld = false
                                stopHaptics()
                                // In a breathing session the blob holds 1.2×
                                // until the exit hold completes.
                                if !breathing.isBreathing {
                                    withAnimation(spring(1.0)) { expansion = 1.0 }
                                }
                                withAnimation(
                                    UIConstants.Animation.motionGate(
                                        .snappy(duration: 0.4),
                                        reduceMotion: reduceMotion
                                    )
                                ) {
                                    blobOffset = .zero
                                }
                            }
                    )

                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        sizeSlider(title: "White", value: $whiteSize)
                        sizeSlider(title: "Base", value: $purpleBaseSize)
                        sizeSlider(title: "Hold", value: $purpleHoldSize)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
        .background(.black)
        .accessibilityLabel("Breathe")
        .accessibilityAddTraits(.isHeader)
        .onChange(of: whiteSize) {
            // Live retarget only when white is the size in force.
            if !breathing.isBreathing {
                withAnimation(.easeInOut(duration: 1.0)) { blobSize = whiteSize }
            }
        }
        .onChange(of: purpleBaseSize) {
            // Base is in force while arriving or exhaling back to it.
            if breathing.isBreathing, segment == .arriving || segment == .exhale {
                withAnimation(.easeInOut(duration: 1.0)) { blobSize = purpleBaseSize }
            }
        }
        .onChange(of: purpleHoldSize) {
            // Hold is in force while inhaling toward it or resting in it.
            if breathing.isBreathing, segment == .inhale || segment == .hold {
                withAnimation(.easeInOut(duration: 1.0)) { blobSize = purpleHoldSize }
            }
        }
    }

    private func sizeSlider(title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 88, alignment: .leading)
            Slider(value: value, in: 0.15...0.50)
                .tint(.white)
            Text(String(format: "%.2f", value.wrappedValue))
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }

    // MARK: - Entry: hold → accelerating ticks → thump → breathing session

    private func startEntrySequence() {
        stopHaptics()
        hapticTask = Task {
            let tick = UIImpactFeedbackGenerator(style: .medium)
            tick.prepare()
            let landing = UIImpactFeedbackGenerator(style: .heavy)
            landing.prepare()
            let count = 10
            let ratio = 0.8
            let geometricSum = (1.0 - pow(ratio, Double(count))) / (1.0 - ratio)
            for i in 0..<count {
                if Task.isCancelled { return }
                tick.impactOccurred(intensity: 0.5 + 0.5 * Double(i) / Double(count - 1))
                let interval = 0.5 * pow(ratio, Double(i)) / geometricSum
                try? await Task.sleep(for: .seconds(interval))
            }
            if Task.isCancelled { return }
            try? await Task.sleep(for: .seconds(0.25))
            if Task.isCancelled { return }
            landing.impactOccurred()
            await MainActor.run {
                guard !Task.isCancelled, isHeld, !breathing.isBreathing else { return }
                breathing.isBreathing = true
                segment = .arriving
                Focus.hide(.ambient)
                withAnimation(gentleShift()) {
                    purpleMix = 1.0
                    blobSize = purpleBaseSize
                    breathEnergy = 1.25
                }
                hapticTask = nil
                // The cycle starts only once purple has fully landed — and
                // only once the finger leaves (see maybeStartCycle).
                startCycleSupervisor()
            }
        }
    }

    // MARK: - 4-7-8 cycle: gated on arrival, then on release, then looping

    private func startCycleSupervisor() {
        cycleTask?.cancel()
        cycleTask = Task {
            // Purple fully achieved first: never breathe on a half-shifted blob.
            try? await Task.sleep(for: .seconds(Self.arrivalDuration))
            guard !Task.isCancelled else { return }
            guard await MainActor.run(body: { breathing.isBreathing }) else { return }
            // Then the finger must leave: holding through arrival waits here.
            while true {
                if Task.isCancelled { return }
                let down = await MainActor.run { fingerDown }
                if !down { break }
                try? await Task.sleep(for: .seconds(0.2))
            }
            guard !Task.isCancelled else { return }
            guard await MainActor.run(body: { breathing.isBreathing }) else { return }
            // 4 s inhale → 7 s hold → 8 s exhale, looping until the session ends.
            while !Task.isCancelled {
                guard await MainActor.run(body: { breathing.isBreathing }) else { return }
                await MainActor.run {
                    segment = .inhale
                    withAnimation(.easeInOut(duration: 4.0)) {
                        blobSize = purpleHoldSize
                        breathEnergy = 1.7
                    }
                }
                try? await Task.sleep(for: .seconds(4.0))
                guard !Task.isCancelled else { return }
                await MainActor.run { segment = .hold }
                try? await Task.sleep(for: .seconds(7.0))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    segment = .exhale
                    withAnimation(.easeInOut(duration: 8.0)) {
                        blobSize = purpleBaseSize
                        breathEnergy = 1.25
                    }
                }
                try? await Task.sleep(for: .seconds(8.0))
            }
        }
    }

    // MARK: - Exit: hold in breathing state → decelerating ticks → thump → release

    /// Inverse of the entry score: ticks slow down and soften instead of
    /// accelerating, then the same heavy thump, then the blob animates to the
    /// white size from wherever the cycle left it while ambient returns and
    /// paging unlocks.
    private func startExitSequence() {
        stopHaptics()
        hapticTask = Task {
            let tick = UIImpactFeedbackGenerator(style: .medium)
            tick.prepare()
            let landing = UIImpactFeedbackGenerator(style: .heavy)
            landing.prepare()
            let count = 10
            let ratio = 1.25
            let geometricSum = (pow(ratio, Double(count)) - 1.0) / (ratio - 1.0)
            for i in 0..<count {
                if Task.isCancelled { return }
                tick.impactOccurred(intensity: 1.0 - 0.5 * Double(i) / Double(count - 1))
                let interval = 0.5 * pow(ratio, Double(i)) / geometricSum
                try? await Task.sleep(for: .seconds(interval))
            }
            if Task.isCancelled { return }
            try? await Task.sleep(for: .seconds(0.25))
            if Task.isCancelled { return }
            landing.impactOccurred()
            await MainActor.run {
                guard !Task.isCancelled, isHeld, breathing.isBreathing else { return }
                cycleTask?.cancel()
                cycleTask = nil
                segment = .idle
                withAnimation(spring(0.5)) {
                    expansion = 1.0
                    blobSize = whiteSize
                    breathEnergy = 1.25
                    breathing.isBreathing = false
                }
                withAnimation(gentleShift()) { purpleMix = 0.0 }
                Focus.visible(.ambient)
                hapticTask = nil
            }
        }
    }

    private func stopHaptics() {
        hapticTask?.cancel()
        hapticTask = nil
    }

    /// Progressive resistance past the boundary: full travel inside, only a
    /// fraction of the excess outside — never a hard stop.
    private static func rubberband(_ translation: CGSize, max: CGFloat) -> CGSize {
        let distance = hypot(translation.width, translation.height)
        guard distance > max, distance > 0 else { return translation }
        let scale = (max + (distance - max) * 0.25) / distance
        return CGSize(width: translation.width * scale, height: translation.height * scale)
    }

    // MARK: - Drawing

    /// White → purple lerp for the breathing session, alpha held at 0.5.
    private static func fillColor(purpleMix: Double) -> Color {
        Color(
            red: 1.0 - 0.31 * purpleMix,
            green: 1.0 - 0.68 * purpleMix,
            blue: 1.0 - 0.13 * purpleMix,
            opacity: 0.5
        )
    }

    private static func rimColor(purpleMix: Double) -> Color {
        Color(
            red: 1.0 - 0.31 * purpleMix,
            green: 1.0 - 0.68 * purpleMix,
            blue: 1.0 - 0.13 * purpleMix,
            opacity: 0.28 + 0.07 * purpleMix
        )
    }

    // Paint order: outer body → nested layers → rim.
    // The outer path is generated once per frame and reused for fill and rim.
    private static func draw(
        context: inout GraphicsContext,
        size: CGSize,
        time: Double,
        scene: BlobScene,
        purpleMix: Double,
        blobSize: Double,
        energy: Double
    ) {
        guard size.width > 0, size.height > 0 else { return }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) * blobSize
        let breathing = scene.breathing(time: time)
        let outerPath = scene.outer.path(
            center: center,
            targetRadius: radius,
            time: time,
            breathing: breathing,
            energy: energy
        )

        context.fill(outerPath, with: .color(fillColor(purpleMix: purpleMix)))

        for layer in scene.layers {
            let ring = layer.generator.path(
                center: center,
                targetRadius: radius * layer.inset,
                time: time,
                breathing: breathing,
                energy: energy
            )
            // Feathered edge: a slight blur melts each layer's boundary into
            // the layer beneath instead of a hard cut. Fill and separator are
            // blurred together so no crisp line survives on top.
            context.drawLayer { soft in
                soft.addFilter(.blur(radius: 20))
                soft.fill(ring, with: .color(fillColor(purpleMix: purpleMix)))
                soft.stroke(ring, with: .color(.black.opacity(0.2)), lineWidth: 1)
            }
        }

        context.stroke(outerPath, with: .color(rimColor(purpleMix: purpleMix)), lineWidth: 1.5)
    }
}

#Preview {
    BreatheView()
        .environment(BreathingState())
}
