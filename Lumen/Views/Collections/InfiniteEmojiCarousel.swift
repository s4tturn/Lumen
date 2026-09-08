import SwiftUI

// MARK: - Expanded Collection Content

struct InfiniteEmojiCarousel: View {
    let items: [CollectionItem]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pageIndex = 0
    @State private var pageOffset: CGFloat = 0
    @State private var isSettling = false

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            HStack(spacing: 0) {
                ForEach(-1...1, id: \.self) { relativeIndex in
                    let item = items[wrapped(relativeIndex + pageIndex)]

                    VStack(spacing: 16) {
                        Text(item.emoji)
                            .font(.system(size: min(width * 0.34, 150)))

                        Text(item.task)
                            .font(.system(.title2, design: .serif))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding(.horizontal, 24)
                    }
                    .frame(width: width, height: geometry.size.height)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Object \(item.emoji), task \(item.task)")
                }
            }
            .offset(x: -width + pageOffset)
            .contentShape(Rectangle())
            .clipped()
            .gesture(carouselGesture(width: width))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func wrapped(_ index: Int) -> Int {
        let n = items.count
        return ((index % n) + n) % n
    }

    private func carouselGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                guard !isSettling else { return }

                guard abs(value.translation.width) > abs(value.translation.height) else {
                    pageOffset = 0
                    return
                }

                pageOffset = value.translation.width
            }
            .onEnded { value in
                Task { await handleEnd(value, width: width) }
            }
    }

    private func handleEnd(_ value: DragGesture.Value, width: CGFloat) async {
        guard !isSettling else { return }

        let horizontal = value.translation.width
        guard abs(horizontal) > abs(value.translation.height) else {
            settleBack()
            return
        }

        let predicted = value.predictedEndTranslation.width
        let fastFlick = abs(value.velocity.width) >= Layout.carouselFlickVelocity

        let shouldAdvance =
            abs(horizontal) > width * 0.2
            || abs(predicted) > width * 0.25
            || fastFlick

        guard shouldAdvance else {
            settleBack()
            return
        }

        let signal = fastFlick
            ? value.velocity.width
            : abs(predicted) > abs(horizontal) ? predicted : horizontal
        let direction = signal < 0 ? 1 : -1

        isSettling = true
        let targetOffset = (direction == 1 ? -2 * width : 0) + width
        withAnimation(UIConstants.Animation.motionGate(UIConstants.Animation.snappySpring, reduceMotion: reduceMotion)) {
            pageOffset = targetOffset
        }
        try? await Task.sleep(for: .seconds(0))
        pageIndex += direction
        pageOffset = 0
        isSettling = false
    }

    private func settleBack() {
        withAnimation(UIConstants.Animation.motionGate(UIConstants.Animation.smoothSpring, reduceMotion: reduceMotion)) {
            pageOffset = 0
        }
    }
}
