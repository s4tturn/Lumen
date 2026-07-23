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
    @State private var engine = AmbientEngine()
    @State private var greetingState: FocusedState = .hidden
    @State private var navigationState: FocusedState = .subduedAlt
    @State private var ambientState: FocusedState = .subdued

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            FocusContainer(state: navigationState) {
                CoreNavigation()
            }
            .environment(\.onCardExpand, handleCardExpand)

            FocusContainer(state: greetingState) {
                GreetingView()
            }

            FocusContainer(state: ambientState, alignment: .bottom) {
                AmbientPlayer(engine: engine)
            }
            .padding(.bottom, 35)
        }
        .ignoresSafeArea()
        .environment(\.onDotMatrixPress, handleDotMatrixPress)
        .task { await startupSequence() }
    }

    // MARK: - Environment Handlers

    private func handleCardExpand(_ expanding: Bool) {
        withAnimation(.smooth(duration: 0.6)) {
            ambientState = expanding ? .hidden : .visible
        }
    }

    private func handleDotMatrixPress(_ pressing: Bool) {
        withAnimation(.smooth(duration: 0.6)) {
            ambientState = pressing ? .subdued : .visible
        }
    }

    // MARK: - Startup Sequence

    /// Cancellable startup: greeting fades in after 100ms, then the main
    /// interface emerges after 3s. Structured concurrency replaces the old
    /// DispatchQueue timers, cancelling automatically if the view leaves
    /// the hierarchy.
    private func startupSequence() async {
        try? await Task.sleep(for: .milliseconds(100))
        withAnimation(.smooth(duration: 0.8)) {
            greetingState = .visible
        }

        try? await Task.sleep(for: .seconds(3))
        withAnimation(.smooth(duration: 0.8)) {
            greetingState = .hidden
            navigationState = .visible
            ambientState = .visible
        }
    }
}
