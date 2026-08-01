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
    @State private var store = CompletionStore()
    @State private var greetingState: FocusedState = .hidden
    @State private var navigationState: FocusedState = .subduedAlt
    @State private var ambientState: FocusedState = .subdued
    @State private var pillState: FocusedState = .hidden
    @State private var isCardExpanded = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            FocusContainer(state: navigationState) {
                CoreNavigation()
            }
            .environment(\.onCardExpand, handleCardExpand)
            .environment(\.onFocusedItemChange, handleFocusedItemChange)

            FocusContainer(state: greetingState) {
                GreetingView()
            }

            FocusContainer(state: ambientState, alignment: .bottom) {
                AmbientPlayer(engine: engine)
            }
            .padding(.bottom, 35)

            FocusContainer(state: pillState, alignment: .bottom) {
                CompletePill()
                    .environment(store)
            }
            .padding(.bottom, 70)
            .allowsHitTesting(isCardExpanded)
        }
        .ignoresSafeArea()
        .environment(\.onDotMatrixPress, handleDotMatrixPress)
        .task { await startupSequence() }
    }

    // MARK: - Environment Handlers

    private func handleCardExpand(_ expanding: Bool) {
        // Ambient yields and the pill emerges; both animate via their own
        // FocusedState springs. `isCardExpanded` only gates the pill's
        // hit-testing once the card is gone.
        ambientState = expanding ? .hidden : .visible
        pillState = expanding ? .visible : .hidden
        isCardExpanded = expanding
    }

    private func handleFocusedItemChange(_ item: FocusedItem?) {
        store.setFocused(item)
    }

    private func handleDotMatrixPress(_ pressing: Bool) {
        // Subduing is fluid (longer smooth tail), release is responsive
        // (snappy focus-in) — both driven by FocusedState's own springs.
        ambientState = pressing ? .subdued : .visible
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
        ambientState = .visible
    }

    private static func sleep(_ seconds: TimeInterval) async {
        try? await Task.sleep(for: .milliseconds(Int(seconds * 1000)))
    }
}
