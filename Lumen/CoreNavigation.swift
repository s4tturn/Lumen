import Observation
import SwiftUI

/// Pages in Lumen's cross-shaped map: Home at the center, one neighbor per edge.
enum LumenPage: Int, CaseIterable, Identifiable, Sendable, Equatable {
    case memory, home, breathe, collections

    var id: Int { rawValue }

    var column: Int {
        switch self {
        case .memory: 0
        case .home, .collections: 1
        case .breathe: 2
        }
    }

    var row: Int { self == .collections ? 1 : 0 }

    init?(column: Int, row: Int) {
        switch (column, row) {
        case (0, 0): self = .memory
        case (1, 0): self = .home
        case (2, 0): self = .breathe
        case (1, 1): self = .collections
        default: return nil
        }
    }

    var title: String {
        switch self {
        case .memory: "Memory"
        case .home: "Home"
        case .breathe: "Breathe"
        case .collections: "Collections"
        }
    }
}

/// Viewport-derived paging metrics. A value type: cheap, testable, never stale-observed.
struct PagingMetrics: Equatable {
    let pageSize: CGSize
    let stepX: CGFloat
    let stepY: CGFloat

    private static let pageSpacing: CGFloat = 20

    init(pageSize: CGSize) {
        self.pageSize = pageSize
        stepX = pageSize.width + Self.pageSpacing
        stepY = pageSize.height + Self.pageSpacing
    }

    // MARK: - Rubber banding (pure math; called from dragChanged, kept off the
    // @MainActor controller's observed state path beyond the single dragOffset)

    private static let rubberBandCoefficient: CGFloat = 0.55

    func validRanges(from page: LumenPage)
        -> (x: ClosedRange<CGFloat>, y: ClosedRange<CGFloat>)
    {
        let x: ClosedRange<CGFloat>
        switch page {
        case .memory: x = -stepX ... 0
        case .home: x = -stepX ... stepX
        case .breathe: x = 0 ... stepX
        case .collections: x = 0 ... 0
        }
        let y: ClosedRange<CGFloat>
        switch page {
        case .home: y = -stepY ... 0
        case .collections: y = 0 ... stepY
        case .memory, .breathe: y = 0 ... 0
        }
        return (x, y)
    }

    func rubberbanded(_ translation: CGSize, from page: LumenPage) -> CGSize {
        let ranges = validRanges(from: page)
        return CGSize(
            width: rubberBandedComponent(translation.width, range: ranges.x, dimension: pageSize.width),
            height: rubberBandedComponent(translation.height, range: ranges.y, dimension: pageSize.height)
        )
    }

    private func rubberBandedComponent(_ raw: CGFloat, range: ClosedRange<CGFloat>, dimension: CGFloat) -> CGFloat {
        if raw < range.lowerBound { return range.lowerBound + rubberBand(raw - range.lowerBound, dimension: dimension) }
        if raw > range.upperBound { return range.upperBound + rubberBand(raw - range.upperBound, dimension: dimension) }
        return raw
    }

    private func rubberBand(_ distance: CGFloat, dimension: CGFloat) -> CGFloat {
        guard dimension > 0 else { return 0 }
        let sign: CGFloat = distance > 0 ? 1 : -1
        return sign * (1 - 1 / ((abs(distance) * Self.rubberBandCoefficient / dimension) + 1)) * dimension
    }
}

/// Owns the settled page plus the single live drag vector. Live drag never
/// reaches page bodies: only the container offset reads it (see
/// `CoreNavigation.body`), so per-sample updates rebuild identical child
/// values — skipped via `.equatable()` — instead of re-rendering heavyweight
/// content at gesture frequency.
///
/// Gesture contract (apple-motion-feel + HIG "handle gestures as responsively
/// as possible"): track 1:1 with no animation while the finger is down — the
/// user is the animation (Apple reserves `interactiveSpring` for driven
/// animations, not finger tracking); decide the target from
/// `predictedEndTranslation` (velocity projection, not raw distance); settle
/// with a named preset — `.smooth` for a cancelled drag, zero-bounce
/// `pageArrival` for a committed turn (paging is arrival: no overshoot).
/// See https://sosumi.ai/documentation/swiftui/draggesture/value/predictedendtranslation
/// https://sosumi.ai/documentation/swiftui/animation/interactivespring(response:dampingfraction:blendduration:)
/// https://sosumi.ai/design/human-interface-guidelines/gestures
@MainActor
@Observable
final class NavigationController {
    var currentPage: LumenPage = .home
    /// Live drag. Read ONLY by the container offset — never by page bodies —
    /// so per-sample updates rebuild identical child values (skipped via
    /// `.equatable()`) instead of re-rendering content at gesture frequency.
    var dragOffset: CGSize = .zero
    /// Bumped on every release commit — page turn or cancelled return — so
    /// the view-side settle task restarts and the haptic lands with the
    /// pixels, never at finger lift.
    var settleNonce = 0

    func dragChanged(_ translation: CGSize, from page: LumenPage, metrics: PagingMetrics) {
        // 1:1, deliberately unanimated — the user is the animation.
        dragOffset = metrics.rubberbanded(translation, from: page)
    }

    func dragEnded(
        _ value: DragGesture.Value,
        from page: LumenPage,
        metrics: PagingMetrics,
        reduceMotion: Bool
    ) {
        let predicted = clamped(value.predictedEndTranslation, from: page, metrics: metrics)
        let target = targetPage(from: page, predicted: predicted, metrics: metrics)
        go(to: target, reduceMotion: reduceMotion)
    }

    /// Programmatic move (accessibility, deep links). Same presets as gestures.
    func go(to target: LumenPage, reduceMotion: Bool) {
        let animation = reduceMotion
            ? UIConstants.Animation.motionReduced
            : UIConstants.Animation.smoothSpring
        settleNonce += 1
        // dragOffset returns inside the same animation: a rubber-banded
        // release glides home instead of teleporting (@GestureState reset
        // cannot animate — that one-frame snap was the jank).
        withAnimation(animation) {
            currentPage = target
            dragOffset = .zero
        }
    }

    // MARK: - Physics

    private func clamped(_ translation: CGSize, from page: LumenPage, metrics: PagingMetrics) -> CGSize {
        let ranges = metrics.validRanges(from: page)
        return CGSize(
            width: min(max(translation.width, ranges.x.lowerBound), ranges.x.upperBound),
            height: min(max(translation.height, ranges.y.lowerBound), ranges.y.upperBound)
        )
    }

    private func targetPage(from page: LumenPage, predicted: CGSize, metrics: PagingMetrics) -> LumenPage {
        let thresholdX = metrics.stepX * 0.25
        let thresholdY = metrics.stepY * 0.25
        let newCol = abs(predicted.width) > thresholdX
            ? page.column + (predicted.width < 0 ? 1 : -1) : page.column
        let newRow = abs(predicted.height) > thresholdY
            ? page.row + (predicted.height < 0 ? 1 : -1) : page.row

        if let direct = LumenPage(column: newCol, row: newRow) { return direct }
        // Diagonal into empty space: fall back along the dominant axis.
        let horizontalFirst = abs(predicted.width) >= abs(predicted.height)
        let first = horizontalFirst
            ? LumenPage(column: newCol, row: page.row)
            : LumenPage(column: page.column, row: newRow)
        let second = horizontalFirst
            ? LumenPage(column: page.column, row: newRow)
            : LumenPage(column: newCol, row: page.row)
        return first ?? second ?? page
    }
}

/// Full-screen pager. Each page is viewport-sized and offset into place — one
/// transform per page, no oversized content frame, no centering drift.
///
/// HIG notes: paging tracks the finger and settles with velocity projection
/// (Gestures, Scroll views); VoiceOver moves via adjustable action because
/// drag is not an assumption (Gestures, VoiceOver); offscreen pages leave the
/// accessibility tree and hit testing so they can't trap focus or touches.
struct CoreNavigation: View {
    @Binding private var collectionsExpanded: Bool
    @Environment(BreathingState.self) private var breathing
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var controller = NavigationController()
    /// Haptic tick, bumped once the settle animation has landed — on every
    /// release, including a cancelled drag that returns to the origin page.
    @State private var settleHapticTick = 0

    init(collectionsExpanded: Binding<Bool> = .constant(false)) {
        _collectionsExpanded = collectionsExpanded
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = PagingMetrics(pageSize: proxy.size)
            let current = controller.currentPage

            // Per-page offsets are settle-stable (no drag term): during a drag
            // every page holds its settled appearance and the whole stack slides
            // as rigid bitmaps via the single container offset. Recede no longer
            // tracks the finger — it crossfades on settle instead. That is the
            // fix for collections trailing the frame ~20-30px on device: the old
            // per-page drag term re-invalidated a dozen materials, gradients and
            // carousels every touch sample, so the cheap transform committed
            // while the content subtree was still re-rendering the last sample.
            ZStack {
                ForEach(LumenPage.allCases) { page in
                    PageView(
                        page: page,
                        size: metrics.pageSize,
                        offset: CGSize(
                            width: CGFloat(page.column - current.column) * metrics.stepX,
                            height: CGFloat(page.row - current.row) * metrics.stepY
                        ),
                        metrics: metrics,
                        isCurrent: page == current,
                        reduceMotion: reduceMotion,
                        collectionsExpanded: $collectionsExpanded
                    )
                    // Guarantee the skip: identical inputs must not re-run this
                    // body at gesture frequency (swiftui-pro performance). The
                    // parent body re-runs per drag sample; without this, the
                    // materials/carousel subtree re-evaluates per sample and
                    // main-thread saturation makes delivery steppy.
                    .equatable()
                }
            }
            .frame(width: metrics.pageSize.width, height: metrics.pageSize.height)
            // The ONLY live-drag reader: one cheap transform node. Page bodies
            // are out of this path (see above + `.equatable()` below).
            .offset(controller.dragOffset)
            .clipped()
            .contentShape(Rectangle())
            .gesture(pagingGesture(metrics: metrics), isEnabled: !collectionsExpanded && !breathing.isBreathing)
        }
        .onChange(of: breathing.isBreathing) { _, isBreathing in
            // A breathing session owns the screen: land on the breathe page
            // (the hold can only start there, so this is a no-op in practice)
            // and keep gestures off until the session clears.
            if isBreathing, controller.currentPage != .breathe {
                controller.go(to: .breathe, reduceMotion: reduceMotion)
            }
        }
        .sensoryFeedback(.selection, trigger: settleHapticTick)
        .task(id: controller.settleNonce) { [nonce = controller.settleNonce, reduceMotion] in
            // Fire only once the settle animation has landed: the task starts
            // at release and auto-cancels if a new turn interrupts it, so a
            // skipped-over page never clicks. Nonce 0 is first appear: silent.
            // (Values are bound in the capture list so the @Sendable task
            // never captures the non-Sendable controller.)
            guard nonce != 0 else { return }
            let delay = (reduceMotion
                ? UIConstants.Animation.reducedDuration
                : UIConstants.Animation.smoothDuration) + 0.05
            try? await Task.sleep(nanoseconds: UInt64(max(0, delay) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            settleHapticTick += 1
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pages")
        .accessibilityValue("\(controller.currentPage.title), \(controller.currentPage.rawValue + 1) of \(LumenPage.allCases.count)")
        .accessibilityHint("Swipe up or down to move between pages")
        .accessibilityAdjustableAction { direction in
            step(direction == .increment ? 1 : -1)
        }
    }

    private func step(_ direction: Int) {
        guard !breathing.isBreathing else { return }
        let order = LumenPage.allCases
        guard let index = order.firstIndex(of: controller.currentPage) else { return }
        let next = order[(index + direction + order.count) % order.count]
        controller.go(to: next, reduceMotion: reduceMotion)
    }

    /// Claim threshold: 8pt (base-4 grid) is the compromise between HIG
    /// "handle gestures as responsively as possible" and letting taps,
    /// long-presses, and inner drags (disk `minimumDistance:0`, carousel/dismiss
    /// `12`) win when they start inside a page. 12pt felt sticky on slow drags;
    /// 0pt starves inner gestures because the outer pager claims first.
    /// `coordinateSpace: .local` keeps translation in the viewport's own points.
    /// Tracking writes `dragOffset` 1:1 (container transform only — never into
    /// page bodies); target selection stays velocity-projected in `dragEnded`.
    /// Disabling via `isEnabled` blocks new gestures; an in-flight drag simply
    /// stops receiving events and the animated return still runs in `go(to:)`.
    /// See https://sosumi.ai/documentation/swiftui/draggesture/minimumdistance
    /// https://sosumi.ai/design/human-interface-guidelines/gestures
    /// https://sosumi.ai/documentation/swiftui/composing-swiftui-gestures
    private func pagingGesture(metrics: PagingMetrics) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                controller.dragChanged(value.translation, from: controller.currentPage, metrics: metrics)
            }
            .onEnded { value in
                controller.dragEnded(value, from: controller.currentPage, metrics: metrics, reduceMotion: reduceMotion)
            }
    }
}

/// One viewport-sized page. Off-center pages recede via `subduedBlur` +
/// `subduedDim`, driven by swipe progress. Deliberately no scale: it is the
/// only recede channel that moves pixels, and its completion at landing reads
/// as a positional shift on every page (see below).
///
/// The inputs here are settle-stable: `offset` carries no drag term (live drag
/// is a container transform, see `CoreNavigation.body`), so progress — and
/// therefore blur radius — is constant for the whole drag. Static blur renders
/// once and slides as a cached layer; no per-sample re-render, no touch-down
/// pop, so no `isDragging` gate is needed. Reduce Motion keeps the opacity dim
/// as its substitute and drops blur.
///
/// Modifier order is load-bearing: the page is clipped first so `blur` and
/// `opacity` operate on the clipped card (not the internal rectangle), then
/// clipped again with the identical shape so the blur's softened edge is cut
/// back to a crisp card boundary. `compositingGroup` unifies the clipped page
/// into one layer for the blur. Deliberately NO `geometryGroup` here: the barrier
/// forces inner `.position()` values to be resolved/animated by the parent on
/// top of the outer offset spring, so grouped content diverges from the frame
/// mid-settle and only converges at landing — the uniform shift seen on device
/// on every page. Static inner positions pass through untouched instead.
/// See https://sosumi.ai/documentation/swiftui/view/geometrygroup()
/// https://sosumi.ai/documentation/swiftui/view/compositinggroup()
/// https://sosumi.ai/documentation/swiftui/view/blur(radius:opaque:)
/// https://sosumi.ai/documentation/xcode/understanding-and-improving-swiftui-performance
private struct PageView: View, Equatable {
    let page: LumenPage
    let size: CGSize
    let offset: CGSize
    let metrics: PagingMetrics
    let isCurrent: Bool
    let reduceMotion: Bool
    @Binding var collectionsExpanded: Bool

    // @Binding blocks synthesized Equatable; compare underlying values.
    static func == (lhs: PageView, rhs: PageView) -> Bool {
        lhs.page == rhs.page
            && lhs.size == rhs.size
            && lhs.offset == rhs.offset
            && lhs.metrics == rhs.metrics
            && lhs.isCurrent == rhs.isCurrent
            && lhs.reduceMotion == rhs.reduceMotion
            && lhs.collectionsExpanded == rhs.collectionsExpanded
    }

    var body: some View {
        let progress = min(
            hypot(offset.width / metrics.stepX, offset.height / metrics.stepY),
            1
        )
        let blurRadius: CGFloat = reduceMotion ? 0 : FocusSystem.Constant.subduedBlur * progress
        // No scale recede on ANY page: scale is the only recede channel that
        // moves pixels (blur/opacity cannot translate), and its 0.95→1.0
        // completion at landing reads as a positional shift — downward on
        // collections (bottom-glued disk) and Home alike, confirmed on device
        // across pages. Anchoring or exempting per page just moves the symptom
        // (center dropped the disk; bottom lifted everything above it), so the
        // fix lives here globally: pages recede via dim + blur only, and land
        // with zero relative motion by construction. Scale == 1 keeps the
        // settled look pixel-identical on every page.
        content
            .frame(width: size.width, height: size.height)
            .clipShape(.rect(cornerRadius: UIConstants.General.screenCornerRadius))
            .compositingGroup()
            .blur(radius: blurRadius)
            .opacity(1 - (1 - FocusSystem.Constant.subduedDim) * Double(progress))
            .clipShape(.rect(cornerRadius: UIConstants.General.screenCornerRadius))
            .offset(offset)
            .allowsHitTesting(isCurrent)
            .accessibilityHidden(!isCurrent)
            .accessibilityLabel(page.title)
            .accessibilityAddTraits(isCurrent ? [.isSelected] : [])
    }

    @ViewBuilder
    private var content: some View {
        switch page {
        case .memory: MemoryView()
        case .home: HomeView()
        case .breathe: BreatheView()
        case .collections: CollectionsView(collectionsExpanded: $collectionsExpanded, pageSize: size)
        }
    }
}
