import CoreHaptics
import UIKit

final class BreathFeedback {

    private let thump = UIImpactFeedbackGenerator(style: .heavy)

    private let ramp = HoldRamp()

    func prepare() {
        thump.prepare()
        ramp.prepare()
    }

    func arm() {
        thump.prepare()
    }

    func ramp(direction: HoldRamp.Direction) {
        ramp.start(direction: direction)
    }

    func stopRamp() {
        ramp.stop()
    }

    func impact() {
        thump.impactOccurred()
    }
}

final class HoldRamp {

    enum Direction {
        case enter
        case exit
    }

    enum Shape: String {

        case linear

        case eager

        case patient

        case smooth

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

        func points(for direction: Direction) -> [(time: Double, value: Double)] {
            guard direction == .exit else { return points }
            return points.reversed().map { (time: 1 - $0.time, value: 1 - $0.value) }
        }
    }

    static let rampDuration: TimeInterval = 0.75

    private static let startIntensity: Float = 0.25

    private static let endIntensity: Float = 0.50

    private static let startSharpness: Float = 0

    private static let endSharpness: Float = 0.75

    private static let shape: Shape = .smooth

    private static let sustained = true

    private static let attackTime: Float = 0.50

    private static let releaseTime: Float = 0.50

    private static let decayTime: Float = 0

    private var engine: CHHapticEngine?
    private var player: (any CHHapticAdvancedPatternPlayer)?

    static var isSupported: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    private func readyEngine() -> CHHapticEngine? {
        if let engine { return engine }
        guard let created = try? CHHapticEngine() else { return nil }
        created.isAutoShutdownEnabled = true

        created.resetHandler = { [weak created] in try? created?.start() }
        engine = created
        return created
    }

    func prepare() {
        guard Self.isSupported, let engine = readyEngine() else { return }
        try? engine.start()
    }

    func start(direction: Direction) {
        guard Self.isSupported, player == nil, let engine = readyEngine() else { return }
        do {
            try engine.start()
            let player = try engine.makeAdvancedPlayer(with: Self.makePattern(direction: direction))
            try player.start(atTime: CHHapticTimeImmediate)
            self.player = player
        } catch {

            self.player = nil
        }
    }

    func stop() {

        try? player?.cancel()
        player = nil
    }

    private static func makePattern(direction: Direction) throws -> CHHapticPattern {
        let entering = direction == .enter
        let intensity = entering ? (startIntensity, endIntensity) : (endIntensity, startIntensity)
        let sharpness = entering ? (startSharpness, endSharpness) : (endSharpness, startSharpness)
        let shape = shape.points(for: direction)

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

    private static func lerp(_ from: Float, _ to: Float, _ t: Double) -> Float {
        Float(Double(from) + t * (Double(to) - Double(from)))
    }
}
import Foundation
import SwiftUI

enum BreathPrompt: Hashable {
    case resting
    case inhale
    case hold
    case exhale

    var word: LocalizedStringResource {
        switch self {
        case .resting: ""
        case .inhale: "Inhale"
        case .hold: "Hold"
        case .exhale: "Exhale"
        }
    }

    var letters: [String] {
        String(localized: word).map { String($0) }
    }
}

struct BreathPromptView: View {
    let prompt: BreathPrompt

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var pointSize = UIConstants.Breathe.breathePromptSize

    var body: some View {
        HStack(spacing: 0) {

            ForEach(Array(prompt.letters.enumerated()), id: \.offset) { index, letter in
                BreathPromptLetter(
                    letter: letter,

                    travel: reduceMotion ? 0 : pointSize * UIConstants.Breathe.breatheLetterTravel,
                    animation: UIConstants.Animation.reduceMotionGate(UIConstants.Animation.dwell, reduceMotion: reduceMotion)
                        .delay(reduceMotion ? 0 : Double(index) * UIConstants.Breathe.breatheLetterStagger)
                )
            }
        }

        .debugSurfaceBorder()

        .font(.system(size: pointSize, design: .serif))

        .id(prompt)

        .focus(.prompt, default: .hidden)

        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(prompt.word))
    }
}

private struct BreathPromptLetter: View {
    let letter: String
    let travel: CGFloat
    let animation: Animation

    @State private var hasRisen = false

    var body: some View {
        Text(letter)
            .foregroundStyle(.white)
            .offset(y: hasRisen ? 0 : travel)
            .opacity(hasRisen ? 1 : 0)
            .animation(animation, value: hasRisen)
            .task { hasRisen = true }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        BreathPromptView(prompt: .exhale)
            .focus(.prompt)
            .offset(y: -UIConstants.Breathe.breathePromptAnchor)
    }
}
