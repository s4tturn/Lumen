import SwiftUI

extension View {

    func earnRewards(stage: RoomStage) -> some View {
        modifier(RoomEarnedRewards(stage: stage))
    }
}

private struct RoomEarnedRewards: ViewModifier {
    let stage: RoomStage

    @Environment(CollectionStore.self) private var completions

    func body(content: Content) -> some View {
        content.onChange(of: earned, initial: true) { _, earned in
            stage.setEarned(earned)
        }
    }

    private var earned: Set<CollectionTask.ID> {
        Set(completions.entries.map(\.id))
    }
}
