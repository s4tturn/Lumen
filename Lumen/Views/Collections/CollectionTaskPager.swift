import SwiftUI

/// One collection's tasks, one at a time, paged by the system.
///
/// The visible task is not local state — it is the app's `CollectionFocus` —
/// because the ambient player's Complete control acts on whatever is on screen
/// here. Two answers to "which task is showing" would eventually disagree, and
/// the disagreeing one files a completion against the wrong task.
///
/// The binding runs both ways: the scroll view writes the page it settled on,
/// and the wheel writes the first task as a card expands. That second write is
/// what opens the pager where the person left off rather than wherever the
/// content happens to lay out.
struct CollectionTaskPager: View {
    let tasks: [CollectionTask]
    @Bindable var focus: CollectionFocus

    var body: some View {
        VStack(spacing: PagerMetrics.pageGap) {
            pages
            // Handed the focus rather than the visible task on purpose: reading
            // `focus.task` in this body would invalidate the whole pager on every
            // page turn, and the only thing that changes is five capsules.
            PagerDots(tasks: tasks, focus: focus)
        }
    }

    /// `containerRelativeFrame` rather than the card's own width: a page fills
    /// exactly what the scroll view can show, so the pager keeps no second copy
    /// of the layout's dimensions to fall out of step with the card it lives in.
    ///
    /// With `.scrollTargetLayout()` and `.paging` that is the entire paging
    /// contract — no page-index arithmetic, no recycled three-view window, no
    /// velocity thresholds to tune, and off-page tasks cost nothing because the
    /// stack is lazy.
    private var pages: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(tasks) { task in
                    CollectionTaskPage(task: task)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $focus.task)
    }
}

// MARK: - Position

/// Where you are in the collection: one capsule per task, the visible one
/// stretched.
///
/// Reads the focus itself rather than being handed a visible task, so a page
/// turn invalidates these few capsules and nothing else — the scroll view and
/// every task page inside it are untouched by which page happens to be showing.
private struct PagerDots: View {
    let tasks: [CollectionTask]
    let focus: CollectionFocus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: PagerMetrics.gap) {
            ForEach(tasks) { task in
                Capsule()
                    .fill(.white)
                    .frame(width: isVisible(task) ? PagerMetrics.activeWidth : PagerMetrics.restWidth,
                           height: PagerMetrics.dotHeight)
                    .opacity(isVisible(task) ? 1 : PagerMetrics.restOpacity)
            }
        }
        .animation(
            UIConstants.Animation.motionGate(UIConstants.Animation.snappySpring, reduceMotion: reduceMotion),
            value: focus.task
        )
        // Position, not content: the tasks themselves are already in the
        // accessibility tree, and a row of anonymous capsules would only be read
        // out as noise between them.
        .accessibilityHidden(true)
        // The tick rides the dots because they are the one view that already
        // changes when the visible page does — the trigger is the page, wherever
        // the gesture happened to end.
        .sensoryFeedback(.selection, trigger: focus.task)
    }

    private func isVisible(_ task: CollectionTask) -> Bool {
        task.id == focus.task
    }
}

// MARK: - Page

/// One task: the pictogram, and the sentence that says what to do.
private struct CollectionTaskPage: View {
    let task: CollectionTask

    /// Emoji carry no point size of their own, so this is where the size lives —
    /// and it scales, because a fixed-size pictogram would be the one part of a
    /// task that ignores the person's text size. 150pt is what it reads at the
    /// default size.
    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize: CGFloat = 150

    var body: some View {
        VStack(spacing: PagerMetrics.pageGap) {
            Text(task.symbol)
                .font(.system(size: symbolSize))
                // The sentence below already says it; announcing a bare
                // "walking man" first would only get in the way.
                .accessibilityHidden(true)

            Text(task.instruction)
                .font(.system(.title2, design: .serif))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
        }
        // Padding first, then the greedy frame: the other way round the padding
        // would sit outside the frame and the page would overflow its own width.
        .padding(.horizontal, PagerMetrics.pageInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // One element rather than two, so VoiceOver reads a task as the single
        // thing it is instead of as a pictogram followed by a sentence. No line
        // limit: at large text sizes the sentence is allowed to run long rather
        // than be cut off mid-thought.
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Metrics

/// Pager dimensions, in one place. Dot and gap sizes are related by
/// multiplication rather than restated, so the rhythm survives a change to any
/// one of them.
private enum PagerMetrics {
    static let dotHeight: CGFloat = 6
    static let restWidth: CGFloat = 6
    static let activeWidth: CGFloat = 20
    /// Unselected capsules recede rather than shrink to nothing: a page mark that
    /// disappears entirely is one fewer cue about how much is left to see.
    static let restOpacity: Double = 0.4
    static let gap: CGFloat = 8
    /// Space between a task's pictogram and its sentence, and between the pages
    /// and the dots. One value so the two never drift into uneven rhythm.
    static let pageGap: CGFloat = dotHeight * 3
    static let pageInset: CGFloat = 24
}
