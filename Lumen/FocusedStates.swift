import SwiftUI

enum FocusedState {
    case visible
    case subdued
    case subduedAlt
    case hidden

    var blur: CGFloat {
        switch self {
        case .visible: return 0
        case .subdued: return UIConstants.Focus.subduedBlur
        case .subduedAlt: return UIConstants.Focus.subduedAltBlur
        case .hidden: return UIConstants.Focus.hiddenBlur
        }
    }

    var opacity: Double {
        switch self {
        case .visible: return 1
        case .subdued: return UIConstants.Focus.subduedOpacity / 100
        case .subduedAlt: return UIConstants.Focus.subduedAltOpacity / 100
        case .hidden: return UIConstants.Focus.hiddenOpacity / 100
        }
    }

    var scale: CGFloat {
        switch self {
        case .visible: return 1
        case .subdued: return 1 - UIConstants.Focus.subduedScale / 100
        case .subduedAlt: return 1 - UIConstants.Focus.subduedAltScale / 100
        case .hidden: return 1 - UIConstants.Focus.hiddenScale / 100
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
            .blur(radius: state.blur)
            .opacity(state.opacity)
            .scaleEffect(state.scale, anchor: alignment.anchor)
    }
}
