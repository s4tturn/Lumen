import SwiftUI

/// The look of a layer in Lumen's focus hierarchy.
///
/// - `visible`: the normal, default look.
/// - `subdued`: recedes — a blur, dim, and scale down.
/// - `subduedAlt`: recedes without shrinking — a blur and dim only.
/// - `hidden`: dissolves — a heavy "blur out" that keeps `subdued`'s scale,
///   while a curved accelerating fade carries it to fully invisible by the
///   end of the transition (no ghost, no residual glow).
enum FocusedState {
    case visible
    case subdued
    case subduedAlt
    case hidden

    var blur: CGFloat {
        switch self {
        case .visible:              return 0
        case .subdued, .subduedAlt: return UIConstants.Focus.subduedBlur
        case .hidden:               return UIConstants.Focus.hiddenBlur
        }
    }

    var opacity: Double {
        switch self {
        case .visible:              return 1
        case .subdued, .subduedAlt: return Double(UIConstants.Focus.subduedOpacity) / 100
        case .hidden:               return 0
        }
    }

    var scale: CGFloat {
        switch self {
        case .visible, .subduedAlt: return 1
        case .subdued, .hidden:     return 1 - UIConstants.Focus.subduedScale / 100
        }
    }

    /// Perceptual duration (seconds) for entering this state. Kept alongside
    /// `motion`/`fade` so callers (e.g. the startup sequence) can schedule
    /// against the same timing without duplicating values. Timings are
    /// deliberately unhurried — an ambient app where yield and dissolve
    /// should feel atmospheric rather than snappy.
    var duration: TimeInterval {
        switch self {
        case .visible:              return 0.4
        case .subdued, .subduedAlt: return 0.55
        case .hidden:               return 0.7
        }
    }

    /// Spring driving the motion properties (blur, scale). Per Apple's
    /// motion guidance (WWDC18 "Designing Fluid Interfaces", WWDC23 "Animate
    /// with springs"): spring-driven, critically damped (`extraBounce: 0`)
    /// for seamless curves. Focusing in snaps in responsively (`snappy`);
    /// receding and dissolving states yield fluidly (`smooth`).
    var motion: Animation {
        switch self {
        case .visible:              return .snappy(duration: duration, extraBounce: 0)
        case .subdued,
             .subduedAlt,
             .hidden:               return .smooth(duration: duration, extraBounce: 0)
        }
    }

    /// Curve driving opacity. Most states dim via the same spring as their
    /// motion. `hidden` instead fades out on an accelerating `easeIn` curve
    /// (starts slowly, speeds up — Apple's classic exit pacing) that lands
    /// on exactly 0 at `duration`, so the element is fully gone by the end.
    var fade: Animation {
        switch self {
        case .visible:              return .snappy(duration: duration, extraBounce: 0)
        case .subdued,
             .subduedAlt:           return .smooth(duration: duration, extraBounce: 0)
        case .hidden:               return .easeIn(duration: duration)
        }
    }
}

extension Alignment {
    var anchor: UnitPoint {
        switch self {
        case .bottom, .bottomLeading, .bottomTrailing: .bottom
        case .top, .topLeading, .topTrailing: .top
        case .leading: .leading
        case .trailing: .trailing
        default: .center
        }
    }
}

struct FocusContainer<Content: View>: View {
    let state: FocusedState
    let alignment: Alignment
    let content: Content

    init(state: FocusedState, alignment: Alignment = .center, @ViewBuilder content: () -> Content) {
        self.state = state
        self.alignment = alignment
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .compositingGroup()
            .blur(radius: state.blur)
            .scaleEffect(state.scale, anchor: alignment.anchor)
            .animation(state.motion, value: state)
            .opacity(state.opacity)
            .animation(state.fade, value: state)
    }
}
