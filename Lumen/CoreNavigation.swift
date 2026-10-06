import SwiftUI

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

private struct Pager: View {
    let viewport: CGSize

    let screenRadius: CGFloat
    let controller: NavigationController
    let reduceMotion: Bool
    @Binding var collectionsExpanded: Bool
    let isPagingEnabled: Bool

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

private struct DragSurface<Content: View>: View {
    let controller: NavigationController
    private let content: Content

    init(controller: NavigationController, @ViewBuilder content: () -> Content) {
        self.controller = controller

        self.content = content()
    }

    var body: some View {
        content
            .offset(controller.dragOffset)
            .clipped()

            .debugSurfaceBorder()
    }
}

private struct PageStack: View {
    let metrics: PagingMetrics
    let screenRadius: CGFloat
    let current: LumenPage
    let dragTarget: LumenPage?
    let reduceMotion: Bool
    @Binding var collectionsExpanded: Bool

    var body: some View {

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

                .equatable()
            }
        }
        .frame(width: metrics.pageSize.width, height: metrics.pageSize.height)
    }
}

private struct PageView: View, Equatable {
    let page: LumenPage
    let metrics: PagingMetrics

    let screenRadius: CGFloat
    let offset: CGSize
    let isCurrent: Bool

    let isLive: Bool
    let reduceMotion: Bool
    @Binding var collectionsExpanded: Bool

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

    private var card: ConcentricRectangle {
        ConcentricRectangle(corners: .concentric(minimum: .fixed(screenRadius)))
    }

    private var progress: CGFloat {
        min(hypot(offset.width / metrics.stepX, offset.height / metrics.stepY), 1)
    }

    var body: some View {
        content
            .frame(width: metrics.pageSize.width, height: metrics.pageSize.height)
            .clipShape(card)

            .debugSurfaceBorder(card)

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
import SwiftUI

enum LumenPage: Int, CaseIterable, Identifiable, Sendable, Equatable {
    case memory, home, breathe, collections, room

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

    func hasNeighbor(columnOffset: Int = 0, rowOffset: Int = 0) -> Bool {
        LumenPage(column: column + columnOffset, row: row + rowOffset) != nil
    }
}
import Observation
import SwiftUI

@MainActor
@Observable
final class NavigationController {
    private(set) var currentPage: LumenPage = .home

    private(set) var dragOffset: CGSize = .zero

    private(set) var dragTarget: LumenPage?

    private(set) var settleHapticTick = 0

    @ObservationIgnored private var settleToken = 0

    func dragChanged(_ translation: CGSize, velocity: CGSize, from page: LumenPage, metrics: PagingMetrics) {

        let next = Self.neighborTarget(from: page, translation: translation)
        if next != dragTarget {
            dragTarget = next
        }

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

        let predicted = metrics.clamped(value.predictedEndTranslation, from: page)
        go(to: targetPage(from: page, predicted: predicted, metrics: metrics), reduceMotion: reduceMotion)
    }

    func go(to target: LumenPage, reduceMotion: Bool) {
        settleToken &+= 1
        let token = settleToken
        withAnimation(
            UIConstants.Animation.reduceMotionGate(UIConstants.Animation.dwell, reduceMotion: reduceMotion),
            completionCriteria: .logicallyComplete
        ) {

            currentPage = target
            dragOffset = .zero
            dragTarget = nil
        } completion: { [self] in

            guard token == self.settleToken else { return }
            self.settleHapticTick &+= 1
        }
    }

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

import SwiftUI

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

    func offset(of page: LumenPage, relativeTo origin: LumenPage) -> CGSize {
        CGSize(
            width: CGFloat(page.column - origin.column) * stepX,
            height: CGFloat(page.row - origin.row) * stepY
        )
    }

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

    private func axisRange(_ step: CGFloat, backward: Bool, forward: Bool) -> ClosedRange<CGFloat> {
        switch (backward, forward) {
        case (false, false): 0 ... 0
        case (true, false): 0 ... step
        case (false, true): -step ... 0
        case (true, true): -step ... step
        }
    }

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
