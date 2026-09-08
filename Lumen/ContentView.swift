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

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CoreNavigation(collectionsExpanded: $collectionsExpanded)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .focus(.navigation, default: .subdued)

            GreetingView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .focus(.greeting, default: .hidden)

            AmbientPlayer(collectionsExpanded: $collectionsExpanded)
                .focus(.ambient, default: .visible)
        }
        .environment(breathingState)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Lumen")
        .ignoresSafeArea()
        .task { await startupSequence() }
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
