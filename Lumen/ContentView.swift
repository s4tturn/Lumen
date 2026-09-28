import SwiftUI

// MARK: - App Entry Point

@main struct LumenApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    private static let greetingHoldDuration: TimeInterval = 0.8
    private static var greetingRevealDelay: TimeInterval {
        UIConstants.Animation.snappyDuration + Self.greetingHoldDuration
    }

    @State private var collectionsExpanded = false
    @State private var breathingState = BreathingState()
    /// One record of what has been finished, shared by the collections pager,
    /// the ambient player's complete control and the completed list in Memory.
    @State private var completions = CollectionCompletionStore()
    /// The task the open card is showing. Owned here rather than by either of the
    /// two views that need it, because the collections page and the ambient
    /// player are siblings: only something above both can be a shared fact.
    @State private var collectionsFocus = CollectionFocus()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CoreNavigation(collectionsExpanded: $collectionsExpanded)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .focus(.navigation, default: .subdued)

            GreetingView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .focus(.greeting, default: .hidden)

            AmbientPlayer()
                // Anchored at the pill, not screen center: the scale effect
                // must grow out of the object itself.
             .focus(.ambient, default: .visible, anchor: .bottom)
        }
        .environment(breathingState)
        .environment(completions)
        .environment(collectionsFocus)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Lumen")
        .ignoresSafeArea()
        .task {
            // Before the reveal, not after: the completed list in Memory has to
            // be populated the first time it can be seen, or it flashes empty.
            await completions.refresh()
            await startupSequence()
        }
        .onChange(of: scenePhase) { _, phase in
            // iCloud Keychain gives no notification when a completion arrives
            // from another device, so coming back to the foreground is when the
            // list is re-read.
            guard phase == .active else { return }
            Task { await completions.refresh() }
        }
    }
    
    private func startupSequence() async {
        Focus.visible(.greeting)
        await Self.sleep(Self.greetingRevealDelay)
        Focus.hide(.greeting)
        Focus.visible(.navigation)
    }

    private static func sleep(_ seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
    }
}
