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

    /// One breath cycle. The long press thump expands the resting blob to the
    /// exhale size; the inhale then contracts to the inhale size, the hold
    /// dwells there, and the exhale returns to where the next inhale starts, so
    /// the loop has no seam to hide.
    enum Breathe {
        // Sizes are radius fractions of the shorter screen edge, so the blob
        // keeps its proportion on every device.

        /// Neutral idle blob: before a long press starts and once it ends.
        static let breatheRestingSize: CGFloat = 0.25
        /// The expanded size. Two jobs, one value: where the thump leaves the
        /// blob, and where the exhale lands — the inhale starts from here.
        static let breatheExhaleSize: CGFloat = 0.35
        /// The contracted size the inhale travels to over its full leg.
        static let breatheInhaleSize: CGFloat = 0.15
        /// Where the hold dwells. The hold issues no `goTo`, so the blob simply
        /// stays where the inhale landed — which is this size, by definition of
        /// the join between those two legs. Referenced so the two can't drift.
        static let breatheHoldSize: CGFloat = breatheInhaleSize

        /// Points per unit of the fractions above. The sizes are fractions of the
        /// shorter screen edge, but the prompt's anchor is a fixed number of
        /// points, so anything that has to clear the blob needs one scale to move
        /// them together: 0.30 reads as 200pt.
        static let breatheSizePointScale: CGFloat = 200 / 0.30

        /// The widest the blob ever gets, read off the sizes above rather than
        /// restated, so the two can't drift apart.
        static var breatheMaxSize: CGFloat {
            max(breatheRestingSize, breatheExhaleSize, breatheInhaleSize, breatheHoldSize)
        }

        /// `breatheMaxSize` measured on the scale above. The blob's real radius is
        /// that fraction of the shorter screen edge; this is the same size read
        /// against the prompt's fixed-point scale.
        static let breatheMaxSizeInPoints: CGFloat = breatheSizePointScale * breatheMaxSize

        /// Stroke width of the snaking timer running the blob's outline.
        static let breatheTimerWidth: CGFloat = 3

        /// Feather applied to every internal ring. The outermost ring is always
        /// drawn crisp — only the layers inside it blur, so the core stays sharp
        /// while the fill softens inward. 0 skips the blur pass entirely.
        static let breatheLayerBlur: CGFloat = 25

        // Leg lengths, in seconds. The timer's head is exact phase progress
        // over the current leg, so these and the morph durations are one value.
        static let breatheInhaleDuration: TimeInterval = 4
        static let breatheHoldDuration: TimeInterval = 7
        static let breatheExhaleDuration: TimeInterval = 8

        // The guidance word. These are points, not fractions of the screen —
        // the word is a fixed piece of type beside the blob, not part of it.
        /// Base point size, scaled from here by Dynamic Type, so 30 is what the
        /// word reads at the default text size rather than a ceiling.
        static let breathePromptSize: CGFloat = 30
        /// Gap between the blob's widest outline and the guidance word, in the
        /// same scaled points as `breatheSizePointScale`.
        static let breathePromptClearance: CGFloat = 50
        /// How far above the blob's centre the guidance word sits. Derived, never
        /// stated: the widest the blob can get, converted to points, plus the
        /// clearance. Widen any size above and the word moves out on its own.
        static let breathePromptAnchor: CGFloat = breatheMaxSizeInPoints + breathePromptClearance
        /// How long after the previous letter the next one starts its rise. Short
        /// enough that the longest word finishes inside a second, so the cascade
        /// reads as one word arriving rather than six letters appearing one at a
        /// time.
        static let breatheLetterStagger: TimeInterval = 0.05
        /// How far below its resting place a letter starts, as a fraction of the
        /// point size, so the rise keeps its proportion as the word scales.
        static let breatheLetterTravel: CGFloat = 0.8
        /// Full inhale → hold → exhale cycles the word coaches before the blob
        /// breathes alone. Past this the prompt has done its job.
        static let breathePromptCycles: Int = 2
    }
}
