import SwiftUI

extension View {
    /// Keeps a room's rewards in step with the keychain's record of what has been
    /// finished, for as long as the page is up.
    ///
    /// This is the whole of the page's link to persistence.
    /// `CollectionStore` is the keychain — the room reads nothing of its
    /// own, holds no second copy of what is done, and cannot drift from it: the
    /// stage is told the finished set, and the stage is the only thing that decides
    /// what that means for the model.
    func earnRewards(stage: RoomStage) -> some View {
        modifier(RoomEarnedRewards(stage: stage))
    }
}

/// Hands the stage the set of finished tasks, when it changes and when the page
/// first appears.
///
/// The `initial` is what makes a completion outlive the session. `ContentView`
/// reads the keychain before this page first mounts, so everything finished in any
/// earlier run is already in the store by the time the page appears — the set never
/// *changes*, and a change-only handler would therefore leave every reward hidden
/// until some brand-new completion happened to arrive and give it something to
/// react to. Reading the record on appearance is the difference between a room that
/// records what has been done and one that records what has been done since launch.
///
/// `initial` also fires when the page reappears, which is harmless and is worth
/// having: `setEarned` early-outs on an unchanged set, so appearing again costs one
/// comparison, and it is what re-settles the stage when the keychain has been
/// re-read underneath a page that was already up.
private struct RoomEarnedRewards: ViewModifier {
    let stage: RoomStage

    /// The keychain-backed record of finished tasks, and so of which objects the
    /// rooms are currently drawing. Read here and nowhere else.
    @Environment(CollectionStore.self) private var completions

    func body(content: Content) -> some View {
        content.onChange(of: earned, initial: true) { _, earned in
            stage.setEarned(earned)
        }
    }

    /// Every finished task, as the set the stage keeps.
    ///
    /// Derived rather than passed through as the completion list itself, because the
    /// stage only ever asks "is this done" — a set answers that without the ordering
    /// and timestamps the list carries for Memory, and it is `Equatable` so it can
    /// key the change that drives it.
    private var earned: Set<CollectionTask.ID> {
        Set(completions.entries.map(\.id))
    }
}