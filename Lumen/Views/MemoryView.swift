import SwiftUI

struct MemoryView: View {
    @Environment(CollectionStore.self) private var completions

    var body: some View {

        let log = rows
        return GeometryReader { proxy in
            GlassEffectContainer(spacing: MemoryMetrics.containerSpacing) {
                ZStack {
                    Color.black
                    VStack(spacing: MemoryMetrics.stackGap) {
                        MemoryHeader(count: log.count)
                        MemoryPanel(
                            rows: log,
                            innerPadding: MemoryMetrics.panelPadding,
                            screenRadius: proxy.screenCornerRadius
                        )
                    }
                    .padding(.horizontal, MemoryMetrics.panelInset)

                    .padding(.top, proxy.size.height * MemoryMetrics.titleTopFraction)

                    .padding(.bottom, MemoryMetrics.panelInset)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

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

private struct MemoryRowModel: Identifiable {
    let id: CollectionTask.ID
    let collectionTitle: LocalizedStringResource
    let task: CollectionTask
    let completedAt: Date
}

private struct MemoryPanel: View {
    let rows: [MemoryRowModel]
    let innerPadding: CGFloat

    let screenRadius: CGFloat

    private var cornerRadius: CGFloat {
        MemoryMetrics.panelMinimumCornerRadius(screenRadius: screenRadius)
    }

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

                .clipShape(ConcentricRectangle(corners: .concentric(minimum: .fixed(rowCornerRadius)), isUniform: true))
            }
        }
        .padding(innerPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

        .glassEffect(
            .regular,
            in: ConcentricRectangle(corners: .concentric(minimum: .fixed(cornerRadius)), isUniform: true)
        )

        .debugSurfaceBorder(ConcentricRectangle(corners: .concentric(minimum: .fixed(cornerRadius)), isUniform: true))
        .accessibilityElement(children: .contain)
    }
}

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

        .debugSurfaceBorder()
        .accessibilityElement(children: .combine)
    }
}

private struct MemoryRow: View {
    let row: MemoryRowModel

    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ScaledMetric(relativeTo: .body) private var symbolSize: CGFloat = 36

    var body: some View {
        HStack(spacing: 12) {
            Text(row.task.symbol)
                .font(.system(size: symbolSize))

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

        .glassEffect(
            .regular,
            in: ConcentricRectangle(corners: .concentric(minimum: .fixed(cornerRadius)), isUniform: true)
        )

        .debugSurfaceBorder(ConcentricRectangle(corners: .concentric(minimum: .fixed(cornerRadius)), isUniform: true))
        .transition(rowTransition)

        .accessibilityElement(children: .combine)
    }

    private var rowTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom))
    }
}

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

        .debugSurfaceBorder()
        .accessibilityElement(children: .combine)
    }
}

private enum MemoryMetrics {
    static let containerSpacing: CGFloat = 8
    static let panelInset: CGFloat = 5
    static let panelPadding: CGFloat = 10
    static let stackGap: CGFloat = 12

    static let titleTopFraction: CGFloat = 0.08
    static let rowGap: CGFloat = 10

    static func panelMinimumCornerRadius(screenRadius: CGFloat) -> CGFloat {
        max(0, screenRadius - panelPadding)
    }

    static func rowMinimumCornerRadius(screenRadius: CGFloat) -> CGFloat {
        max(0, screenRadius - panelPadding - panelInset)
    }
}

#Preview("Memory") {
    MemoryView()
        .environment(CollectionStore())
}

#Preview("Memory — kept") {
    MemoryPreviewSeeds()
}

private struct MemoryPreviewSeeds: View {
    @State private var store = CollectionStore()

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
