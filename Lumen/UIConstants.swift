import Foundation
import SwiftUI

enum UIConstants {
    enum General {
        static let safeSpace: CGFloat = 15
        static let screenCornerRadius: CGFloat = 24
    }

    /// Lumen's whole motion vocabulary: three springs, one Reduce Motion
    /// substitute, one gate, and nothing else. Every animation in the app is
    /// one of these, chosen by what triggered it.
    ///
    /// The two axes are Apple's — *duration sets the pace, bounce sets the
    /// character* ([Animate with springs](https://developer.apple.com/videos/play/wwdc2023/10158/))
    /// — resolved against the three triggers Lumen actually has:
    ///
    /// | Trigger | | Pace | Bounce |
    /// |---|---|---|---|
    /// | Large travel — page turn, full-screen recede, expand | `dwell` | 0.5s | 0 |
    /// | A tap, or a selection the user committed to — press, toggle, card settle, room tab | `commit` | 0.35s | 0.15 |
    /// | A drag the user let go of, carrying its velocity | `release` | 0.38s | 0.15 |
    ///
    /// The rows name the **trigger**, never the component: a room change is a
    /// `commit` because a tab was tapped, not a `dwell` because it moves a
    /// lot. Bounce follows the same rule — it is earned by momentum, so only
    /// a release gets it, however far the thing travels.
    ///
    /// Bounce **0** on the long one is Apple's own default and, in Apple's
    /// words, the most versatile spring there is: no overshoot, so a
    /// full-screen arrival lands and stops rather than ringing. Bounce **0.15**
    /// is the base of Apple's `.snappy`, documented as "not very bouncy yet,
    /// but the long tail feels a little more brisk" — the least that says
    /// *this had momentum behind it*, spent only where something really did
    /// throw the thing. Nothing in Lumen reaches 0.3, let alone the 0.4 above
    /// which Apple says a UI element starts to feel exaggerated.
    ///
    /// Durations are declared first and the springs derived from them, because
    /// `ContentView`'s launch sequence waits the greeting out on these same
    /// numbers: the schedule can never outrun the animation it is timing. And
    /// Apple is explicit that waiting on *perceptual* duration is right here —
    /// never the spring's much longer, unpredictable settling duration.
    ///
    /// `dwell` and `commit` are wrapped in `Animation.spring(_:)`, which makes
    /// them *persistent*: a second animation on the same property replaces the
    /// first and inherits its presented position **and** its velocity, so an
    /// interrupted transition bends toward its new target instead of jumping.
    enum Animation {
        // MARK: - Durations

        /// Perceptual duration of `dwell`: Apple's own `.smooth` default, and
        /// long enough that a full-screen move reads as atmosphere rather than
        /// as a state change.
        static let dwellDuration: TimeInterval = 0.5
        /// Perceptual duration of `commit`: inside the 0.3–0.4s band Apple
        /// gives tap-driven UI, and quick enough to read as an answer.
        static let commitDuration: TimeInterval = 0.35
        /// Perceptual duration of `release`, a shade longer than `commit`
        /// because it has to absorb whatever the finger handed it.
        static let releaseDuration: TimeInterval = 0.38
        /// Duration of `reduced` — the 0.1–0.15s band Reduce Motion asks for,
        /// at the top of it, because a cross-fade too quick to see is not
        /// feedback.
        static let reducedDuration: TimeInterval = 0.15
        /// Bounce on `commit` and `release`. This *is* the base bounce of
        /// `.snappy`, stated once so the preset below and the hand-rolled
        /// spring in `releaseSpring` cannot drift apart.
        static let briskBounce: Double = 0.15

        // MARK: - Springs

        /// Large, slow travel that resolves without ringing: page turns, the
        /// room changing, an expand, anything giving way between states.
        static let dwell = SwiftUI.Animation.spring(.smooth(duration: dwellDuration))

        /// Brisk tap and commit feedback — a press, a toggle, a selection, a
        /// dismissal. Bounced slightly, because a tap is not a throw.
        static let commit = SwiftUI.Animation.spring(.snappy(duration: commitDuration))

        /// What all of them become under Reduce Motion: the same change, with
        /// the bounce taken out, over `reducedDuration`.
        ///
        /// Substituted rather than dropped, on purpose. A state change with no
        /// feedback at all is harder to follow, not easier — this is the rung
        /// of the ladder immediately above "nothing happened".
        static let reduced = SwiftUI.Animation.easeOut(duration: reducedDuration)

        /// The spring a drag hands off to when the finger lets go.
        ///
        /// The one place Lumen has momentum, so the one place the bounce is
        /// earned — Apple's own case for it: bounce "can make sense when you
        /// want your animation to feel more physical, like if it's going to be
        /// used at the end of a gesture". `initialVelocity` is the normalised
        /// relative velocity Apple specifies for a release (gesture velocity
        /// over remaining travel), clamped here rather than at each call site
        /// because a spring handed a wildly wrong velocity does not arrive, it
        /// leaves.
        ///
        /// A still finger gets `commit` instead: nothing was thrown, so there
        /// is nothing to carry, and settling home is tap-band work.
        ///
        /// Gated inside rather than at the call site — it is the only spring
        /// whose value is computed per gesture, and so the one most easily left
        /// bare. Interpolating rather than persistent, because the velocity
        /// arrives explicitly here instead of being tracked by SwiftUI.
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

        // MARK: - Reduce Motion

        /// The one gate. Every animation in Lumen is passed through it, so
        /// switching Reduce Motion on shortens all of the app's motion at once
        /// instead of leaving a hand-written ternary behind somewhere.
        static func reduceMotionGate(_ animation: SwiftUI.Animation, reduceMotion: Bool) -> SwiftUI.Animation {
            reduceMotion ? reduced : animation
        }

        // MARK: - Gesture tracking

        /// Speed (pt/s) at which tracking has reached its tightest response.
        /// A deliberate flick across a full-screen page runs well past this;
        /// a slow considered drag stays well under it.
        private static let dragTrackFastSpeed: CGFloat = 600
        /// Response at rest: the heavy end of the filter, where hand tremor
        /// is the only thing left to reject.
        private static let dragTrackSlowResponse: Double = 0.25
        /// Response at speed: ~48ms of lag, under the point where lag reads
        /// as sluggish, and tremor is irrelevant once the finger is moving.
        private static let dragTrackFastResponse: Double = 0.15

        /// The live-drag tracking filter for a full-screen pager — the one
        /// animation outside the vocabulary above, and deliberately not gated.
        ///
        /// **Not gated, by design.** This *is* the finger moving the page, not
        /// the app moving something on its own; Reduce Motion is a
        /// vestibular setting about motion the user did not ask for, and
        /// stopping a surface tracking the finger mid-drag reads as broken
        /// rather than as calm. What Reduce Motion does tame here is the
        /// release, which is `releaseSpring` — and it is gated.
        ///
        /// A *persistent* spring (`spring(response:dampingFraction:)`), so
        /// every retarget replaces its predecessor and inherits the presented
        /// position **and** velocity — Apple documents that handoff, and
        /// SwiftUI additionally tracks gesture velocity automatically. Because
        /// SwiftUI interpolates the frames between touch samples itself, a
        /// drag costs one state write per touch event and nothing per frame.
        ///
        /// Critically damped on purpose: the target is retargeted on every
        /// sample and so never stops moving, and any overshoot would pull the
        /// page past the finger and snap back. Same reasoning as `dwell` —
        /// paging is arrival.
        ///
        /// Response is a function of gesture speed because lag and jitter
        /// trade off differently: 8–12Hz tremor is only visible when the
        /// finger is barely moving, and lag is only perceptible when there is
        /// motion to lag behind. So filter hard when slow and tighten as the
        /// drag becomes deliberate — 0.25s buys ~7x tremor rejection for ~80ms
        /// of lag that nobody can see at walking pace. `blendDuration` keeps
        /// the stiffness change itself from stepping.
        ///
        /// See https://sosumi.ai/documentation/swiftui/animation/spring(response:dampingfraction:blendduration:)
        static func dragTrack(speed: CGFloat) -> SwiftUI.Animation {
            let t = min(max(speed / dragTrackFastSpeed, 0), 1)
            let response = dragTrackSlowResponse + (dragTrackFastResponse - dragTrackSlowResponse) * Double(t)
            return .spring(response: response, dampingFraction: 1, blendDuration: 0.08)
        }

        // MARK: - Content transition

        /// How far the ambient player's artwork falls back while it is not the
        /// thing being watched. Not a timing — the values an already-applied
        /// `.blur`/`.scaleEffect`/`.opacity` run at — so it sits here as the
        /// motion vocabulary rather than in a view.
        enum contentTransition {
            static let blur: CGFloat = 20
            static let opacity: Double = 0
            static let scale: CGFloat = 0.90
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

// MARK: - Screen geometry

extension GeometryProxy {
    /// The largest of the four corner radii SwiftUI resolves for this view's
    /// bounds against its container shape — the container's own radius less the
    /// distance from each of this view's corners to it.
    ///
    /// On a view whose corners sit on the screen container's corners that
    /// distance is zero, so the largest of the four is the screen's radius. Read
    /// from an inset view it is that view's concentric radius instead, which is
    /// the point: one value, correctly measured wherever it is taken from.
    ///
    /// `0` when no container shape is set, or the container shape carries no
    /// corner information — nothing was resolved, so there is no radius to read.
    /// `nonisolated` because this is read from `onGeometryChange`'s transform
    /// closure, which is `@Sendable` — and the value it reads is a resolved
    /// measurement of a layout, with nothing of the main actor in it.
    nonisolated var screenCornerRadius: CGFloat {
        guard let radii = concentricCornerRadii else { return 0 }
        return max(radii.topLeading, radii.topTrailing, radii.bottomLeading, radii.bottomTrailing)
    }
}
