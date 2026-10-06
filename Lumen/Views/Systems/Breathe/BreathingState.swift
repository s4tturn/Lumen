import Observation

/// Global breathing-session state, owned by ContentView and shared down the
/// tree. Set when the BreatheView hold sequence completes; cleared when the
/// breathing-state exit hold completes. While true, CoreNavigation paging is
/// disabled and the AmbientPlayer is morphed to hidden.
@MainActor
@Observable
final class BreathingState {
    var isBreathing = false
}
