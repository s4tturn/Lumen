import Foundation
import SwiftUI

enum UIConstants {
    enum General {
        static let safeSpace: CGFloat = 15
        static let screenCornerRadius: CGFloat = 24
    }

    enum Animation {

        static let dwellDuration: TimeInterval = 0.5

        static let commitDuration: TimeInterval = 0.35

        static let releaseDuration: TimeInterval = 0.38

        static let reducedDuration: TimeInterval = 0.15

        static let briskBounce: Double = 0.15

        static let dwell = SwiftUI.Animation.spring(.smooth(duration: dwellDuration))

        static let commit = SwiftUI.Animation.spring(.snappy(duration: commitDuration))

        static let reduced = SwiftUI.Animation.easeOut(duration: reducedDuration)

        static func releaseSpring(initialVelocity: Double, reduceMotion: Bool) -> SwiftUI.Animation {
            reduceMotionGate(
                initialVelocity == 0
                    ? commit
                    : .interpolatingSpring(
                        duration: releaseDuration,
                        bounce: briskBounce,
                        initialVelocity: min(max(initialVelocity, -6), 6)
                    ),
                reduceMotion: reduceMotion
            )
        }

        static func reduceMotionGate(_ animation: SwiftUI.Animation, reduceMotion: Bool) -> SwiftUI.Animation {
            reduceMotion ? reduced : animation
        }

        private static let dragTrackFastSpeed: CGFloat = 600

        private static let dragTrackSlowResponse: Double = 0.25

        private static let dragTrackFastResponse: Double = 0.15

        static func dragTrack(speed: CGFloat) -> SwiftUI.Animation {
            let t = min(max(speed / dragTrackFastSpeed, 0), 1)
            let response = dragTrackSlowResponse + (dragTrackFastResponse - dragTrackSlowResponse) * Double(t)
            return .spring(response: response, dampingFraction: 1, blendDuration: 0.08)
        }

        enum contentTransition {
            static let blur: CGFloat = 20
            static let opacity: Double = 0
            static let scale: CGFloat = 0.90
        }
    }

    enum Breathe {

        static let breatheRestingSize: CGFloat = 0.25

        static let breatheExhaleSize: CGFloat = 0.35

        static let breatheInhaleSize: CGFloat = 0.15

        static let breatheHoldSize: CGFloat = breatheInhaleSize

        static let breatheSizePointScale: CGFloat = 200 / 0.30

        static var breatheMaxSize: CGFloat {
            max(breatheRestingSize, breatheExhaleSize, breatheInhaleSize, breatheHoldSize)
        }

        static let breatheMaxSizeInPoints: CGFloat = breatheSizePointScale * breatheMaxSize

        static let breatheTimerWidth: CGFloat = 3

        static let breatheLayerBlur: CGFloat = 25

        static let breatheInhaleDuration: TimeInterval = 4
        static let breatheHoldDuration: TimeInterval = 7
        static let breatheExhaleDuration: TimeInterval = 8

        static let breathePromptSize: CGFloat = 30

        static let breathePromptClearance: CGFloat = 50

        static let breathePromptAnchor: CGFloat = breatheMaxSizeInPoints + breathePromptClearance

        static let breatheLetterStagger: TimeInterval = 0.05

        static let breatheLetterTravel: CGFloat = 0.8

        static let breathePromptCycles: Int = 2
    }
}

extension GeometryProxy {

    nonisolated var screenCornerRadius: CGFloat {
        guard let radii = concentricCornerRadii else { return 0 }
        return max(radii.topLeading, radii.topTrailing, radii.bottomLeading, radii.bottomTrailing)
    }
}
