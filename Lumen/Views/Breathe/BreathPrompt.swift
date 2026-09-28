import Foundation

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
