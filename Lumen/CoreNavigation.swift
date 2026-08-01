import SwiftUI

struct CoreNavigation: View {
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var currentPage: Page = .center

    private enum Page: CaseIterable {
        case center, left, right, bottom
    }

    // MARK: - Geometry

    private static let w = UIConstants.General.screenWidth
    private static let h = UIConstants.General.screenHeight
    private static let stepW = w + UIConstants.Navigation.pageSpacing
    private static let stepH = h + UIConstants.Navigation.pageSpacing

    private static func target(for page: Page) -> CGSize {
        switch page {
        case .center: .zero
        case .left:   CGSize(width: stepW, height: 0)
        case .right:  CGSize(width: -stepW, height: 0)
        case .bottom: CGSize(width: 0, height: -stepH)
        }
    }

    private static func base(for page: Page) -> CGSize {
        switch page {
        case .center: .zero
        case .left:   CGSize(width: -stepW, height: 0)
        case .right:  CGSize(width: stepW, height: 0)
        case .bottom: CGSize(width: 0, height: stepH)
        }
    }

    // MARK: - Animation

    /// Smooth snap with subtle bounce — rewards gesture momentum (WWDC2018 "Designing Fluid Interfaces").
    /// Modern duration:bounce API per WWDC2023 "Animate with springs".
    private static let snap = Animation.spring(duration: 0.5, bounce: 0.05)

    /// Heavier critically-damped return for rubberband snapback — weighty, no float.
    private static let rubberbandReturn = Animation.spring(duration: 0.6, bounce: 0.0)

    // MARK: - Rubberband

    /// Asymptotic rubberband curve matching UIScrollView physics.
    /// Approaches `limit` but never reaches it — stronger resistance with distance.
    private static func rubberBandOffset(_ x: CGFloat) -> CGFloat {
        guard x != 0 else { return 0 }
        let limit: CGFloat = 160
        let coefficient: CGFloat = 0.7
        let sign: CGFloat = x > 0 ? 1 : -1
        return sign * limit * (1 - 1 / (abs(x) * coefficient / limit + 1))
    }

    /// Valid horizontal offset range for the given page (from adjacent page targets).
    private func validXRange(for page: Page) -> ClosedRange<CGFloat> {
        let values = adjacentPages(from: page).map { Self.target(for: $0).width }
        return values.min()!...values.max()!
    }

    /// Valid vertical offset range for the given page (from adjacent page targets).
    private func validYRange(for page: Page) -> ClosedRange<CGFloat> {
        let values = adjacentPages(from: page).map { Self.target(for: $0).height }
        return values.min()!...values.max()!
    }

    /// Clamps offset to valid ranges, applying rubberband resistance beyond bounds.
    private func applyRubberband(to raw: CGSize) -> CGSize {
        let xRange = validXRange(for: currentPage)
        let yRange = validYRange(for: currentPage)

        let x: CGFloat
        if raw.width < xRange.lowerBound {
            x = xRange.lowerBound + Self.rubberBandOffset(raw.width - xRange.lowerBound)
        } else if raw.width > xRange.upperBound {
            x = xRange.upperBound + Self.rubberBandOffset(raw.width - xRange.upperBound)
        } else {
            x = raw.width
        }

        let y: CGFloat
        if raw.height < yRange.lowerBound {
            y = yRange.lowerBound + Self.rubberBandOffset(raw.height - yRange.lowerBound)
        } else if raw.height > yRange.upperBound {
            y = yRange.upperBound + Self.rubberBandOffset(raw.height - yRange.upperBound)
        } else {
            y = raw.height
        }

        return CGSize(width: x, height: y)
    }

    // MARK: - Visual Effects

    private static let corner = RoundedRectangle(
        cornerRadius: UIConstants.General.screenCornerRadius, style: .continuous
    )

    /// 0→1 unfocus progress from drag displacement.
    /// Computed once per page per frame — single source of truth for all visual effects.
    private func unfocusProgress(for page: Page) -> CGFloat {
        let t = Self.target(for: page)
        let delta: CGFloat = page == .bottom
            ? abs(offset.height - t.height)
            : abs(offset.width - t.width)
        return min(delta / (page == .bottom ? Self.stepH : Self.stepW), 1)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            ForEach(Page.allCases, id: \.self) { page in
                let p = unfocusProgress(for: page)
                // The unfocused look IS FocusedState.subdued, interpolated by
                // drag progress — navigation uses the same focus language as
                // every other layer instead of its own inline values.
                let subdued = FocusedState.subdued

                pageContent(page)
                    .frame(width: Self.w, height: Self.h)
                    .clipShape(Self.corner)
                    .scaleEffect(1 - (1 - subdued.scale) * p)
                    .compositingGroup()
                    .blur(radius: subdued.blur * p)
                    .opacity(1 - (1 - subdued.opacity) * p)
                    .offset(Self.base(for: page))
            }
        }
        .frame(width: Self.w, height: Self.h)
        .offset(offset)
        .gesture(dragGesture)
        .clipped()
        .ignoresSafeArea()
        .drawingGroup()
    }

    @ViewBuilder
    private func pageContent(_ page: Page) -> some View {
        switch page {
        case .center:  HomeView()
        case .left:    MemoryView()
        case .right:   BreatheView()
        case .bottom:  CollectionsView()
        }
    }

    // MARK: - Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                let raw = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
                offset = applyRubberband(to: raw)
            }
            .onEnded { value in
                let chosen = snapTarget(for: value)
                let returningToCurrentPage = (chosen == Self.target(for: currentPage))
                withAnimation(returningToCurrentPage ? Self.rubberbandReturn : Self.snap) {
                    offset = chosen
                    lastOffset = chosen
                }
                currentPage = Page.allCases.first { Self.target(for: $0) == chosen } ?? currentPage
            }
    }

    // MARK: - Snap Decision

    /// Determines which page to snap to based on displacement threshold or velocity prediction.
    private func snapTarget(for value: DragGesture.Value) -> CGSize {
        let pages = adjacentPages(from: currentPage)
        let currentTarget = Self.target(for: currentPage)
        let drag = CGSize(
            width: offset.width - currentTarget.width,
            height: offset.height - currentTarget.height
        )

        // Displacement threshold: commit if drag exceeds 25% of a page step.
        if let d = displacementTarget(drag),
           pages.contains(where: { Self.target(for: $0) == d }) {
            return d
        }

        // Velocity prediction fallback: project where the gesture is heading.
        let predicted = CGSize(
            width: offset.width + value.velocity.width * 0.12,
            height: offset.height + value.velocity.height * 0.12
        )
        var bestPage = pages[0]
        var bestDist = CGFloat.infinity
        for page in pages {
            let t = Self.target(for: page)
            let dist = hypot(predicted.width - t.width, predicted.height - t.height)
            if dist < bestDist {
                bestDist = dist
                bestPage = page
            }
        }
        return Self.target(for: bestPage)
    }

    /// Computes the target offset from drag displacement, or nil if below threshold.
    private func displacementTarget(_ drag: CGSize) -> CGSize? {
        let tw = Self.stepW * 0.25, th = Self.stepH * 0.25

        if abs(drag.width) > tw {
            return CGSize(width: drag.width > 0 ? Self.stepW : -Self.stepW, height: 0)
        }
        if abs(drag.height) > th, drag.height < 0 {
            return CGSize(width: 0, height: -Self.stepH)
        }
        return nil
    }

    /// Center can reach all pages; side pages only return to center.
    private func adjacentPages(from page: Page) -> [Page] {
        switch page {
        case .center: Page.allCases
        case .left, .right, .bottom: [page, .center]
        }
    }
}

#Preview {
    CoreNavigation()
}
