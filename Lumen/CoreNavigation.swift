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
    private static let snap = Animation.spring(duration: 0.45, bounce: 0.05)

    // MARK: - Visual Effects

    private static let corner = RoundedRectangle(
        cornerRadius: UIConstants.General.screenCornerRadius, style: .continuous
    )

    /// 0→1 progress: how far this page is from being the focused (visible) page.
    /// Single source of truth for all per-page visual effects.
    private func unfocusProgress(for page: Page) -> CGFloat {
        let t = Self.target(for: page)
        let (dist, step): (CGFloat, CGFloat) = switch page {
        case .bottom: (abs(offset.height - t.height), Self.stepH)
        default:      (abs(offset.width - t.width), Self.stepW)
        }
        return min(dist / step, 1)
    }

    private func scale(for page: Page) -> CGFloat {
        1 - (UIConstants.Focus.subduedScale / 100) * unfocusProgress(for: page)
    }

    private func blur(for page: Page) -> CGFloat {
        UIConstants.Focus.subduedBlur * unfocusProgress(for: page)
    }

    private func opacity(for page: Page) -> Double {
        1 - (1 - Double(UIConstants.Focus.subduedOpacity) / 100) * Double(unfocusProgress(for: page))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            ForEach(Page.allCases, id: \.self) { page in
                pageContent(page)
                    .frame(width: Self.w, height: Self.h)
                    .clipShape(Self.corner)
                    .scaleEffect(scale(for: page))
                    .compositingGroup()
                    .blur(radius: blur(for: page))
                    .opacity(opacity(for: page))
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
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { value in
                let chosen = snapTarget(for: value)
                withAnimation(Self.snap) {
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
        let fromTarget = CGSize(
            width: offset.width - currentTarget.width,
            height: offset.height - currentTarget.height
        )

        // Displacement threshold: commit if drag exceeds 25% of a page step
        let tw = Self.stepW * 0.25, th = Self.stepH * 0.25

        if let d = displacementTarget(fromTarget, tw: tw, th: th),
           pages.contains(where: { Self.target(for: $0) == d }) {
            return d
        }

        // Velocity prediction fallback: project where the gesture is heading
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
    private func displacementTarget(_ drag: CGSize, tw: CGFloat, th: CGFloat) -> CGSize? {
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
        case .center: [.center, .left, .right, .bottom]
        case .left:   [.left, .center]
        case .right:  [.right, .center]
        case .bottom: [.bottom, .center]
        }
    }
}

#Preview {
    CoreNavigation()
}
