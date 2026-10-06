import Foundation
import SwiftUI

struct CreditsSheet: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CreditsMetrics.lineSpacing) {
                Text("Credits")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.bottom, 8)

                ForEach(Credits.all) { line in
                    CreditLineText(line: line) { openURL($0) }
                }
            }
            .padding(.horizontal, CreditsMetrics.horizontalPadding)
            .padding(.top, CreditsMetrics.topPadding)
            .padding(.bottom, CreditsMetrics.bottomPadding)
        }
        .background(
            ConcentricRectangle(corners: .concentric(minimum: .fixed(UIConstants.General.screenCornerRadius)), isUniform: true)
                .fill(.ultraThinMaterial)
                .background(
                    ConcentricRectangle(corners: .concentric(minimum: .fixed(UIConstants.General.screenCornerRadius)), isUniform: true)
                        .fill(.black.opacity(0.2))
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

private struct CreditLineText: View {
    let line: CreditLine
    let open: (URL) -> Void

    var body: some View {
        CreditFlow(spacing: CreditsMetrics.runSpacing) {
            ForEach(line.segments) { segment in
                if let url = segment.url {
                    Button {
                        open(url)
                    } label: {
                        Text(segment.text)
                            .font(.footnote)
                            .foregroundStyle(CreditsMetrics.linkTint)
                            .padding(.horizontal, CreditsMetrics.linkPadding)
                            .padding(.vertical, CreditsMetrics.linkPadding / 2)
                            .background(
                                ConcentricRectangle(corners: .fixed(CreditsMetrics.linkRadius), isUniform: true)
                                    .fill(CreditsMetrics.linkTint.opacity(CreditsMetrics.linkFillOpacity))
                            )

                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)

                    .accessibilityHint(Text(CreditsMetrics.linkHint))
                } else {
                    Text(segment.text)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct CreditFlow: Layout {

    var spacing: CGFloat

    typealias Cache = (width: CGFloat, sizes: [CGSize], rows: [[Int]], heights: [CGFloat])

    func makeCache(subviews: Subviews) -> Cache {
        (width: .infinity, sizes: [], rows: [], heights: [])
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        measure(width: proposal.width ?? .infinity, subviews: subviews, cache: &cache)
        let height = cache.heights.reduce(0, +) + spacing * CGFloat(max(cache.heights.count - 1, 0))
        guard let width = proposal.width else {
            return CGSize(width: intrinsicWidth(cache), height: height)
        }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        measure(width: bounds.width, subviews: subviews, cache: &cache)
        var origin = bounds.minY
        for (rowIndex, row) in cache.rows.enumerated() {
            let height = cache.heights[rowIndex]
            var x = bounds.minX
            for index in row {
                let size = cache.sizes[index]
                subviews[index].place(
                    at: CGPoint(x: x, y: origin + (height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            origin += height + spacing
        }
    }

    private func measure(width: CGFloat, subviews: Subviews, cache: inout Cache) {
        guard cache.width != width || cache.sizes.count != subviews.count else { return }
        cache.sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        cache.rows = []
        cache.heights = []

        var row: [Int] = []
        var height: CGFloat = 0
        var x: CGFloat = 0
        for (index, size) in cache.sizes.enumerated() {
            let advance = row.isEmpty ? size.width : size.width + spacing
            if !row.isEmpty, x + advance > width {
                cache.rows.append(row)
                cache.heights.append(height)
                row = [index]
                height = size.height
                x = size.width
            } else {
                row.append(index)
                height = max(height, size.height)
                x += advance
            }
        }
        if !row.isEmpty {
            cache.rows.append(row)
            cache.heights.append(height)
        }
        cache.width = width
    }

    private func intrinsicWidth(_ cache: Cache) -> CGFloat {
        cache.rows.indices.reduce(0) { widest, rowIndex in
            let row = cache.rows[rowIndex]
            return max(widest, row.reduce(0) { $0 + cache.sizes[$1].width } + spacing * CGFloat(max(row.count - 1, 0)))
        }
    }
}

struct RoomCreditsButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "info")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.primary)
                .frame(minWidth: RoomTabMetrics.minimumHeight, minHeight: RoomTabMetrics.minimumHeight)
        }

        .buttonStyle(isActive ? .glass(.regular.tint(.white.opacity(0.25)).interactive()) : .glass)

        .animation(
            UIConstants.Animation.reduceMotionGate(UIConstants.Animation.commit, reduceMotion: reduceMotion),
            value: isActive
        )
        .accessibilityLabel("Credits")
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
        .debugSurfaceBorder()
    }
}

private enum CreditsMetrics {

    static let lineSpacing: CGFloat = 10

    static let runSpacing: CGFloat = 4

    static let linkPadding: CGFloat = 5

    static let linkRadius: CGFloat = 5

    static let linkFillOpacity: CGFloat = 0.2

    static let linkTint: Color = .blue

    static let horizontalPadding: CGFloat = 16
    static let topPadding: CGFloat = 20
    static let bottomPadding: CGFloat = 40

    static let linkHint = "Opens in Safari"
}

#Preview {
    CreditsSheet()
        .presentationDetents([.fraction(0.8)])
}
import Foundation

nonisolated struct CreditSegment: Identifiable, Equatable, Sendable {

    let id: Int
    let text: String

    let url: URL?
}

nonisolated struct CreditLine: Identifiable, Equatable, Sendable {
    let id: Int
    let segments: [CreditSegment]
}

nonisolated enum Credits {
    static let all: [CreditLine] = load()

    static func warmUp() async {
        await Task.detached(priority: .utility) { _ = all }.value
    }

    private static func load() -> [CreditLine] {
        guard let url = Bundle.main.url(forResource: "CREDITS", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return [] }

        return text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { runs(in: String($0)) }
            .enumerated()
            .compactMap { index, runs in
                let runs = runs.filter { !$0.text.isEmpty }
                return runs.isEmpty ? nil : CreditLine(id: index, segments: runs)
            }
    }

    private static func runs(in line: String) -> [CreditSegment] {
        let characters = Array(line)
        var runs: [Run] = []
        var prose = ""

        func flushProse() {
            runs.append(contentsOf: splitBareURLs(prose))
            prose = ""
        }

        var i = 0
        while i < characters.count {
            guard characters[i] == "[",
                  let labelEnd = characters[i...].firstIndex(of: "]"),
                  labelEnd + 1 < characters.count,
                  characters[labelEnd + 1] == "("
            else {
                prose.append(characters[i])
                i += 1
                continue
            }

            var depth = 1
            var end = labelEnd + 2
            while end < characters.count, depth > 0 {
                if characters[end] == "(" { depth += 1 }
                if characters[end] == ")" { depth -= 1 }
                end += 1
            }

            guard depth == 0 else {
                prose.append(characters[i])
                i += 1
                continue
            }

            flushProse()
            runs.append(Run(
                text: clean(String(characters[(i + 1)..<labelEnd])),
                url: URL(string: String(characters[(labelEnd + 2)..<(end - 1)]))
            ))
            i = characters.indices.contains(end) && characters[end] == "]" ? end + 1 : end
        }
        flushProse()

        return runs.enumerated().map { index, run in
            CreditSegment(id: index, text: run.text, url: run.url)
        }
    }

    private static func splitBareURLs(_ prose: String) -> [Run] {
        var runs: [Run] = []
        var plain = ""
        let characters = Array(prose)
        var i = 0

        while i < characters.count {

            guard hasScheme(characters, at: i) else {
                plain.append(characters[i])
                i += 1
                continue
            }

            var end = i
            while end < characters.count,
                  !characters[end].isWhitespace,
                  characters[end] != ")",
                  characters[end] != "]" {
                end += 1
            }

            if !plain.isEmpty {
                runs.append(Run(text: clean(plain), url: nil))
                plain = ""
            }
            let link = String(characters[i..<end])
            runs.append(Run(text: link, url: URL(string: link)))
            i = end
        }

        runs.append(Run(text: clean(plain), url: nil))
        return runs
    }

    private static func hasScheme(_ characters: [Character], at index: Int) -> Bool {
        let rest = characters[index...]
        return rest.starts(with: "http://") || rest.starts(with: "https://")
    }

    private static func clean(_ text: String) -> String {
        text
            .replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
    }

    private struct Run {
        let text: String
        let url: URL?
    }
}
