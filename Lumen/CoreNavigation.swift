import SwiftUI
import Observation

/// Represents a page in the 2×2 navigation grid.
enum LumenPage: Int, CaseIterable, Identifiable, Sendable {
    case page1, page2, page3, page4

    var id: Int { rawValue }

    var column: Int {
        switch self {
        case .page1: 0
        case .page2: 1
        case .page3: 2
        case .page4: 1
        }
    }

    var row: Int {
        switch self {
        case .page1, .page2, .page3: 0
        case .page4: 1
        }
    }

    var isCenter: Bool { self == .page2 }

    init?(column: Int, row: Int) {
        switch (column, row) {
        case (0, 0): self = .page1
        case (1, 0): self = .page2
        case (2, 0): self = .page3
        case (1, 1): self = .page4
        default: return nil
        }
    }

    var color: Color {
        switch self {
        case .page1: .red
        case .page2: .yellow
        case .page3: .green
        case .page4: .blue
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .page1: "Page 1, top left"
        case .page2: "Page 2, top center"
        case .page3: "Page 3, top right"
        case .page4: "Page 4, bottom center"
        }
    }
}

/// Precomputed layout metrics to avoid recalculation during drag.
@MainActor
@Observable
final class NavigationLayout {
    let pageWidth: CGFloat
    let pageHeight: CGFloat
    let stepX: CGFloat
    let stepY: CGFloat

    init(proxy: GeometryProxy) {
        self.pageWidth = proxy.size.width
        self.pageHeight = proxy.size.height
        self.stepX = pageWidth + UIConstants.Navigation.pageSpacing
        self.stepY = pageHeight + UIConstants.Navigation.pageSpacing
    }

    var contentWidth: CGFloat { 3 * stepX }
    var contentHeight: CGFloat { 2 * stepY }
}

/// Manages navigation state and gesture handling.
@MainActor
@Observable
final class NavigationController {
    var currentPage: LumenPage = .page2
    var dragTranslation: CGSize = .zero
    private(set) var isDragging = false

    private let rubberBandCoefficient: CGFloat = 0.55

    func handleDragChanged(_ value: DragGesture.Value, layout: NavigationLayout) {
        if !isDragging {
            isDragging = true
        }

        withAnimation(UIConstants.Animation.tracking) {
            dragTranslation = rubberbanded(value.translation, for: currentPage, layout: layout)
        }
    }

    func handleDragEnded(_ value: DragGesture.Value, layout: NavigationLayout) {
        isDragging = false

        let predicted = clamped(value.predictedEndTranslation, for: currentPage, layout: layout)
        let target = targetPage(from: currentPage, predicted: predicted, layout: layout)
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        let animation = reduceMotion
            ? UIConstants.Animation.reducedMotionFallback
            : (target == currentPage ? UIConstants.Animation.rubberbandReturn : UIConstants.Animation.snap)

        withAnimation(animation) {
            currentPage = target
            dragTranslation = .zero
        }
    }

    // MARK: - Private Physics Calculations

    private func validRanges(for page: LumenPage, layout: NavigationLayout) -> (x: ClosedRange<CGFloat>, y: ClosedRange<CGFloat>) {
        let xRange: ClosedRange<CGFloat>
        switch page {
        case .page1: xRange = -layout.stepX...0
        case .page2: xRange = -layout.stepX...layout.stepX
        case .page3: xRange = 0...layout.stepX
        case .page4: xRange = 0...0
        }

        let yRange: ClosedRange<CGFloat>
        if page.isCenter {
            yRange = -layout.stepY...0
        } else if page == .page4 {
            yRange = 0...layout.stepY
        } else {
            yRange = 0...0
        }

        return (x: xRange, y: yRange)
    }

    private func clamped(_ translation: CGSize, for page: LumenPage, layout: NavigationLayout) -> CGSize {
        let ranges = validRanges(for: page, layout: layout)
        return CGSize(
            width: min(max(translation.width, ranges.x.lowerBound), ranges.x.upperBound),
            height: min(max(translation.height, ranges.y.lowerBound), ranges.y.upperBound)
        )
    }

    private func rubberbanded(_ translation: CGSize, for page: LumenPage, layout: NavigationLayout) -> CGSize {
        let ranges = validRanges(for: page, layout: layout)
        return CGSize(
            width: rubberBandedComponent(translation.width, range: ranges.x, dimension: layout.pageWidth),
            height: rubberBandedComponent(translation.height, range: ranges.y, dimension: layout.pageHeight)
        )
    }

    private func rubberBandedComponent(_ raw: CGFloat, range: ClosedRange<CGFloat>, dimension: CGFloat) -> CGFloat {
        if raw < range.lowerBound {
            return range.lowerBound + rubberBand(raw - range.lowerBound, dimension: dimension)
        }
        if raw > range.upperBound {
            return range.upperBound + rubberBand(raw - range.upperBound, dimension: dimension)
        }
        return raw
    }

    private func rubberBand(_ distance: CGFloat, dimension: CGFloat) -> CGFloat {
        guard dimension > 0 else { return 0 }
        let sign: CGFloat = distance > 0 ? 1 : -1
        return sign * (1 - 1 / ((abs(distance) * rubberBandCoefficient / dimension) + 1)) * dimension
    }

    private func targetPage(from page: LumenPage, predicted: CGSize, layout: NavigationLayout) -> LumenPage {
        let thresholdX = layout.stepX * 0.25
        let thresholdY = layout.stepY * 0.25

        let newCol = abs(predicted.width) > thresholdX
            ? page.column + (predicted.width < 0 ? 1 : -1)
            : page.column
        let newRow = abs(predicted.height) > thresholdY
            ? page.row + (predicted.height < 0 ? 1 : -1)
            : page.row

        // Try direct target first
        if let candidate = LumenPage(column: newCol, row: newRow) {
            return candidate
        }

        // Fall back to dominant axis
        if abs(predicted.width) >= abs(predicted.height) {
            if let horizontal = LumenPage(column: newCol, row: page.row) { return horizontal }
            if let vertical = LumenPage(column: page.column, row: newRow) { return vertical }
        } else {
            if let vertical = LumenPage(column: page.column, row: newRow) { return vertical }
            if let horizontal = LumenPage(column: newCol, row: page.row) { return horizontal }
        }
        return page
    }
}

/// The main navigation view with a 2×2 grid of pages and drag navigation.
struct CoreNavigation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding private var collectionsExpanded: Bool
    @State private var controller = NavigationController()

    init(collectionsExpanded: Binding<Bool> = .constant(false)) {
        self._collectionsExpanded = collectionsExpanded
    }

    var body: some View {
        GeometryReader { proxy in
            let currentLayout = NavigationLayout(proxy: proxy)

            navigationContent(layout: currentLayout)
                .gesture(dragGesture(layout: currentLayout))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main navigation")
        .accessibilityHint("Drag to navigate between pages")
    }

    @ViewBuilder
    private func navigationContent(layout: NavigationLayout) -> some View {
        ZStack {
            ForEach(LumenPage.allCases) { page in
                pageView(page, layout: layout)
            }
        }
        .frame(width: layout.contentWidth, height: layout.contentHeight)
        .offset(
            x: -CGFloat(controller.currentPage.column) * layout.stepX + controller.dragTranslation.width,
            y: -CGFloat(controller.currentPage.row) * layout.stepY + controller.dragTranslation.height
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func pageView(_ page: LumenPage, layout: NavigationLayout) -> some View {
        let offsetX = CGFloat(page.column - controller.currentPage.column) * layout.stepX + controller.dragTranslation.width
        let offsetY = CGFloat(page.row - controller.currentPage.row) * layout.stepY + controller.dragTranslation.height
        let distance = sqrt(offsetX * offsetX + offsetY * offsetY)
        let progress = min(distance / layout.stepX, 1.0)

        let pageSize = CGSize(width: layout.pageWidth, height: layout.pageHeight)

        pageContent(page, pageSize: pageSize)
            .frame(width: pageSize.width, height: pageSize.height)
            .clipShape(ContainerRelativeShape())
            .scaleEffect(effectiveScale(progress: progress))
            .blur(radius: effectiveBlur(progress: progress))
            .opacity(effectiveOpacity(progress: progress))
            .position(
                x: CGFloat(page.column) * layout.stepX + layout.pageWidth / 2,
                y: CGFloat(page.row) * layout.stepY + layout.pageHeight / 2
            )
            .accessibilityLabel(page.accessibilityLabel)
            .accessibilityAddTraits(page == controller.currentPage ? .isSelected : [])
    }

    @ViewBuilder
    private func pageContent(_ page: LumenPage, pageSize: CGSize) -> some View {
        switch page {
        case .page1:
            MemoryView()
        case .page2:
            HomeView()
        case .page3:
            BreatheView()
        case .page4:
            CollectionsView(collectionsExpanded: $collectionsExpanded, pageSize: pageSize)
        }
    }

    private func effectiveBlur(progress: CGFloat) -> CGFloat {
        reduceMotion ? 0 : UIConstants.Focus.subduedBlur * progress
    }

    private func effectiveOpacity(progress: CGFloat) -> Double {
        1.0 - (1.0 - UIConstants.Focus.subduedDim) * Double(progress)
    }

    private func effectiveScale(progress: CGFloat) -> CGFloat {
        reduceMotion ? 1.0 : 1.0 - (1.0 - UIConstants.Focus.subduedScale) * progress
    }

    private func dragGesture(layout: NavigationLayout) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                controller.handleDragChanged(value, layout: layout)
            }
            .onEnded { value in
                controller.handleDragEnded(value, layout: layout)
            }
    }
}
