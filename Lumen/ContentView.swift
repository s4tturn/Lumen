import SwiftUI

// MARK: - App Entry Point

@main struct LumenApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// The window's root: black, the five-page pager, the greeting and the ambient
/// transport, stacked full-bleed. Composition, and as little else as possible.
///
/// Three decisions here carry the weight, all of them invisible on screen:
///
/// - **Layers are separate `View` types fed value inputs.** A view body only
///   re-runs when something that body read has changed, so resolving each
///   layer's focus state here and passing it down is what stops one layer's
///   focus write from rebuilding the other two. BreatheView re-focuses the
///   ambient player and the prompt on every hold; those writes no longer reach
///   the pager.
/// - **Every layer sits behind `.equatable()`.** Equal inputs skip the subtree,
///   so the three focus writes of the launch sequence and the four of a
///   breathing session cost a few scalar comparisons instead of re-rendering
///   five pages and a glass player.
/// - **The greeting is mounted, not resident.** `FocusSystem.hidden` is a
///   full-screen compositing group at a 100pt blur radius: real work and real
///   GPU memory for a layer that can never be seen again. It leaves the tree as
///   soon as it has finished receding, which cannot be seen — by then it is at
///   zero opacity, out of hit testing and out of the accessibility tree.
struct ContentView: View {
    /// How long the greeting rests at full focus once its reveal has landed.
    private static let greetingHoldDuration: TimeInterval = 0.8

    /// Reveal plus hold: when the greeting hands the screen back.
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
    /// Whether the launch greeting is still in the tree. Launch-time only —
    /// nothing ever focuses it again, so it is retired rather than kept at a
    /// full-screen blur forever.
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
        // One injection for the two subtrees that read these; the greeting reads
        // none of them and is unmounted long before they matter.
        .environment(breathingState)
        .environment(completions)
        .environment(collectionsFocus)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Lumen")
        // Root ignores the safe area: every page is a full-bleed card by
        // design, and each paints its own edge-to-edge background. Pages that
        // need notch clearance use fixed padding for it (see MemoryView).
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

    // MARK: - Launch sequence

    /// Greeting in, hold it, then the greeting out and the pager in behind it.
    ///
    /// The waits are the focus system's own durations — it arrives on the snappy
    /// band and leaves on the smooth one — read from the same constants the
    /// animations run on, so the schedule can never outrun what it is timing.
    private func startupSequence() async {
        Focus.visible(.greeting)
        guard await Self.pause(Self.greetingRevealDelay) else { return }
        Focus.hide(.greeting)
        Focus.visible(.navigation)
        // Only once both motions have landed: the greeting's recede is the
        // longer of the two, and dropping it mid-flight would cut the fade short.
        guard await Self.pause(UIConstants.Animation.smoothDuration) else { return }
        isGreetingMounted = false
    }

    /// Waits out `seconds`, reporting `false` if the surrounding task was
    /// cancelled — a cancelled reveal must not go on to change state.
    private static func pause(_ seconds: TimeInterval) async -> Bool {
        try? await Task.sleep(for: .seconds(seconds))
        return !Task.isCancelled
    }
}

// MARK: - Focus layers

/// The pager: Lumen's navigation, subdued behind the greeting and handed the
/// screen once it has receded. Mounted from the first frame and never removed,
/// so it is also the layer that must not be redrawn for anyone else's sake.
private struct NavigationLayer: View, Equatable {
    let focus: FocusSystem
    @Binding var collectionsExpanded: Bool

    /// A binding has no identity of its own, so the value behind it stands in:
    /// equal focus *and* an unchanged flag is the only case where this subtree
    /// genuinely has nothing new to show.
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

/// The greeting. Mounted hidden so it can reveal itself, then retired by
/// `ContentView` once it has fully receded.
private struct GreetingLayer: View, Equatable {
    let focus: FocusSystem

    var body: some View {
        GreetingView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .focus(focus)
    }
}

/// The ambient transport: the pill, its volume drag and its source band. Hidden
/// for as long as a breathing session holds the screen.
private struct AmbientLayer: View, Equatable {
    let focus: FocusSystem

    var body: some View {
        AmbientPlayer()
            // Anchored at the pill, not screen center: the scale effect
            // must grow out of the object itself.
            .focus(focus, anchor: .bottom)
    }
}
