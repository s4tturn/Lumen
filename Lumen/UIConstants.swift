import Foundation
import SwiftUI

enum UIConstants {
    enum General {
        static let screenCornerRadius: CGFloat = 40
        static let safeSpace: CGFloat = 15
    }

    enum Animation {
        // Shared vocabulary — use nothing else. Two characters: smooth is the
        // cinematic dwell (fullscreen recede, page turns, expands — critically
        // damped, so length reads as atmosphere); snappy is tap/commit
        // feedback (apple-motion-feel tap-driven band is 0.3–0.4s).
        static let smoothDuration: TimeInterval = 0.5
        static let snappyDuration: TimeInterval = 0.35
        static let reducedDuration: TimeInterval = 0.15
        static let smoothSpring = SwiftUI.Animation.spring(.smooth(duration: smoothDuration))
        enum contentTransition {
            static let blur: CGFloat = 20
            static let opacity: Double = 0
            static let scale: CGFloat = 0.90
        }
        static let snappySpring = SwiftUI.Animation.spring(.snappy(duration: snappyDuration))
        // Reduce Motion substitute: shortened and bounceless per
        // apple-motion-feel (0.1–0.15s band), applied via motionGate.
        static let motionReduced = SwiftUI.Animation.easeOut(duration: reducedDuration)

        /// Reduce-motion gate: substitutes a short crossfade instead of
        /// removing feedback. Every reduce-motion ternary goes through here.
        static func motionGate(_ animation: SwiftUI.Animation, reduceMotion: Bool) -> SwiftUI.Animation {
            reduceMotion ? motionReduced : animation
        }
    }
}
