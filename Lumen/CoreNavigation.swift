import SwiftUI

struct CoreNavigation: View {
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var currentPage: Page = .center

    private enum Page: CaseIterable {
        case center, left, right, bottom
    }

    private static let pageStepW = UIConstants.General.screenWidth + UIConstants.Navigation.pageSpacing
    private static let pageStepH = UIConstants.General.screenHeight + UIConstants.Navigation.pageSpacing

    private static func targetOffset(for page: Page) -> CGSize {
        switch page {
        case .center: return .zero
        case .left:   return CGSize(width: pageStepW, height: 0)
        case .right:  return CGSize(width: -pageStepW, height: 0)
        case .bottom: return CGSize(width: 0, height: -pageStepH)
        }
    }

    private static func baseOffset(for page: Page) -> CGSize {
        switch page {
        case .center: return .zero
        case .left:   return CGSize(width: -pageStepW, height: 0)
        case .right:  return CGSize(width: pageStepW, height: 0)
        case .bottom: return CGSize(width: 0, height: pageStepH)
        }
    }

    private static let corners = RoundedRectangle(
        cornerRadius: UIConstants.General.screenCornerRadius,
        style: .continuous
    )

    var body: some View {
        let w = UIConstants.General.screenWidth
        let h = UIConstants.General.screenHeight
        ZStack {
            ForEach(Page.allCases, id: \.self) { page in
                pageContent(page)
                    .frame(width: w, height: h)
                    .clipShape(Self.corners)
                    .scaleEffect(focusScale(for: page))
                    .compositingGroup()
                    .blur(radius: focusBlur(for: page))
                    .opacity(focusOpacity(for: page))
                    .offset(Self.baseOffset(for: page))
            }
        }
        .frame(width: w, height: h)
        .offset(offset)
        .gesture(dragGesture)
        .clipped()
        .ignoresSafeArea()
        .drawingGroup()
    }

    @ViewBuilder
    private func pageContent(_ page: Page) -> some View {
        switch page {
        case .center:     HomeView()
        case .left:       MemoryView()
        case .right:      BreatheView()
        case .bottom:     CollectionsView()
        }
    }

    private func unfocusProgress(for page: Page) -> CGFloat {
        let target = Self.targetOffset(for: page)
        let distance: CGFloat
        let step: CGFloat
        switch page {
        case .center, .left, .right:
            distance = abs(offset.width - target.width)
            step = Self.pageStepW
        case .bottom:
            distance = abs(offset.height - target.height)
            step = Self.pageStepH
        }
        return min(distance / step, 1.0)
    }

    private func focusScale(for page: Page) -> CGFloat {
        1.0 - (UIConstants.Focus.subduedScale / 100) * unfocusProgress(for: page)
    }

    private func focusBlur(for page: Page) -> CGFloat {
        UIConstants.Focus.subduedBlur * unfocusProgress(for: page)
    }

    private func focusOpacity(for page: Page) -> Double {
        1.0 - (1.0 - Double(UIConstants.Focus.subduedOpacity) / 100) * Double(unfocusProgress(for: page))
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { value in
                let targets = adjacentPages(from: currentPage)
                    .map { ($0, Self.targetOffset(for: $0)) }
                let dragFromTarget = CGSize(
                    width: offset.width - Self.targetOffset(for: currentPage).width,
                    height: offset.height - Self.targetOffset(for: currentPage).height
                )

                // — displacement threshold: commit if drag exceeds 25 % of a full page
                let thresholdW = Self.pageStepW * 0.25
                let thresholdH = Self.pageStepH * 0.25

                let displacementTarget: CGSize? = {
                    if abs(dragFromTarget.width) > thresholdW,
                       dragFromTarget.width > 0 {
                        return CGSize(width: Self.pageStepW, height: 0)   // left page
                    }
                    if abs(dragFromTarget.width) > thresholdW,
                       dragFromTarget.width < 0 {
                        return CGSize(width: -Self.pageStepW, height: 0)  // right page
                    }
                    if abs(dragFromTarget.height) > thresholdH,
                       dragFromTarget.height < 0 {
                        return CGSize(width: 0, height: -Self.pageStepH)  // bottom page
                    }
                    return nil
                }()

                let chosen: CGSize
                if let displacementTarget, targets.contains(where: { $0.1 == displacementTarget }) {
                    chosen = displacementTarget
                } else {
                    // — velocity-prediction fallback
                    let predicted = CGSize(
                        width: offset.width + value.velocity.width * 0.12,
                        height: offset.height + value.velocity.height * 0.12
                    )
                    chosen = targets.min { a, b in
                        let da = hypot(predicted.width - a.1.width, predicted.height - a.1.height)
                        let db = hypot(predicted.width - b.1.width, predicted.height - b.1.height)
                        return da < db
                    }!.1
                }

                currentPage = targets.first { $0.1 == chosen }!.0
                withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.8)) {
                    offset = chosen
                    lastOffset = offset
                }
            }
    }

    private func adjacentPages(from page: Page) -> [Page] {
        switch page {
        case .center: return [.center, .left, .right, .bottom]
        case .left:   return [.left, .center]
        case .right:  return [.right, .center]
        case .bottom: return [.bottom, .center]
        }
    }
}

#Preview {
    CoreNavigation()
}
