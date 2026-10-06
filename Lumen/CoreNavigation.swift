import Foundation
import Observation
import SwiftUI

// MARK: - The map

/// Lumen's pages: a cross with Home at the centre and one neighbour per edge.
/// `column`/`row` are the whole geometry of the map — every offset, range and
/// reachability question in the pager is answered by them.
enum LumenPage: Int, CaseIterable, Identifiable, Sendable, Equatable {
    case memory, home, breathe, collections, room

    /// Every page, in the order VoiceOver walks them. `rawValue` follows the same
    /// order, so a page's position in that walk is `rawValue + 1`.
    static let pages: [LumenPage] = allCases

    var id: Int { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .memory: "Memory"
        case .home: "Home"
        case .breathe: "Breathe"
        case .collections: "Collections"
        case .room: "Room"
        }
    }

    var column: Int {
        switch self {
        case .memory: 0
        case .home, .collections, .room: 1
        case .breathe: 2
        }
    }

    var row: Int {
        switch self {
        case .room: -1
        case .collections: 1
        default: 0
        }
    }

    init?(column: Int, row: Int) {
        switch (column, row) {
        case (0, 0): self = .memory
        case (1, 0): self = .home
        case (2, 0): self = .breathe
        case (1, 1): self = .collections
        case (1, -1): self = .room
        default: return nil
        }
    }

    /// Whether the page one step away in this direction exists. The cross has
    /// no diagonals, so this single question is the whole of its adjacency —
    /// the drag limits below are read straight off it instead of restating the
    /// map in a second switch.
    func hasNeighbor(columnOffset: Int = 0, rowOffset: Int = 0) -> Bool {
        LumenPage(column: column + columnOffset, row: row + rowOffset) != nil
    }
}

// MARK: - Paging geometry

/// Viewport-derived paging metrics. A value type: cheap, testable, never
/// stale-observed, and safe to rebuild from the viewport whenever it is needed.
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

    /// Where a page sits relative to the page the pager is settled on. Pure
    /// settled geometry: it carries no drag term, so it changes only when a turn
    /// is committed — never while the finger is down.
    func offset(of page: LumenPage, relativeTo origin: LumenPage) -> CGSize {
        CGSize(
            width: CGFloat(page.column - origin.column) * stepX,
            height: CGFloat(page.row - origin.row) * stepY
        )
    }

    // MARK: - Rubber banding (pure math; called from `dragChanged`, kept off the
    // @MainActor controller's observed state path beyond the single `dragOffset`)

    /// How far a drag may travel from `page` on each axis: one step for every
    /// neighbour that exists, nothing past the edge of the map.
    func validRanges(from page: LumenPage)
        -> (x: ClosedRange<CGFloat>, y: ClosedRange<CGFloat>)
    {
        (
            axisRange(
                stepX,
                backward: page.hasNeighbor(columnOffset: -1),
                forward: page.hasNeighbor(columnOffset: 1)
            ),
            axisRange(
                stepY,
                backward: page.hasNeighbor(rowOffset: -1),
                forward: page.hasNeighbor(rowOffset: 1)
            )
        )
    }

    /// The sign is the whole subtlety, so it is spelled out rather than left to
    /// the reader: a neighbour one step *forward* is drawn at `+step`, so the
    /// drag that brings it to centre goes *back* by `-step`. Forward neighbours
    /// therefore buy travel on the negative side of the range and backward
    /// neighbours on the positive side — the drag always opposes the neighbour's
    /// offset, because the stack travels with the finger.
    private func axisRange(_ step: CGFloat, backward: Bool, forward: Bool) -> ClosedRange<CGFloat> {
        switch (backward, forward) {
        case (false, false): 0 ... 0
        case (true, false): 0 ... step
        case (false, true): -step ... 0
        case (true, true): -step ... step
        }
    }

    /// The drag's resting bounds: beyond them the drag only moves under
    /// resistance.
    func clamped(_ translation: CGSize, from page: LumenPage) -> CGSize {
        let ranges = validRanges(from: page)
        return CGSize(
            width: min(max(translation.width, ranges.x.lowerBound), ranges.x.upperBound),
            height: min(max(translation.height, ranges.y.lowerBound), ranges.y.upperBound)
        )
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

    private static let rubberBandCoefficient: CGFloat = 0.55
}

// MARK: - Pager state

/// The pager's state: the settled page, the single live drag vector, the
/// neighbour a drag is headed toward, and the haptic tick that lands with a settle.
///
/// The animated values have exactly one reader each, and that is what keeps
/// the pager cheap:
///
/// - `dragOffset` is read only by `DragSurface`, the leaf that applies the
///   container transform. A drag sample re-runs one three-line body instead of
///   re-diffing five pages of materials, gradients and carousels.
/// - `currentPage` and `dragTarget` are read only by `Pager`, which rebuilds
///   the page stack once per committed turn plus at most once more per drag
///   when the headed-toward neighbour changes.
///
/// Nothing else observes them, so a drag never reaches a page body. Live drag
/// tracks through `UIConstants.Animation.dragTrack(speed:)`, a persistent
/// spring whose response adapts to gesture speed: hand tremor is filtered out
/// of a slow drag, a flick stays crisp, and SwiftUI carries the presented
/// velocity from sample to sample without any of it being tracked here.
/// Every settle — a committed turn, a cancelled drag, a programmatic move —
/// runs on the same named preset: `.smooth`, critically damped, because paging
/// is arrival and does not overshoot. That preset is persistent too, so a
/// release picks up the drag's velocity instead of restarting from rest.
/// See https://sosumi.ai/documentation/swiftui/draggesture/value/predictedendtranslation
/// https://sosumi.ai/documentation/swiftui/animation/spring(response:dampingfraction:blendduration:)
/// https://sosumi.ai/design/human-interface-guidelines/gestures
@MainActor
@Observable
final class NavigationController {
    private(set) var currentPage: LumenPage = .home

    /// The live drag in rubber-banded points. Read by `DragSurface` and by
    /// nothing else in the pager.
    private(set) var dragOffset: CGSize = .zero

    /// The neighbour the current drag is headed toward, if any. Written in
    /// `dragChanged` only when it actually changes (at most ~1 write per drag),
    /// so `Pager` rebuilds at most twice per turn to flip pages live. Cleared in
    /// `go(to:)` when the turn commits. Lets off-current pages freeze their
    /// frame drivers while untouched, then resume a touch ahead of becoming
    /// visible.
    private(set) var dragTarget: LumenPage?

    /// Bumped once a settle animation has landed, so the haptic rides the pixels
    /// rather than a timer running beside them.
    private(set) var settleHapticTick = 0

    /// Identifies the settle whose completion is allowed to fire the haptic: a
    /// turn superseded before it lands never clicks.
    @ObservationIgnored private var settleToken = 0

    func dragChanged(_ translation: CGSize, velocity: CGSize, from page: LumenPage, metrics: PagingMetrics) {
        // Direction only, and read off the raw translation: this is about which
        // way the finger is going, not how far the stack has travelled, so the
        // tracking filter must not delay a page going live. Leading the
        // presented offset is the point — the page is already running its
        // frame drivers by the time the spring brings it into view.
        let next = Self.neighborTarget(from: page, translation: translation)
        if next != dragTarget {
            dragTarget = next
        }
        // One write per touch event, retargeting a persistent spring. The
        // spring filters tremor out of a slow drag without adding lag to a
        // flick, and carries its own velocity forward so neither this nor the
        // release in `go(to:)` ever restarts from a standstill.
        withAnimation(UIConstants.Animation.dragTrack(speed: hypot(velocity.width, velocity.height))) {
            dragOffset = metrics.rubberbanded(translation, from: page)
        }
    }

    func dragEnded(
        _ value: DragGesture.Value,
        from page: LumenPage,
        metrics: PagingMetrics,
        reduceMotion: Bool
    ) {
        // Decide from the projected resting point, not the raw distance: the
        // target is where a flick was actually going.
        let predicted = metrics.clamped(value.predictedEndTranslation, from: page)
        go(to: targetPage(from: page, predicted: predicted, metrics: metrics), reduceMotion: reduceMotion)
    }

    /// Programmatic move (VoiceOver, a breathing session). Same presets as
    /// gestures, and the same haptic.
    func go(to target: LumenPage, reduceMotion: Bool) {
        settleToken &+= 1
        let token = settleToken
        withAnimation(
            UIConstants.Animation.reduceMotionGate(UIConstants.Animation.dwell, reduceMotion: reduceMotion),
            completionCriteria: .logicallyComplete
        ) {
            // `dragOffset` returns inside the same animation: a rubber-banded
            // release glides home instead of teleporting. (@GestureState reset
            // cannot animate — that one-frame snap was the jank.)
            currentPage = target
            dragOffset = .zero
            dragTarget = nil
        } completion: { [self] in
            // Fires when the pixels land, so a skipped-over or interrupted turn
            // never clicks.
            guard token == self.settleToken else { return }
            self.settleHapticTick &+= 1
        }
    }

    // MARK: - Physics

    /// The neighbour a drag is headed toward, from direction alone. A neighbour
    /// one step forward sits at `+step`, so the drag that reveals it goes back
    /// by `-step`: the drag always opposes the neighbour's offset. Dominant
    /// axis wins; the other axis is the fallback when the dominant side has no
    /// neighbour. Threshold matches the pager's 8pt claim so pages go live a
    /// touch before becoming visible.
    private static func neighborTarget(from page: LumenPage, translation: CGSize) -> LumenPage? {
        let threshold: CGFloat = 8
        let w = translation.width
        let h = translation.height
        guard max(abs(w), abs(h)) > threshold else { return nil }
        if abs(w) >= abs(h) {
            if w < 0, let n = LumenPage(column: page.column + 1, row: page.row) { return n }
            if w > 0, let n = LumenPage(column: page.column - 1, row: page.row) { return n }
            if h < 0, let n = LumenPage(column: page.column, row: page.row + 1) { return n }
            if h > 0, let n = LumenPage(column: page.column, row: page.row - 1) { return n }
        } else {
            if h < 0, let n = LumenPage(column: page.column, row: page.row + 1) { return n }
            if h > 0, let n = LumenPage(column: page.column, row: page.row - 1) { return n }
            if w < 0, let n = LumenPage(column: page.column + 1, row: page.row) { return n }
            if w > 0, let n = LumenPage(column: page.column - 1, row: page.row) { return n }
        }
        return nil
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

// MARK: - Pager

/// The full-screen pager.
///
/// This view is a shell. It owns the pager's state, hands the viewport down, and
/// carries the accessibility surface and the settle haptic — nothing that has to
/// run while a finger is down. The one reading of `dragOffset` lives in
/// `DragSurface`, two levels below, so a drag sample re-runs a transform and
/// nothing else.
///
/// HIG notes: paging tracks the finger and settles with velocity projection
/// (Gestures, Scroll views); VoiceOver moves via the adjustable action because
/// drag is not an assumption (Gestures, VoiceOver); offscreen pages leave the
/// accessibility tree and hit testing so they can't trap focus or touches.
struct CoreNavigation: View {
    @Binding private var collectionsExpanded: Bool
    @Environment(BreathingState.self) private var breathing
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var controller = NavigationController()

    init(collectionsExpanded: Binding<Bool> = .constant(false)) {
        _collectionsExpanded = collectionsExpanded
    }

    var body: some View {
        GeometryReader { proxy in
            Pager(
                viewport: proxy.size,
                screenRadius: proxy.screenCornerRadius,
                controller: controller,
                reduceMotion: reduceMotion,
                collectionsExpanded: $collectionsExpanded,
                isPagingEnabled: !collectionsExpanded && !breathing.isBreathing
            )
        }
        .onChange(of: breathing.isBreathing) { _, isBreathing in
            // A breathing session owns the screen: land on the breathe page
            // (the hold can only start there, so this is a no-op in practice)
            // and keep gestures off until the session clears.
            if isBreathing, controller.currentPage != .breathe {
                controller.go(to: .breathe, reduceMotion: reduceMotion)
            }
        }
        .sensoryFeedback(.selection, trigger: controller.settleHapticTick)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Pages"))
        .accessibilityValue(pagerValue)
        .accessibilityHint(Text("Swipe to move between pages"))
        .accessibilityAdjustableAction { direction in
            step(direction == .increment ? 1 : -1)
        }
    }

    private var pagerValue: Text {
        let page = controller.currentPage
        return Text("\(page.title), \(page.rawValue + 1) of \(LumenPage.pages.count)")
    }

    private func step(_ direction: Int) {
        guard !breathing.isBreathing else { return }
        let order = LumenPage.pages
        guard let index = order.firstIndex(of: controller.currentPage) else { return }
        controller.go(to: order[(index + direction + order.count) % order.count], reduceMotion: reduceMotion)
    }
}

/// The viewport's contents plus the paging gesture.
///
/// Reads `currentPage` and `dragTarget` and nothing else from the controller:
/// rebuilt once per committed turn plus at most one extra rebuild per drag
/// when the headed-toward neighbour changes — never per drag sample.
private struct Pager: View {
    let viewport: CGSize
    /// The screen's own corner radius, read here because this is the outermost
    /// point in the tree still resolving against the screen container — the same
    /// reading `MemoryView` takes, and every page below inherits this one value.
    let screenRadius: CGFloat
    let controller: NavigationController
    let reduceMotion: Bool
    @Binding var collectionsExpanded: Bool
    let isPagingEnabled: Bool

    /// Derived once per body evaluation and reused by both `PageStack` and
    /// `pagingGesture`, so the geometry is never built twice for one pass.
    private var metrics: PagingMetrics { PagingMetrics(pageSize: viewport) }

    var body: some View {
        DragSurface(controller: controller) {
            PageStack(
                metrics: metrics,
                screenRadius: screenRadius,
                current: controller.currentPage,
                dragTarget: controller.dragTarget,
                reduceMotion: reduceMotion,
                collectionsExpanded: $collectionsExpanded
            )
        }
        .contentShape(Rectangle())
        .gesture(pagingGesture, isEnabled: isPagingEnabled)
    }

    /// Claim threshold: 8pt (base-4 grid) is the compromise between HIG
    /// "handle gestures as responsively as possible" and letting taps,
    /// long-presses, and inner drags (disk `minimumDistance:0`, carousel/dismiss
    /// `12`) win when they start inside a page. 12pt felt sticky on slow drags;
    /// 0pt starves inner gestures because the outer pager claims first.
    /// `coordinateSpace: .local` keeps translation in the viewport's own points.
    /// Tracking writes `dragOffset` 1:1 and nothing else; the target is chosen
    /// from the projected resting point in `dragEnded`. Disabling via
    /// `isEnabled` blocks new gestures; an in-flight drag simply stops receiving
    /// events and the animated return still runs in `go(to:)`.
    /// See https://sosumi.ai/documentation/swiftui/draggesture/minimumdistance
    /// https://sosumi.ai/design/human-interface-guidelines/gestures
    /// https://sosumi.ai/documentation/swiftui/composing-swiftui-gestures
    private var pagingGesture: some Gesture {
        let metrics = self.metrics
        return DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                controller.dragChanged(value.translation, velocity: value.velocity, from: controller.currentPage, metrics: metrics)
            }
            .onEnded { value in
                controller.dragEnded(
                    value,
                    from: controller.currentPage,
                    metrics: metrics,
                    reduceMotion: reduceMotion
                )
            }
    }
}

/// The pager's only reader of `NavigationController.dragOffset`.
///
/// A stored view value plus one transform, so a drag sample costs one transform
/// and nothing else. Reading the offset in the view that builds the pages — the
/// obvious way to write this — re-diffed all five pages on every touch sample,
/// and that main-thread work is what made delivery steppy on device.
private struct DragSurface<Content: View>: View {
    let controller: NavigationController
    private let content: Content

    init(controller: NavigationController, @ViewBuilder content: () -> Content) {
        self.controller = controller
        // Built here rather than stored as a closure: a retained closure is
        // re-invoked whenever the enclosing view's properties change, which
        // would rebuild the page stack on every drag sample and defeat the
        // point of this type.
        self.content = content()
    }

    var body: some View {
        content
            .offset(controller.dragOffset)
            .clipped()
    }
}

/// The five pages, placed by settled geometry.
///
/// Reads no observable state of its own: `Pager` rebuilds it when a turn is
/// committed or the headed-toward neighbour changes, and a drag never reaches it.
private struct PageStack: View {
    let metrics: PagingMetrics
    let screenRadius: CGFloat
    let current: LumenPage
    let dragTarget: LumenPage?
    let reduceMotion: Bool
    @Binding var collectionsExpanded: Bool

    var body: some View {
        // Per-page offsets are settle-stable (no drag term): during a drag every
        // page holds its settled appearance and the whole stack slides as rigid
        // bitmaps via the single container offset in `DragSurface`. Recede does
        // not track the finger — it crossfades on settle instead.
        ZStack {
            ForEach(LumenPage.pages) { page in
                PageView(
                    page: page,
                    metrics: metrics,
                    screenRadius: screenRadius,
                    offset: metrics.offset(of: page, relativeTo: current),
                    isCurrent: page == current,
                    isLive: page == current || page == dragTarget,
                    reduceMotion: reduceMotion,
                    collectionsExpanded: $collectionsExpanded
                )
                // Guarantee the skip: identical inputs must not re-run a page
                // body at gesture frequency (swiftui-pro performance).
                .equatable()
            }
        }
        .frame(width: metrics.pageSize.width, height: metrics.pageSize.height)
    }
}

/// One viewport-sized page. An off-centre page gets exactly one effect: a fade on
/// `FocusSystem.hidden`'s dim — fully clear a whole step away — eased in by
/// `progress`, so the stack crossfades as one continuous gesture rather than
/// snapping when the drag commits. `hiddenDim` is the only focus value the pager
/// reads, and changing it moves the whole recede.
///
/// Deliberately **not** scaled and **not** blurred, though `FocusSystem` carries
/// both for every state. Blur is gone from the pager by design (plan B): two
/// full-screen variable-radius blurs re-evaluated every frame of the settle was
/// the lag, confirmed by the Reduce Motion test, and freezing the frame drivers
/// alone did not recover it. Scale is gone because opacity is the better single
/// channel: scale is the only one of the three that moves pixels, and a scale
/// about the centre of a full-bleed page is what read as the page *shifting*
/// rather than receding — larger values were tried and landed visibly
/// off-centre downward on collections and Home alike. Opacity cannot translate,
/// so it cannot be misread as movement, and the crossfade carries the depth on
/// its own.
///
/// Deliberately NO `compositingGroup` here either: with no blur there is no
/// layer to unify, and a full-screen offscreen is real GPU memory for nothing.
/// Deliberately NO `geometryGroup`: the barrier forces inner `.position()`
/// values to be resolved/animated by the parent on top of the outer offset
/// spring, so grouped content diverges from the frame mid-settle and only
/// converges at landing — the uniform shift seen on device on every page.
/// Static inner positions pass through untouched instead.
/// See https://sosumi.ai/documentation/swiftui/view/geometrygroup()
/// https://sosumi.ai/documentation/swiftui/view/compositinggroup()
/// https://sosumi.ai/documentation/xcode/understanding-and-improving-swiftui-performance
private struct PageView: View, Equatable {
    let page: LumenPage
    let metrics: PagingMetrics
    /// The screen's own corner radius, handed down from `CoreNavigation`. Part
    /// of equality: a page whose clip moved must not be skipped.
    let screenRadius: CGFloat
    let offset: CGSize
    let isCurrent: Bool
    /// Whether this page's frame drivers may run: settled here or the drag is
    /// headed here. Off-live pages hold a still frame (cheap to fade and slide).
    let isLive: Bool
    let reduceMotion: Bool
    @Binding var collectionsExpanded: Bool

    // @Binding blocks synthesized Equatable; compare underlying values.
    static func == (lhs: PageView, rhs: PageView) -> Bool {
        lhs.page == rhs.page
            && lhs.metrics == rhs.metrics
            && lhs.screenRadius == rhs.screenRadius
            && lhs.offset == rhs.offset
            && lhs.isCurrent == rhs.isCurrent
            && lhs.isLive == rhs.isLive
            && lhs.reduceMotion == rhs.reduceMotion
            && lhs.collectionsExpanded == rhs.collectionsExpanded
    }

    /// The page's clip. Concentric to the system screen container rather than a
    /// fixed radius, because a page's corners *are* the screen's corners: the
    /// resolved value is the display's own curve on every device, where a
    /// hardcoded constant cuts a modern iPhone's radius back to a rounded
    /// rectangle and lets the black base behind the pager show through the
    /// corners it should have filled.
    ///
    /// The floor is the screen radius with nothing deducted — the page sits on
    /// the edge, so there is no inset to step down by, and this is the one
    /// surface in the app where the concentric result and the minimum agree.
    private var card: ConcentricRectangle {
        ConcentricRectangle(corners: .concentric(minimum: .fixed(screenRadius)))
    }

    /// How far this page sits from the settled one, 0…1 — the recede's driver.
    private var progress: CGFloat {
        min(hypot(offset.width / metrics.stepX, offset.height / metrics.stepY), 1)
    }

    var body: some View {
        content
            .frame(width: metrics.pageSize.width, height: metrics.pageSize.height)
            .clipShape(card)
            // The recede, and the only appearance a page away from centre gets:
            // `FocusSystem.hidden`'s dim, interpolated by `progress` rather than
            // switched, so a page half a step away is half faded and the stack
            // crossfades as one gesture. No scale and no blur above this line —
            // see the type's documentation for why opacity is the only channel.
            .opacity(1 - (1 - FocusSystem.hidden.opacity) * Double(progress))
            .offset(offset)
            .allowsHitTesting(isCurrent)
            .accessibilityHidden(!isCurrent)
            .accessibilityLabel(Text(page.title))
            .accessibilityAddTraits(isCurrent ? [.isSelected] : [])
    }

    @ViewBuilder
    private var content: some View {
        switch page {
        case .memory: MemoryView()
        case .home: HomeView(isLive: isLive)
        case .breathe: BreatheView(isLive: isLive)
        case .collections: CollectionsView(collectionsExpanded: $collectionsExpanded, pageSize: metrics.pageSize)
        case .room: RoomView(isLive: isLive)
        }
    }
}