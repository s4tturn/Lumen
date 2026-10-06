import SwiftUI

struct ContentView: View {

    private static let greetingHoldDuration: TimeInterval = 0.8

    private static var greetingRevealDelay: TimeInterval {
        UIConstants.Animation.commitDuration + Self.greetingHoldDuration
    }

    @State private var collectionsExpanded = false
    @State private var breathingState = BreathingState()

    @State private var completions = CollectionStore()

    @State private var collectionsFocus = CollectionFocus()

    @State private var isGreetingMounted = true
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            NavigationLayer(
                focus: Focus.state(for: .navigation, default: .subdued),
                collectionsExpanded: $collectionsExpanded
            )
            .equatable()

            if isGreetingMounted {
                GreetingLayer(focus: Focus.state(for: .greeting, default: .hidden))
                    .equatable()
            }

            AmbientLayer(focus: Focus.state(for: .ambient, default: .visible))
                .equatable()
        }

        .environment(breathingState)
        .environment(completions)
        .environment(collectionsFocus)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Lumen")

        .ignoresSafeArea()

        .overlay(alignment: .topLeading) {
            DebugChromeOverlay()
        }
        .task {

            await completions.refresh()

            Task { await Credits.warmUp() }
            await startupSequence()
        }
        .onChange(of: scenePhase) { _, phase in

            guard phase == .active else { return }
            Task { await completions.refresh() }
        }
    }

    private func startupSequence() async {
        Focus.visible(.greeting)
        guard await Self.pause(Self.greetingRevealDelay) else { return }
        Focus.hide(.greeting)
        Focus.visible(.navigation)

        guard await Self.pause(UIConstants.Animation.dwellDuration) else { return }
        isGreetingMounted = false
    }

    private static func pause(_ seconds: TimeInterval) async -> Bool {
        try? await Task.sleep(for: .seconds(seconds))
        return !Task.isCancelled
    }
}

private struct NavigationLayer: View, Equatable {
    let focus: FocusSystem
    @Binding var collectionsExpanded: Bool

    static func == (lhs: NavigationLayer, rhs: NavigationLayer) -> Bool {
        lhs.focus == rhs.focus
            && lhs.collectionsExpanded == rhs.collectionsExpanded
    }

    var body: some View {
        CoreNavigation(collectionsExpanded: $collectionsExpanded)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .focus(focus)
    }
}

private struct GreetingLayer: View, Equatable {
    let focus: FocusSystem

    var body: some View {
        GreetingView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .focus(focus)
    }
}

private struct AmbientLayer: View, Equatable {
    let focus: FocusSystem

    var body: some View {
        AmbientPlayer()

            .focus(focus, anchor: .bottom)
    }
}
