import SwiftUI

// MARK: - App Entry Point

@main struct LumenApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Root View

/// Root orchestrator for Lumen. Manages the startup greeting sequence,
/// layers all views in a ZStack, and coordinates cross-view focus changes.
struct ContentView: View {
    @State private var greetingState: FocusedState = .hidden
    @State private var navigationState: FocusedState = .subduedAlt

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            FocusContainer(state: navigationState) {
                CoreNavigation()
            }

            FocusContainer(state: greetingState) {
                GreetingView()
            }

            AmbientPlayer()
        }
        .ignoresSafeArea()
        .task { await startupSequence() }
    }

    // MARK: - Startup Sequence

    /// The greeting opens the app with a quiet, unhurried beat (~2s): a brief
    /// pause, a fluid fade-in, a glanceable dwell, then the greeting departs
    /// on its curved `hidden` fade-out as the interface emerges beneath it —
    /// people don't wait for a separate reveal (HIG "Launching", "Onboarding").
    /// All motion is owned by `FocusedState`, so the greeting's fade is
    /// `FocusedState.visible.duration`; `holdDuration` is measured from when
    /// the fade-in *completes*, so dwell never drifts with fade speed.
    private static let appearDelay: TimeInterval = 0.1
    private static let holdDuration: TimeInterval = 0.8

    /// Cancellable startup: brief pause, quick fade in, glanceable dwell,
    /// then the greeting departs as the interface emerges beneath it.
    /// Structured concurrency replaces the old DispatchQueue timers,
    /// cancelling automatically if the view leaves the hierarchy.
    private func startupSequence() async {
        await Self.sleep(Self.appearDelay)
        greetingState = .visible

        await Self.sleep(FocusedState.visible.duration + Self.holdDuration)
        greetingState = .hidden
        navigationState = .visible
    }

    private static func sleep(_ seconds: TimeInterval) async {
        try? await Task.sleep(for: .milliseconds(Int(seconds * 1000)))
    }
}
