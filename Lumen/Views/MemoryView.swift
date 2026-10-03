import SwiftUI

/// The log of everything finished: the title above one inset glass panel
/// holding one glass row per completion, newest first.
///
/// Layering (liquid-glass containers-and-sampling): a single
/// `GlassEffectContainer` holds the panel and every row, so all surfaces share
/// one sampling region and render consistently. Its `spacing` sits below the
/// row gap on purpose — rows must never merge into each other — which mirrors
/// the AppKit deliberate-zero rationale of sharing sampling without fusing.
/// The list is bounded by the catalog size (at most one entry per task), so a
/// plain `VStack` carries it: nothing scrolls into view that was not already
/// laid out, and no sampling region is torn down mid-scroll.
///
/// Monochrome by design: black base, white text, secondary details — the only
/// colour on screen is the task pictograms.
struct MemoryView: View {
    @Environment(CollectionCompletionStore.self) private var completions

    var body: some View {
        GeometryReader { proxy in
            GlassEffectContainer(spacing: MemoryMetrics.containerSpacing) {
                ZStack {
                    Color.black
                    VStack(spacing: MemoryMetrics.stackGap) {
                        MemoryHeader(count: rows.count)
                        MemoryPanel(
                            rows: rows,
                            innerPadding: MemoryMetrics.panelPadding,
                            screenRadius: proxy.screenCornerRadius
                        )
                    }
                    .padding(.horizontal, MemoryMetrics.panelInset)
                    // Title clears the notch / Dynamic Island by proportion of
                    // the screen, not a fixed constant, so it holds on every
                    // device size. The root ignores the safe area, so no
                    // safe-area API reports a real inset in this tree.
                    .padding(.top, proxy.size.height * MemoryMetrics.titleTopFraction)
                    // Bottom is a flat inset.
                    .padding(.bottom, MemoryMetrics.panelInset)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // No manual container: the system screen container that
                // CoreNavigation reads `concentricCornerRadii` against is the
                // container here too, so the `ConcentricRectangle` panel below
                // resolves its radii against the true display curve with no
                // hardcoded radius and no measured global.
            }
        }
    }

    /// The store's entries, newest first, resolved against the catalog.
    /// Identities the catalog no longer holds are dropped rather than trapped:
    /// they stay in the keychain and reappear if the content ever returns, but
    /// a renamed task can never break the log. Bounded by the catalog, so the
    /// compactMap is trivially cheap and stays inline.
    private var rows: [MemoryRowModel] {
        completions.entries.compactMap { entry in
            guard let (collection, task) = CollectionCatalog.entry(for: entry.id) else { return nil }
            return MemoryRowModel(
                id: entry.id,
                collectionTitle: collection.title,
                task: task,
                completedAt: entry.completedAt
            )
        }
    }
}

// MARK: - Row identity

/// One log line. Identity is the task's own stable id — the store holds one
/// entry per task — so paging, refreshes and undo all diff as updates to the
/// same row rather than replacements (swiftui-specialist foreach).
private struct MemoryRowModel: Identifiable {
    let id: CollectionTask.ID
    let collectionTitle: LocalizedStringResource
    let task: CollectionTask
    let completedAt: Date
}

// MARK: - Panel

/// The overarching inset rectangle: the rows scrolling inside one `.regular`
/// surface. Regular because the panel carries text and must stay legible over
/// whatever scrolls behind it (HIG liquid-glass: regular for text-heavy
/// surfaces). Inert, so no `interactive()`.
private struct MemoryPanel: View {
    let rows: [MemoryRowModel]
    let innerPadding: CGFloat
    /// The screen's own radius, read once by `MemoryView` and handed down whole.
    /// Both floors below are derived from it, so the panel and its rows can never
    /// disagree about what the screen's curve is.
    let screenRadius: CGFloat

    /// Floor under the panel's own concentric radius.
    private var cornerRadius: CGFloat {
        MemoryMetrics.panelMinimumCornerRadius(screenRadius: screenRadius)
    }

    /// Floor under each row's, handed on so the rows nest inside this panel's
    /// curve rather than re-deciding their own.
    private var rowCornerRadius: CGFloat {
        MemoryMetrics.rowMinimumCornerRadius(screenRadius: screenRadius)
    }

    var body: some View {
        Group {
            if rows.isEmpty {
                MemoryEmptyState()
            } else {
                ScrollView {
                    VStack(spacing: MemoryMetrics.rowGap) {
                        ForEach(rows) { row in
                            MemoryRow(row: row, cornerRadius: rowCornerRadius)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
                // Rows must never paint past the panel's rounded corners while
                // scrolling: clip the scroll region to the same inner curve
                // the rows themselves use — same floor, so the two cannot
                // disagree at the corner.
                .clipShape(ConcentricRectangle(corners: .concentric(minimum: .fixed(rowCornerRadius)), isUniform: true))
            }
        }
        .padding(innerPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Concentric to the system screen container: insets resolve the radii
        // automatically against the display curve, floored so the panel still
        // curves where the screen's curve never reaches it.
        .glassEffect(
            .regular,
            in: ConcentricRectangle(corners: .concentric(minimum: .fixed(cornerRadius)), isUniform: true)
        )
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Header

private struct MemoryHeader: View {
    let count: Int

    var body: some View {
        VStack(spacing: 4) {
            Text("Memory", comment: "Memory page title — the log of completed tasks.")
                .font(.system(.largeTitle, design: .serif))
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
            Text(
                "^[\(count) moment](inflect: true) kept",
                comment: "Subtitle under the Memory title — the value is the number of completed tasks."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Row

/// One completion: the collection (the object), the task, and when it was
/// finished. A single-root `HStack` keeps the row unary so `ForEach` ids
/// template from the element alone (swiftui-specialist foreach). Dates use
/// `Text(_:format:)` — cached and locale-aware, never a hardcoded formatter
/// (swiftui-specialist localization).
private struct MemoryRow: View {
    let row: MemoryRowModel
    /// Floor under this row's concentric radius. Read in `MemoryMetrics` from the
    /// screen radius less the panel's own insets, so a row still curves even
    /// where the screen's curve never reaches it.
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Emoji carry no point size of their own, so the size lives here and
    /// scales with Dynamic Type (CollectionTaskPage precedent).
    @ScaledMetric(relativeTo: .body) private var symbolSize: CGFloat = 36

    var body: some View {
        HStack(spacing: 12) {
            Text(row.task.symbol)
                .font(.system(size: symbolSize))
                // The task title below already says it; announcing a bare
                // pictogram first would only get in the way.
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.collectionTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(row.task.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(row.completedAt, format: .dateTime.day().month())
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Text(row.completedAt, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Concentric to the system screen container like the panel above, with a
        // floor at the panel's own inset: the rows nearest the screen's corners
        // resolve the true concentric radius, and rows further in — where that
        // radius reaches zero — keep the same curvature instead of squaring off.
        .glassEffect(
            .regular,
            in: ConcentricRectangle(corners: .concentric(minimum: .fixed(cornerRadius)), isUniform: true)
        )
        .transition(rowTransition)
        // One element rather than four, so VoiceOver reads a completion as the
        // single thing it is instead of as fragments.
        .accessibilityElement(children: .combine)
    }

    /// Insertions ride the tap's own `withAnimation` from the complete
    /// control; the transition here only describes the arrival. Reduce Motion
    /// gets the crossfade, everyone else a rise (liquid-glass-motion
    /// reduce-motion: substitute, never remove).
    private var rowTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom))
    }
}

// MARK: - Empty state

/// No completions yet. Names the next action rather than the absence
/// (HIG writing: empty screens invite what comes next).
private struct MemoryEmptyState: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Nothing kept yet", comment: "Memory empty-state title — no tasks completed yet.")
                .font(.system(.title2, design: .serif))
                .foregroundStyle(.white)
            Text(
                "Complete a task and it will live here.",
                comment: "Memory empty-state invitation to complete a first task."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Metrics

/// Memory dimensions, in one place. The container spacing is deliberately the
/// smallest number here: it must stay below the row gap so neighbouring rows
/// share a sampling region without ever fusing into each other.
private enum MemoryMetrics {
    static let containerSpacing: CGFloat = 8
    static let panelInset: CGFloat = 5
    static let panelPadding: CGFloat = 10
    static let stackGap: CGFloat = 12
    /// Title clearance as a fraction of screen height, mirroring how the
    /// collection name pads by `size.height` proportion in CollectionsView.
    static let titleTopFraction: CGFloat = 0.08
    static let rowGap: CGFloat = 10

    /// The floor under the panel's own concentric radius: the screen's radius
    /// less the panel's inner padding — the one inset that lies between the
    /// panel's edges and the rows inside it. The rows then step down from here by
    /// the panel's outer inset, so panel and rows nest one step apart.
    ///
    /// Clamped at zero for the same reason as the row floor below.
    static func panelMinimumCornerRadius(screenRadius: CGFloat) -> CGFloat {
        max(0, screenRadius - panelPadding)
    }

    /// The floor under each row's concentric radius: the screen's own radius
    /// less exactly the distance a row sits from the screen's edge — the
    /// panel's inset, then the panel's inner padding. A row at the screen's
    /// corner would resolve that radius on its own; this is the same number,
    /// handed to rows further in so the curvature never drops away mid-list.
    ///
    /// Clamped at zero because `screenCornerRadius` is zero when SwiftUI
    /// resolves no container shape, and a negative minimum is not a corner style.
    static func rowMinimumCornerRadius(screenRadius: CGFloat) -> CGFloat {
        max(0, screenRadius - panelPadding - panelInset)
    }
}

// MARK: - Preview

#Preview("Memory") {
    MemoryView()
        .environment(CollectionCompletionStore())
}

#Preview("Memory — kept") {
    MemoryPreviewSeeds()
}

private struct MemoryPreviewSeeds: View {
    @State private var store = CollectionCompletionStore()

    var body: some View {
        MemoryView()
            .environment(store)
            .task {
                for raw in ["self.walk", "space.bed", "kitchen.drink", "joy.music", "connection.call", "growth.reading"] {
                    store.complete(CollectionTask.ID(raw))
                }
            }
    }
}
