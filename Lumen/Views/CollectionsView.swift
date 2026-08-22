import SwiftUI
import UIKit

// MARK: - Models

struct CollectionItem: Identifiable, Equatable {
    let id = UUID()
    let emoji: String
    let name: String
    let task: String
}

// MARK: - Card Configuration

private struct Card: Identifiable {
    let id = UUID()
    let imageName: String
    let name: String
    let items: [CollectionItem]
}

private let cards: [Card] = [
    Card(
        imageName: "SelfBackground",
        name: "Self",
        items: [
            CollectionItem(emoji: "🚶‍♂️", name: "Walk", task: "Take a 10-minute walk somewhere pleasant"),
            CollectionItem(emoji: "🧘‍♀️", name: "Stretch", task: "Do a full-body stretch while listening to one song"),
            CollectionItem(emoji: "🧥", name: "Clothes", task: "Take a shower and put on clothes you feel good in"),
            CollectionItem(emoji: "💧", name: "Water", task: "Drink a big glass of water"),
            CollectionItem(emoji: "✨", name: "Ritual", task: "Do one small grooming ritual you've been neglecting")
        ]
    ),
    Card(
        imageName: "SpaceBackground",
        name: "Space",
        items: [
            CollectionItem(emoji: "🧽", name: "Surface", task: "Clear one surface completely"),
            CollectionItem(emoji: "🧺", name: "Belongings", task: "Put 10 things back where they belong"),
            CollectionItem(emoji: "🛏️", name: "Bed", task: "Make your bed properly"),
            CollectionItem(emoji: "🌬️", name: "Windows", task: "Open the windows and freshen the room"),
            CollectionItem(emoji: "🕯️", name: "Beauty", task: "Make one small area feel beautiful")
        ]
    ),
    Card(
        imageName: "KitchenBackground",
        name: "Kitchen",
        items: [
            CollectionItem(emoji: "🥞", name: "Breakfast", task: "Make your favorite breakfast"),
            CollectionItem(emoji: "🥗", name: "Snack", task: "Create a snack from whatever you already have"),
            CollectionItem(emoji: "🍳", name: "Recipe", task: "Cook something you've never made before"),
            CollectionItem(emoji: "☕", name: "Drink", task: "Make yourself a really good drink"),
            CollectionItem(emoji: "🍲", name: "Memory", task: "Recreate a dish you love from memory")
        ]
    ),
    Card(
        imageName: "ConnectionBackground",
        name: "Connection",
        items: [
            CollectionItem(emoji: "📸", name: "Photo", task: "Send someone a photo that made you think of them"),
            CollectionItem(emoji: "💬", name: "Appreciation", task: "Tell someone something you genuinely appreciate about them"),
            CollectionItem(emoji: "📞", name: "Call", task: "Call someone you haven't spoken to in a while"),
            CollectionItem(emoji: "🎁", name: "Favor", task: "Do a small unexpected favor for someone"),
            CollectionItem(emoji: "⏳", name: "Presence", task: "Spend 15 minutes with someone without your phone")
        ]
    ),
    Card(
        imageName: "GrowthBackground",
        name: "Growth",
        items: [
            CollectionItem(emoji: "📖", name: "Reading", task: "Read 5 pages of something you're interested in"),
            CollectionItem(emoji: "💡", name: "Learning", task: "Learn one interesting thing and tell someone about it"),
            CollectionItem(emoji: "🎯", name: "Practice", task: "Practice a skill for 10 minutes"),
            CollectionItem(emoji: "✍️", name: "Idea", task: "Write down one idea you've been sitting on"),
            CollectionItem(emoji: "🛠️", name: "Making", task: "Spend 10 minutes making something you've been putting off")
        ]
    ),
    Card(
        imageName: "JoyBackground",
        name: "Joy",
        items: [
            CollectionItem(emoji: "🎧", name: "Music", task: "Listen to a favorite song with your eyes closed"),
            CollectionItem(emoji: "🎨", name: "Hobby", task: "Spend 15 minutes on a hobby you haven't touched recently"),
            CollectionItem(emoji: "🌸", name: "Beauty", task: "Go outside and find something beautiful"),
            CollectionItem(emoji: "🤪", name: "Silly", task: "Do something purely silly"),
            CollectionItem(emoji: "😂", name: "Laughter", task: "Rewatch a scene that always makes you laugh")
        ]
    )
]

// MARK: - Geometry

private struct CollectionsGeometry {
    let size: CGSize

    var diskRadius: CGFloat { size.height * Layout.diskRadiusRatio }
    var diskDiameter: CGFloat { diskRadius * 2 }
    var cardSize: CGFloat { diskDiameter * Layout.cardSizeRatio }
    var orbitPadding: CGFloat { diskRadius * Layout.orbitPaddingRatio }
    var orbitRadius: CGFloat { diskRadius + orbitPadding + cardSize / 2 }
    var diskCenter: CGPoint { CGPoint(x: size.width / 2, y: size.height) }
    var diskDeadZone: CGFloat { diskRadius * Layout.deadZoneRatio }
    var dismissThreshold: CGFloat { cardSize * 0.15 }
    var collapsedCornerRadius: CGFloat { cardSize * Layout.collapsedCornerRatio }
    var tickHeight: CGFloat { diskRadius * Layout.tickHeightRatio }
    var tickWidth: CGFloat { diskRadius * Layout.tickWidthRatio }
    var screenCornerRadius: CGFloat { UIConstants.General.screenCornerRadius }
}

// MARK: - Constants

private enum Layout {
    static let cardCount = cards.count

    static let cardSpacing: Double = 360.0 / Double(cardCount)
    static let tickSpacing: Double = UIConstants.Collections.cardAngle

    static let diskRadiusRatio: CGFloat = 0.35
    static let cardSizeRatio: CGFloat = 0.5
    static let orbitPaddingRatio: CGFloat = 0.20
    static let deadZoneRatio: CGFloat = 0.06
    static let collapsedCornerRatio: CGFloat = 0.15
    static let tickHeightRatio: CGFloat = 0.15
    static let tickWidthRatio: CGFloat = 0.03

    static let expandAnimation: Animation = .spring(.smooth(duration: 0.5))
    static let dismissAnimation: Animation = .spring(.snappy(duration: 0.45))
    static let snapBackAnimation: Animation = .spring(.smooth(duration: 0.4))
    static let snapSpring: Spring = .smooth(duration: 0.55)

    static let dismissVelocity: CGFloat = 800
    static let carouselFlickVelocity: CGFloat = 700
}

private enum CoordinateSpaces {
    static let collections = "CollectionsView"
}

// MARK: - Math Helpers

private func degrees(fromRadians radians: Double) -> Double {
    radians * 180.0 / .pi
}

private func radians(fromDegrees degrees: Double) -> Double {
    degrees * .pi / 180.0
}

private func normalizedAngleDelta(from start: Double, to end: Double) -> Double {
    var delta = end - start
    while delta > 180 { delta -= 360 }
    while delta < -180 { delta += 360 }
    return delta
}

private func angle(of point: CGPoint, around center: CGPoint) -> Double {
    degrees(
        fromRadians: atan2(
            point.y - center.y,
            point.x - center.x
        )
    )
}

// MARK: - Ghost Card Assets

private var lowResImageCache: [String: UIImage] = [:]

private func lowResImage(for name: String) -> Image {
    if let cached = lowResImageCache[name] {
        return Image(uiImage: cached)
    }

    let placeholder = Image(name)

    guard let source = UIImage(named: name) else {
        return placeholder
    }

    let longEdge: CGFloat = 48
    let scale = min(
        1,
        longEdge / max(source.size.width, source.size.height)
    )
    let target = CGSize(
        width: max(1, source.size.width * scale),
        height: max(1, source.size.height * scale)
    )

    let small = UIGraphicsImageRenderer(size: target)
        .image { _ in
            source.draw(in: CGRect(origin: .zero, size: target))
        }

    lowResImageCache[name] = small
    return Image(uiImage: small)
}

// MARK: - Shared Card Layout

private struct CardLayout {
    let position: CGPoint
    let size: CGSize
    let offsetY: CGFloat
    let cornerRadius: CGFloat
}

// MARK: - Tick Marks

private struct TickMarksView: View {
    let rotation: Double
    let radius: CGFloat
    let tickWidth: CGFloat
    let tickHeight: CGFloat

    private let count = Int(360.0 / Layout.tickSpacing)

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(.white)
                    .frame(width: tickWidth, height: tickHeight)
                    .offset(y: -radius + tickHeight + 2)
                    .rotationEffect(.degrees(Double(index) * Layout.tickSpacing))
            }
        }
        .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Expanded Collection Content

private struct InfiniteEmojiCarousel: View {
    let items: [CollectionItem]

    @State private var pageIndex = 0
    @State private var pageOffset: CGFloat = 0
    @State private var isSettling = false

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            HStack(spacing: 0) {
                ForEach(-1...1, id: \.self) { relativeIndex in
                    let item = items[wrapped(relativeIndex + pageIndex)]

                    VStack(spacing: 18) {
                        Text(item.emoji)
                            .font(.system(size: min(width * 0.34, 150)))
                            .minimumScaleFactor(0.65)

                        Text(item.task)
                            .font(.system(.title2, design: .serif))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.75)
                            .padding(.horizontal, 28)
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
                withAnimation(.snappy(duration: 0.35)) {
                    pageOffset = (direction == 1 ? -2 * width : 0) + width
                } completion: {
                    var transaction = Transaction()
                    transaction.animation = nil
                    withTransaction(transaction) {
                        pageIndex += direction
                        pageOffset = 0
                        isSettling = false
                    }
                }
            }
    }

    private func settleBack() {
        withAnimation(.smooth(duration: 0.28)) {
            pageOffset = 0
        }
    }
}

// MARK: - Collections View

struct CollectionsView: View {

    @Binding private var collectionsExpanded: Bool
    @State private var expandedIndex: Int?

    private let pageSize: CGSize

    init(
        collectionsExpanded: Binding<Bool> = .constant(false),
        pageSize: CGSize = CGSize(width: 390, height: 844)
    ) {
        self._collectionsExpanded = collectionsExpanded
        self.pageSize = pageSize
    }

    @State private var rotation: Double = 0
    @State private var isDraggingDisk = false
    @State private var lastFingerAngle: Double = 0
    @State private var hapticTrigger = 0
    @State private var lastHapticRidge = 0
    @State private var dismissDrag: CGFloat = 0
    @State private var dismissAxisLocked = false

    var body: some View {
        let geometry = CollectionsGeometry(size: pageSize)
        let anyExpanded = expandedIndex != nil

        ZStack {
            Color.black
                .ignoresSafeArea()

            diskView(geometry: geometry)
                .allowsHitTesting(!anyExpanded)

            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                let isExpanded = expandedIndex == index

                ghostCardView(
                    card: card,
                    index: index,
                    geometry: geometry,
                    isExpanded: isExpanded
                )

                cardView(
                    card: card,
                    index: index,
                    geometry: geometry,
                    isExpanded: isExpanded,
                    anyExpanded: anyExpanded
                )
            }
        }
        .frame(width: pageSize.width, height: pageSize.height)
        .coordinateSpace(.named(CoordinateSpaces.collections))
        .ignoresSafeArea()
        .sensoryFeedback(.selection, trigger: hapticTrigger)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Collections")
        .accessibilityHint("Rotate the disk to browse collections, tap a card to open it")
    }

    // MARK: - Disk

    @ViewBuilder
    private func diskView(geometry: CollectionsGeometry) -> some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.6))

            TickMarksView(
                rotation: rotation,
                radius: geometry.diskRadius,
                tickWidth: geometry.tickWidth,
                tickHeight: geometry.tickHeight
            )
        }
        .frame(width: geometry.diskDiameter, height: geometry.diskDiameter)
        .clipShape(Circle())
        .glassEffect(.regular, in: Circle())
        .position(geometry.diskCenter)
        .geometryGroup()
        .gesture(diskDragGesture(center: geometry.diskCenter, geometry: geometry))
    }

    // MARK: - Card Layout

    private func cardLayout(
        index: Int,
        isExpanded: Bool,
        geometry: CollectionsGeometry
    ) -> CardLayout {
        let angle = radians(
            fromDegrees: rotation + Double(index) * Layout.cardSpacing
        )

        let position = CGPoint(
            x: isExpanded
                ? geometry.size.width / 2
                : geometry.diskCenter.x + geometry.orbitRadius * sin(angle),
            y: isExpanded
                ? geometry.size.height / 2
                : geometry.diskCenter.y - geometry.orbitRadius * cos(angle)
        )

        let size = CGSize(
            width: isExpanded ? geometry.size.width : geometry.cardSize,
            height: isExpanded ? geometry.size.height : geometry.cardSize
        )

        let progress = isExpanded
            ? min(max(-dismissDrag / geometry.dismissThreshold, 0), 1)
            : 0

        let cornerRadius = isExpanded
            ? geometry.screenCornerRadius
                + (geometry.collapsedCornerRadius - geometry.screenCornerRadius) * progress
            : geometry.collapsedCornerRadius

        return CardLayout(
            position: position,
            size: size,
            offsetY: dismissDrag,
            cornerRadius: cornerRadius
        )
    }

    @ViewBuilder
    private func ghostCardView(
        card: Card,
        index: Int,
        geometry: CollectionsGeometry,
        isExpanded: Bool
    ) -> some View {
        let layout = cardLayout(
            index: index,
            isExpanded: isExpanded,
            geometry: geometry
        )

        lowResImage(for: card.imageName)
            .resizable()
            .interpolation(.none)
            .aspectRatio(contentMode: .fill)
            .frame(width: layout.size.width, height: layout.size.height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .fill(.ultraThinMaterial)
                    .opacity(isExpanded ? 1 : 0)
            }
            .offset(y: layout.offsetY)
            .position(layout.position)
            .geometryGroup()
            .animation(Layout.expandAnimation, value: isExpanded)
            .zIndex(0)
    }

    @ViewBuilder
    private func cardView(
        card: Card,
        index: Int,
        geometry: CollectionsGeometry,
        isExpanded: Bool,
        anyExpanded: Bool
    ) -> some View {
        let layout = cardLayout(
            index: index,
            isExpanded: isExpanded,
            geometry: geometry
        )

        let expandedContentOpacity = isExpanded ? 1 - min(max(-dismissDrag / geometry.dismissThreshold, 0), 1) : 0

        ZStack {
            Image(card.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: layout.size.width, height: layout.size.height)
                .clipped()

            ZStack(alignment: isExpanded ? .top : .bottom) {
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .fill(.ultraThinMaterial)
                    .mask(gradientMask(isExpanded: isExpanded, width: layout.size.width))

                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .fill(Color(red: 0.05, green: 0.07, blue: 0.12)
                        .opacity(isExpanded ? 0 : 0.22))
                    .mask(gradientMask(isExpanded: isExpanded, width: layout.size.width))

                InfiniteEmojiCarousel(items: card.items)
                    .id(card.id)
                    .padding(.top, max(48, layout.size.height * 0.12))
                    .padding(.bottom, max(72, layout.size.height * 0.12))
                    .opacity(expandedContentOpacity)
                    .allowsHitTesting(isExpanded)

                Text(card.name)
                    .font(.system(size: isExpanded ? 50 : 25, design: .serif))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .padding(.bottom, isExpanded ? 0 : max(12, layout.size.height * 0.06))
                    .padding(.top, isExpanded ? max(20, layout.size.height * 0.08) : 0)
            }
        }
        .frame(width: layout.size.width, height: layout.size.height)
        .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: layout.cornerRadius)
                .stroke(.white.opacity(isExpanded ? 0 : 0.2), lineWidth: 1)
        }
        .offset(y: layout.offsetY)
        .position(layout.position)
        .geometryGroup()
        .animation(Layout.expandAnimation, value: isExpanded)
        .zIndex(1)
        .allowsHitTesting(!anyExpanded || isExpanded)
        .onTapGesture {
            guard expandedIndex == nil else { return }

            withAnimation(Layout.expandAnimation) {
                expandedIndex = index
                collectionsExpanded = true
            }
        }
        .simultaneousGesture(
            expandDismissGesture(geometry: geometry, isExpanded: isExpanded)
        )
        .accessibilityLabel(card.imageName.replacingOccurrences(of: "Background", with: ""))
        .accessibilityHint(isExpanded ? "Swipe up to dismiss" : "Double tap to open")
    }

    private func gradientMask(isExpanded: Bool, width: CGFloat) -> some View {
        RadialGradient(
            stops: [
                .init(color: isExpanded ? .black : .clear, location: 0.0),
                .init(color: .black, location: 1.0)
            ],
            center: UnitPoint(x: 0.5, y: 0.0),
            startRadius: 0,
            endRadius: width * 0.9
        )
    }

    // MARK: - Expand / Dismiss

    private func expandDismissGesture(
        geometry: CollectionsGeometry,
        isExpanded: Bool
    ) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                guard isExpanded else { return }

                guard dismissAxisLocked
                    || abs(value.translation.height) > abs(value.translation.width)
                else {
                    dismissDrag = 0
                    return
                }

                dismissAxisLocked = true
                dismissDrag = value.translation.height < 0 ? value.translation.height : 0
            }
            .onEnded { value in
                guard isExpanded, dismissAxisLocked else {
                    dismissAxisLocked = false
                    dismissDrag = 0
                    return
                }

                defer { dismissAxisLocked = false }

                let shouldDismiss =
                    value.translation.height < -geometry.dismissThreshold
                    || value.velocity.height < -Layout.dismissVelocity

                withAnimation(shouldDismiss ? Layout.dismissAnimation : Layout.snapBackAnimation) {
                    if shouldDismiss {
                        expandedIndex = nil
                        collectionsExpanded = false
                    }
                    dismissDrag = 0
                }
            }
    }

    // MARK: - Disk Gesture

    private func diskDragGesture(
        center: CGPoint,
        geometry: CollectionsGeometry
    ) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(CoordinateSpaces.collections))
            .onChanged { value in
                guard expandedIndex == nil else { return }

                let dx = value.location.x - center.x
                let dy = value.location.y - center.y
                guard hypot(dx, dy) >= geometry.diskDeadZone else { return }

                let currentAngle = angle(of: value.location, around: center)

                guard isDraggingDisk else {
                    isDraggingDisk = true
                    lastFingerAngle = currentAngle
                    lastHapticRidge = currentHapticRidge()
                    return
                }

                rotation += normalizedAngleDelta(from: lastFingerAngle, to: currentAngle)
                lastFingerAngle = currentAngle
                updateHapticRidge()
            }
            .onEnded { value in
                defer { isDraggingDisk = false }

                guard expandedIndex == nil else { return }

                guard isDraggingDisk else {
                    snapToNearest()
                    return
                }

                let current = value.location
                let predicted = value.predictedEndLocation

                guard hypot(current.x - center.x, current.y - center.y) >= geometry.diskDeadZone,
                      hypot(predicted.x - center.x, predicted.y - center.y) >= geometry.diskDeadZone
                else {
                    snapToNearest()
                    return
                }

                let predictedRotation = rotation + normalizedAngleDelta(
                    from: angle(of: current, around: center),
                    to: angle(of: predicted, around: center)
                )

                animateToCard(nearestCardIndex(to: predictedRotation))
            }
    }

    // MARK: - Rotation / Snapping

    private func nearestCardIndex(to rotation: Double) -> Int {
        Int(round(-rotation / Layout.cardSpacing))
    }

    private func snapToNearest() {
        animateToCard(nearestCardIndex(to: rotation))
    }

    private func animateToCard(_ target: Int) {
        var transaction = Transaction(
            animation: .smooth(duration: Layout.snapSpring.duration)
        )
        transaction.tracksVelocity = false

        withTransaction(transaction) {
            rotation = Double(-target) * Layout.cardSpacing
        }

        updateHapticRidge(to: target)
    }

    // MARK: - Haptics

    private func currentHapticRidge() -> Int {
        Int(round(-rotation / Layout.cardSpacing))
    }

    private func updateHapticRidge() {
        let ridge = currentHapticRidge()
        guard ridge != lastHapticRidge else { return }
        hapticTrigger += abs(ridge - lastHapticRidge)
        lastHapticRidge = ridge
    }

    private func updateHapticRidge(to target: Int) {
        let delta = target - lastHapticRidge
        guard delta != 0 else { return }
        hapticTrigger += abs(delta)
        lastHapticRidge = target
    }
}

// MARK: - Preview

#Preview {
    CollectionsView()
}
