import SwiftUI

enum FocusSystem: String, CaseIterable {
    case visible
    case subdued
    case hidden

    enum Constant {
        static let subduedBlur: CGFloat = 10
        static let subduedDim: Double = 0.75
        static let subduedScale: CGFloat = 0.95
        static let hiddenBlur: CGFloat = 100
        static let hiddenDim: Double = 0
        static let hiddenScale: CGFloat = 0.80
    }

    var blur: CGFloat {
        switch self {
        case .visible: return 0
        case .subdued: return Constant.subduedBlur
        case .hidden:  return Constant.hiddenBlur
        }
    }

    var opacity: Double {
        switch self {
        case .visible: return 1
        case .subdued: return Constant.subduedDim
        case .hidden:  return Constant.hiddenDim
        }
    }

    var scale: CGFloat {
        switch self {
        case .visible: return 1
        case .subdued: return Constant.subduedScale
        case .hidden:  return Constant.hiddenScale
        }
    }

    var isInteractive: Bool { self != .hidden }


    /// Spring driving blur, scale, and opacity — gated by
    /// `UIConstants.Animation.motionGate` in `FocusEffect` when Reduce Motion
    /// is on. Focusing in snaps responsively; receding yields fluidly.
    var animation: Animation {
        switch self {
        case .visible: return UIConstants.Animation.snappySpring
        case .subdued, .hidden: return UIConstants.Animation.smoothSpring
        }
    }
}

enum FocusLayer: String, CaseIterable {
    case greeting
    case navigation
    case ambient
}

enum Focus {
    private static let store = Store()

    static func state(for layer: FocusLayer, default defaultState: FocusSystem = .visible) -> FocusSystem {
        store.state(for: layer, default: defaultState)
    }

    static func visible(_ layer: FocusLayer) { store.set(.visible, for: layer) }
    static func subdue(_ layer: FocusLayer) { store.set(.subdued, for: layer) }
    static func hide(_ layer: FocusLayer) { store.set(.hidden, for: layer) }

    @Observable @MainActor
    final class Store {
        private var states: [FocusLayer: FocusSystem] = [:]

        func state(for layer: FocusLayer, default defaultState: FocusSystem) -> FocusSystem {
            states[layer] ?? defaultState
        }

        func set(_ state: FocusSystem, for layer: FocusLayer) {
            states[layer] = state
        }
    }
}

struct FocusEffect: ViewModifier {
    let state: FocusSystem
    let anchor: UnitPoint
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let motion = UIConstants.Animation.motionGate(state.animation, reduceMotion: reduceMotion)
        let fade = UIConstants.Animation.motionGate(state.animation, reduceMotion: reduceMotion)
        content
            .compositingGroup()
            .blur(radius: state.blur)
            .scaleEffect(state.scale, anchor: anchor)
            .animation(motion, value: state)
            .opacity(state.opacity)
            .animation(fade, value: state)
            .allowsHitTesting(state.isInteractive)
            .accessibilityHidden(state == .hidden)
    }
}

extension View {
    func focus(_ state: FocusSystem, anchor: UnitPoint = .center) -> some View {
        modifier(FocusEffect(state: state, anchor: anchor))
    }

    func focus(
        _ layer: FocusLayer,
        default defaultState: FocusSystem = .visible,
        anchor: UnitPoint = .center
    ) -> some View {
        focus(Focus.state(for: layer, default: defaultState), anchor: anchor)
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
