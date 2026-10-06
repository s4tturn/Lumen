import Foundation
import SwiftUI

// MARK: - Sheet

/// The credits sheet: what each model is called, who made it, and under what.
///
/// A line is laid out as a wrapping row of runs so that each link can be
/// highlighted and tapped on its own. One `Text` per line could not do that: a
/// background follows a view, and the tappable thing here is a handful of words
/// in the middle of a sentence — the whole line as one button, which is what this
/// replaced, is either all a link or none of it.
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

/// One credit line, wrapping across as many rows as its runs need.
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
                            // The capsule is drawn by the label but is not itself
                            // the shape that takes the tap, so the hit area is restated.
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    // VoiceOver already reads the label as the button's name; what it
                    // cannot say is that tapping leaves the app, which is the one thing
                    // that is not obvious from the row.
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

/// Lays runs out left to right, wrapping onto the next row at the edge.
///
/// Exists because the highlight has to sit behind the words it belongs to, and a
/// highlight is a shape: it cannot be a run inside a single `Text`, and wrapping
/// runs of differently-sized views is not something `HStack` does. A `Layout`
/// measures each run at its natural width and breaks where the row runs out,
/// which is what a sentence does.
///
/// The break is between runs, never inside one, so a link's capsule and its label
/// always arrive on the same row.
private struct CreditFlow: Layout {
    /// Gap between runs. Also the gap a wrapped row leaves behind it, so the
    /// paragraph reads as continuous text rather than as a grid.
    var spacing: CGFloat

    /// Everything one measuring pass produces: each run's natural size, the rows
    /// they break into at this width, and each row's height.
    ///
    /// A `Layout` is asked to size and then to place, and both need this. Without
    /// a cache each run is measured once to break the line, again to measure the
    /// row, again to find the intrinsic width, and again to place — four times
    /// the text measurement for one sentence.
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

    /// One greedy left-to-right pass: a run moves down only when it cannot fit
    /// where it stands, which is how text fills. Re-run only when the width or
    /// the subviews change — the cache is what stops this being asked twice for
    /// the same answer.
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

    /// Widest row, for the one case where nothing was proposed: with no width to
    /// break at, the line is as wide as it needs to be.
    private func intrinsicWidth(_ cache: Cache) -> CGFloat {
        cache.rows.indices.reduce(0) { widest, rowIndex in
            let row = cache.rows[rowIndex]
            return max(widest, row.reduce(0) { $0 + cache.sizes[$1].width } + spacing * CGFloat(max(row.count - 1, 0)))
        }
    }
}

// MARK: - Button

/// The credits button at the head of the room tab row. Opens the sheet, and
/// tints white while that sheet is up, so it reads as the control that is
/// currently responsible for what is on screen rather than as an idle one.
///
/// The tint is white and not one of the rooms' colours on purpose: the sheet is
/// not a room, so it does not borrow a room's colour to mark itself. Same
/// `.regular` variant and the same `.interactive()` the room tabs use, so the
/// two kinds of capsule in the row differ only in colour.
struct RoomCreditsButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Whether the credits sheet is presented. Drives the tint, and the
    /// selected trait alongside it, so the button's state is never carried by
    /// colour alone.
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "info")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.primary)
                .frame(minWidth: RoomTabMetrics.minimumHeight, minHeight: RoomTabMetrics.minimumHeight)
        }
        // The untinted branch is the bare `init()` rather than a configured
        // `.regular`, which leaves a closed sheet on exactly the style this
        // button has always had. Only the open state is a configured value.
        .buttonStyle(isActive ? .glass(.regular.tint(.white.opacity(0.25)).interactive()) : .glass)
        // The tint crossfades instead of jumping, so it arrives with the sheet
        // rather than snapping white a frame ahead of it.
        //
        // Scoped to `isActive` and attached here rather than wrapped around the
        // state write: that one write also presents the sheet, and a transaction
        // spanning a presentation would hand the sheet's own detent transition a
        // spring it never asked for. Keyed on the value, so nothing else in this
        // button is animated by it — the press reaction is gesture state, not a
        // change of `isActive`.
        //
        // Reduce Motion keeps the fade and drops the bounce, via the shared gate:
        // a tint is a colour change, which is the kind of feedback that stays.
        .animation(
            UIConstants.Animation.reduceMotionGate(UIConstants.Animation.commit, reduceMotion: reduceMotion),
            value: isActive
        )
        .accessibilityLabel("Credits")
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
        .debugSurfaceBorder()
    }
}

// MARK: - Metrics

/// The credits' dimensions and the one colour they use.
private enum CreditsMetrics {
    /// Between lines.
    static let lineSpacing: CGFloat = 10

    /// Between a run and the next.
    static let runSpacing: CGFloat = 4

    /// Inset of the highlight past its label, all round.
    static let linkPadding: CGFloat = 5

    /// The chip's radius. Interior glyph geometry on a chip that never reaches the
    /// sheet's edge, so it is fixed inside the project's concentric shape family
    /// rather than measured against the sheet.
    static let linkRadius: CGFloat = 5

    /// The highlight's fill. Blue at a fifth of its opacity: enough to read as a
    /// chip against the sheet in either appearance, faint enough that a line of
    /// them does not turn into a wall of colour.
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

// MARK: - Content

/// One run of a credit line: either prose, or a single link.
///
/// A line is a sequence of these rather than one string because the sheet
/// highlights each link individually — the words that go somewhere are tappable,
/// and the words that do not are not.
///
/// Value types with no actor-bound behaviour, so they opt out of the project's
/// default isolation: the sheet parses `CREDITS.md` once, off the main thread
/// during launch, rather than the first time someone opens it.
nonisolated struct CreditSegment: Identifiable, Equatable, Sendable {
    /// Position within the line. Stable across launches, and all `ForEach` needs —
    /// a fresh `UUID` per launch would rebuild the whole sheet on every open.
    let id: Int
    let text: String
    /// `nil` for prose, which is not a target.
    let url: URL?
}

/// One line of `CREDITS.md`, split into the runs the sheet lays out.
nonisolated struct CreditLine: Identifiable, Equatable, Sendable {
    let id: Int
    let segments: [CreditSegment]
}

nonisolated enum Credits {
    static let all: [CreditLine] = load()

    /// Reads and parses the file ahead of the sheet that shows it.
    ///
    /// `all` is lazy and thread-safe, so the one-off read and the per-character
    /// scan happen wherever this is called from — which is a background task, so
    /// opening the credits never pays for the parse.
    static func warmUp() async {
        await Task.detached(priority: .utility) { _ = all }.value
    }

    /// The file, read once and split into lines. A missing or unreadable file
    /// gives an empty credits list rather than a crash: attribution is not worth
    /// refusing to open the app over.
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

    /// Splits one line into its runs. `[label](url)` becomes a link run of its
    /// own, and a bare URL left in the prose becomes one too, so both places the
    /// file writes a link end up tappable rather than one of them being dead
    /// text.
    ///
    /// The bracket pair is scanned rather than matched with a pattern because the
    /// file has a label and a URL that both contain parentheses —
    /// `Julien%20Kleber%20(Juliusprod)` — and a pattern cannot tell that URL's
    /// closing parenthesis from the one that ends the link. Counting depth over
    /// the characters does.
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

            // Past the opening parenthesis to the one that closes it at depth zero.
            var depth = 1
            var end = labelEnd + 2
            while end < characters.count, depth > 0 {
                if characters[end] == "(" { depth += 1 }
                if characters[end] == ")" { depth -= 1 }
                end += 1
            }

            // An unbalanced bracket is prose, not a broken link.
            guard depth == 0 else {
                prose.append(characters[i])
                i += 1
                continue
            }

            // The file wraps some licences in a second pair of brackets —
            // `[[CC-BY](…)]` — and the outer pair is decoration, not part of the
            // label. The scanner took it as the label's first character, so it is
            // trimmed off the front and its closing bracket skipped below.
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

    /// Cuts any bare `http(s)` URL out of a stretch of prose and gives it a run
    /// of its own, so a link the file wrote as plain text is still a link rather
    /// than dead text.
    private static func splitBareURLs(_ prose: String) -> [Run] {
        var runs: [Run] = []
        var plain = ""
        let characters = Array(prose)
        var i = 0

        while i < characters.count {
            // The scheme is what tells a URL apart from ordinary prose. Finding it
            // is only half of it: the link runs from here to the whitespace or
            // bracket that ends it, which is what keeps a URL written inside
            // `(…)` from swallowing the parenthesis.
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

    /// Whether an `http` or `https` URL begins at `index`.
    private static func hasScheme(_ characters: [Character], at index: Int) -> Bool {
        let rest = characters[index...]
        return rest.starts(with: "http://") || rest.starts(with: "https://")
    }

    /// Tidies a run's text for display: drops the `**` the file uses for emphasis,
    /// and any bracket a second pair of them left around a licence label. The
    /// sheet has one treatment for prose, so showing the punctuation and not the
    /// emphasis would be worse than showing neither.
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
