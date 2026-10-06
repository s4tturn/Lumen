import Foundation
import SwiftUI

// MARK: - Prompt

/// The word the guidance prompt spells for each phase of the breath cycle.
/// `resting` is the between-sessions state: an empty word spells no letters,
/// which is what makes the next session's first word a real change and sends
/// its letters back down to the bottom of the rise.
enum BreathPrompt: Hashable {
    case resting
    case inhale
    case hold
    case exhale

    /// Localized rather than baked into a `String` at init: resolution happens
    /// at display time, so the word honors the locale in force when it actually
    /// renders. Empty while resting.
    var word: LocalizedStringResource {
        switch self {
        case .resting: ""
        case .inhale: "Inhale"
        case .hold: "Hold"
        case .exhale: "Exhale"
        }
    }

    /// One entry per visible letter, split on grapheme-cluster boundaries so a
    /// translation carrying combining marks or a surrogate pair still reveals one
    /// letter at a time. `String`, not `LocalizedStringResource`: the word was
    /// already localized as a whole above, so each piece must render verbatim.
    var letters: [String] {
        String(localized: word).map { String($0) }
    }
}

// MARK: - View

/// The guidance word above the blob. One serif word, spelled a letter at a
/// time: each letter waits out its delay and then slides up from below the
/// baseline on its own spring, so the word arrives rather than appearing.
///
/// Anchored to the blob, not the screen: the stack centres this on the blob's
/// centre and `BreatheView` lifts it by `breathePromptAnchor`, so the word
/// travels with the blob when it is dragged and springs back with it.
///
/// Layer visibility belongs to the focus system, not to this view. It starts
/// `.hidden` and `BreatheView` walks it to `.visible` for the coaching cycles.
struct BreathPromptView: View {
    let prompt: BreathPrompt

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var pointSize = UIConstants.Breathe.breathePromptSize

    var body: some View {
        HStack(spacing: 0) {
            // Positional ids are the right identity here: `.id(prompt)` below
            // already makes each word a new value, so inside one word a letter
            // only has to hold its slot.
            ForEach(Array(prompt.letters.enumerated()), id: \.offset) { index, letter in
                BreathPromptLetter(
                    letter: letter,
                    // Reduce Motion trades the rise for a plain crossfade and
                    // drops the stagger: the word still changes, it just stops
                    // travelling through space to say so.
                    travel: reduceMotion ? 0 : pointSize * UIConstants.Breathe.breatheLetterTravel,
                    animation: UIConstants.Animation.reduceMotionGate(UIConstants.Animation.dwell, reduceMotion: reduceMotion)
                        .delay(reduceMotion ? 0 : Double(index) * UIConstants.Breathe.breatheLetterStagger)
                )
            }
        }
        // One font for the word, inherited by every letter — and `design: .serif`
        // is the system New York face, not an embedded font.
        .font(.system(size: pointSize, design: .serif))
        // Rebuilds the letters for every word, which is what re-arms the cascade.
        .id(prompt)
        // No frame of its own: the stack centres the word on the blob's centre
        // and `BreatheView` lifts it, so the focus system's scale pivots on the
        // word's own centre and leaves the anchor distance untouched.
        .focus(.prompt, default: .hidden)
        // A label, never a control: it must not take a touch from the drag that
        // moves the blob. After `.focus`, so it wins over the focus system's own
        // hit testing.
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(prompt.word))
    }
}

// MARK: - Letter

/// One letter, born below the baseline and raised into place once it appears.
private struct BreathPromptLetter: View {
    let letter: String
    let travel: CGFloat
    let animation: Animation

    /// Born false, so this letter's first frame is parked below the word. The
    /// task runs once it has appeared, and that flip is the only change
    /// `animation` ever sees — which is what makes the rise a property
    /// animation on this letter's own spring rather than a transition.
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