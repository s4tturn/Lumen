import SwiftUI

// MARK: - Card Expand Environment Key

struct CardExpandKey: EnvironmentKey {
    static let defaultValue: (Bool) -> Void = { _ in }
}

extension EnvironmentValues {
    var onCardExpand: (Bool) -> Void {
        get { self[CardExpandKey.self] }
        set { self[CardExpandKey.self] = newValue }
    }
}

// MARK: - Model

struct CollectionItem: Equatable, Identifiable {
    let id = UUID()
    let emoji: String
    let name: String
}

struct Collection: Identifiable {
    let id = UUID()
    let name: String
    let color: Color
    let items: [CollectionItem]
}

// MARK: - Sample Data

private let collections: [Collection] = [
    Collection(name: "Dawn", color: Color(red: 1, green: 0.76, blue: 0.46), items: [
        .init(emoji: "☀️", name: "Sun"),
        .init(emoji: "🌅", name: "Sunrise"),
        .init(emoji: "🌄", name: "Morning"),
        .init(emoji: "🐦", name: "Bird"),
        .init(emoji: "🌻", name: "Sunflower"),
        .init(emoji: "☁️", name: "Cloud"),
        .init(emoji: "🌤️", name: "Clear Sky"),
        .init(emoji: "🦋", name: "Butterfly"),
    ]),
    Collection(name: "Ocean", color: Color(red: 0.46, green: 0.76, blue: 1), items: [
        .init(emoji: "🌊", name: "Wave"),
        .init(emoji: "🐚", name: "Shell"),
        .init(emoji: "🐠", name: "Fish"),
        .init(emoji: "🐙", name: "Octopus"),
        .init(emoji: "⚓", name: "Anchor"),
        .init(emoji: "🐳", name: "Whale"),
        .init(emoji: "🪸", name: "Coral"),
        .init(emoji: "🚢", name: "Sailboat"),
    ]),
    Collection(name: "Dusk", color: Color(red: 0.76, green: 0.46, blue: 1), items: [
        .init(emoji: "🌙", name: "Moon"),
        .init(emoji: "🌌", name: "Galaxy"),
        .init(emoji: "🦉", name: "Owl"),
        .init(emoji: "🌠", name: "Shooting Star"),
        .init(emoji: "🍂", name: "Maple Leaf"),
        .init(emoji: "🕯️", name: "Candle"),
        .init(emoji: "🌆", name: "Sunset"),
        .init(emoji: "🦇", name: "Bat"),
    ]),
    Collection(name: "Moss", color: Color(red: 0.46, green: 1, blue: 0.66), items: [
        .init(emoji: "🌿", name: "Fern"),
        .init(emoji: "🍀", name: "Clover"),
        .init(emoji: "🌱", name: "Sprout"),
        .init(emoji: "🐸", name: "Frog"),
        .init(emoji: "🪨", name: "Stone"),
        .init(emoji: "🍃", name: "Leaf"),
        .init(emoji: "🌳", name: "Tree"),
        .init(emoji: "🐛", name: "Caterpillar"),
    ]),
    Collection(name: "Rose", color: Color(red: 1, green: 0.46, blue: 0.66), items: [
        .init(emoji: "🌹", name: "Rose"),
        .init(emoji: "💐", name: "Bouquet"),
        .init(emoji: "🌸", name: "Blossom"),
        .init(emoji: "🦩", name: "Flamingo"),
        .init(emoji: "🍓", name: "Strawberry"),
        .init(emoji: "🎀", name: "Ribbon"),
        .init(emoji: "🕊️", name: "Dove"),
        .init(emoji: "🩷", name: "Pink Heart"),
    ]),
    Collection(name: "Lavender", color: Color(red: 0.66, green: 0.66, blue: 1), items: [
        .init(emoji: "💜", name: "Purple Heart"),
        .init(emoji: "🦋", name: "Butterfly"),
        .init(emoji: "🌾", name: "Lavender"),
        .init(emoji: "🫐", name: "Blueberry"),
        .init(emoji: "💎", name: "Crystal"),
        .init(emoji: "🌙", name: "Moon"),
        .init(emoji: "✨", name: "Sparkles"),
        .init(emoji: "🎵", name: "Music"),
    ]),
    Collection(name: "Amber", color: Color(red: 1, green: 0.6, blue: 0.2), items: [
        .init(emoji: "🔥", name: "Fire"),
        .init(emoji: "🍂", name: "Maple Leaf"),
        .init(emoji: "🧡", name: "Orange Heart"),
        .init(emoji: "🐝", name: "Bee"),
        .init(emoji: "🍯", name: "Honey"),
        .init(emoji: "🌾", name: "Wheat"),
        .init(emoji: "🦊", name: "Fox"),
        .init(emoji: "🪵", name: "Wood"),
    ]),
    Collection(name: "Silver", color: Color(red: 0.75, green: 0.78, blue: 0.82), items: [
        .init(emoji: "❄️", name: "Snowflake"),
        .init(emoji: "🌫️", name: "Fog"),
        .init(emoji: "🪶", name: "Feather"),
        .init(emoji: "🦢", name: "Swan"),
        .init(emoji: "🌙", name: "Moon"),
        .init(emoji: "✨", name: "Star"),
        .init(emoji: "🐈", name: "Cat"),
        .init(emoji: "🩶", name: "Gray Heart"),
    ]),
]

/// Wraps any index into the collections array cyclically.
private func getCollection(at index: Int) -> Collection {
    collections[((index % collections.count) + collections.count) % collections.count]
}

// MARK: - Animation Springs

/// Shared spring constants using Apple's perceptual duration + bounce API (WWDC2023).
extension Animation {
    /// Snappy settle for turntable snap-to — subtle bounce for premium feel.
    static let cardSnap    = Animation.spring(duration: 0.4,  bounce: 0.05)
    /// Tap-based expand/collapse — smooth with just a hint of life.
    static let cardExpand  = Animation.spring(duration: 0.4,  bounce: 0.05)
    /// Gesture-driven dismiss — bouncy to respect throw velocity.
    static let cardDismiss = Animation.spring(duration: 0.35, bounce: 0.15)
    /// Threshold cancellation — no bounce, just friction.
    static let cardCancel  = Animation.spring(duration: 0.3,  bounce: 0)
    /// Item swipe settling — interpolating spring for physical feel.
    static let itemSwipe   = Animation.interpolatingSpring(mass: 0.8, stiffness: 260, damping: 24)
}

// MARK: - Card Layout

/// Pure-data descriptor for a single card's visual state.
/// Computing this once per card per frame is cheaper than scattering math in ViewBuilder.
private struct CardLayout: Equatable {
    let index: Int
    let scale: CGFloat
    let opacity: Double
    let rotation: Double
    let offsetX: CGFloat
    let offsetY: CGFloat
    let zIndex: Double
}

/// Derives all 5 cards' layouts from the current turntable position.
/// - Parameter fractional: negative rotation / 45° — the continuous "rotor position".
/// - Parameter cardSize: width of a single card.
/// - Parameter spacing: center-to-center distance between adjacent cards.
/// - Returns: Array of 5 CardLayouts, ordered from leftmost to rightmost.
private func cardLayouts(
    fractional: Double,
    cardSize: CGFloat,
    spacing: CGFloat,
    expandedIndex: Int?
) -> [CardLayout] {
    let current = Int(round(fractional))
    let radius = UIConstants.Collections.visibleCardRadius

    return (current - radius ... current + radius).map { i in
        let delta = Double(i) - fractional
        let d = abs(delta)
        let isExpanded = i == expandedIndex
        // Parallax: cards closer to center are bigger, more opaque, less rotated.
        let scale: CGFloat = max(0.8, 1 - 0.12 * d)
        let opacity: Double = max(0, 1 - 0.2 * d)
        let rotation: Double = delta * 10
        let offsetX = CGFloat(delta) * spacing
        let offsetY = CGFloat(d * d * 16)
        // Expanded card sits on top; everything else uses natural z-order by distance.
        let zIndex: Double = isExpanded ? 2 : (1 - d * 0.1)
        return CardLayout(
            index: i, scale: scale, opacity: opacity, rotation: rotation,
            offsetX: offsetX, offsetY: offsetY, zIndex: zIndex
        )
    }
}

// MARK: - CardView

private struct CardView: View, Equatable {
    let layout: CardLayout
    let size: CGFloat
    let expanded: Bool
    let parentOffsetY: CGFloat
    let dismissOffset: CGSize
    let dismissProgress: CGFloat
    let swipeOffset: CGFloat
    let itemIndex: Int

    static func == (lhs: CardView, rhs: CardView) -> Bool {
        lhs.layout == rhs.layout
            && lhs.size == rhs.size
            && lhs.expanded == rhs.expanded
            && lhs.parentOffsetY == rhs.parentOffsetY
            && lhs.dismissOffset == rhs.dismissOffset
            && lhs.dismissProgress == rhs.dismissProgress
            && lhs.swipeOffset == rhs.swipeOffset
            && lhs.itemIndex == rhs.itemIndex
    }

    var body: some View {
        let dragging = expanded && dismissProgress > 0
        let cornerRadius = UIConstants.General.screenCornerRadius

        let scale: CGFloat = dragging
            ? 1 - dismissProgress * 0.03
            : expanded ? 1 : layout.scale

        let offsetX: CGFloat = expanded ? dismissOffset.width : layout.offsetX
        let offsetY: CGFloat = expanded
            ? -parentOffsetY + dismissOffset.height
            : layout.offsetY

        let contentBlur: CGFloat = expanded ? dismissProgress * 10 : 10
        let contentOpacity: Double = expanded ? 1 : 0

        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(getCollection(at: layout.index).color)
            .overlay(
                ExpandedCollectionView(
                    index: layout.index,
                    itemIndex: itemIndex,
                    swipeOffset: swipeOffset
                )
                .opacity(contentOpacity)
                .blur(radius: contentBlur)
            )
            .frame(
                width: expanded ? UIConstants.General.screenWidth : size,
                height: expanded ? UIConstants.General.screenHeight : size
            )
            .scaleEffect(scale)
            .opacity(expanded ? 1 : layout.opacity)
            .offset(x: offsetX, y: offsetY)
            .rotationEffect(.degrees(expanded ? 0 : layout.rotation))
            .edgesIgnoringSafeArea(.all)
    }
}

// MARK: - ExpandedCollectionView

/// Renders all collection items simultaneously with physical sliding.
/// Uses circular wrapping so items loop infinitely.
/// The parent owns the gesture; this view only renders state.
private struct ExpandedCollectionView: View {
    let index: Int
    let itemIndex: Int
    let swipeOffset: CGFloat

    private var collection: Collection { getCollection(at: index) }

    var body: some View {
        let items = collection.items
        let count = items.count

        GeometryReader { geo in
            let pw = geo.size.width
            ZStack {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    let raw = i - itemIndex
                    let wrapped = raw - Int(round(Double(raw) / Double(count))) * count
                    let offset = CGFloat(wrapped) * pw + swipeOffset
                    let dist = abs(offset) / pw
                    // Items within 1.5 screens are visible; beyond that hidden.
                    let visible = dist < 1.5
                    let blurRadius: CGFloat = visible ? min(10, dist * 10) : 0
                    let opacity: Double = visible ? 1 : 0

                    VStack(spacing: 30) {
                        Text(item.emoji)
                            .font(.system(size: 180))
                        Text(item.name)
                            .font(.system(size: 32, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .frame(width: pw, height: geo.size.height)
                    .offset(x: offset)
                    .blur(radius: blurRadius)
                    .opacity(opacity)
                }
            }
            .clipped()
            .overlay(alignment: .top) {
                Text(collection.name)
                    .font(.system(size: 40, weight: .semibold, design: .serif))
                    .foregroundColor(.white)
                    .padding(.top, 90)
            }
        }
    }
}

// MARK: - TickMarksView

private struct TickMarksView: View {
    let rotation: Double
    let radius: CGFloat

    var body: some View {
        let count = collections.count
        let step = 360.0 / Double(count)
        let tW = UIConstants.Collections.tickWidth
        let tH = UIConstants.Collections.tickHeight

        ZStack {
            ForEach(0..<count, id: \.self) { i in
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white, collections[i].color],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: tW, height: tH)
                    .mask(
                        LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom)
                    )
                    .offset(y: -radius + tH + 2)
                    .rotationEffect(.degrees(Double(i) * step))
            }
        }
        .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Gestures

// Using Apple's gesture composition pattern: each gesture is a standalone method
// on the view that owns the mutable state.

// MARK: - CollectionsView

struct CollectionsView: View {
    @State private var rotation = 0.0
    @State private var dragOffset = 0.0
    @State private var velocity = 0.0
    @State private var isDragging = false
    @State private var lastAngle = 0.0
    @State private var lastTimestamp = Date()
    @State private var lastHapticRidge = 0
    @State private var expandedIndex: Int? = nil
    @State private var animatingInIndex: Int? = nil
    @State private var animatingOutIndex: Int? = nil
    @State private var dismissOffset: CGSize = .zero
    @State private var itemSwipeOffset: CGFloat = 0
    @State private var itemIndex: Int = 0
    @State private var expandedDragLock: Bool? = nil
    @Environment(\.onCardExpand) private var onCardExpand

    /// True whenever the expanded card is animating in, fully expanded, or animating out.
    /// Controls primary card elevation (zIndex 4 vs 2) and ghost card visibility.
    private var isPrimaryElevated: Bool {
        expandedIndex != nil || animatingInIndex != nil || animatingOutIndex != nil
    }

    /// Shared haptic generator — created once per view instance (Apple HIG).
    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let center = CGPoint(x: w / 2, y: h + 0.2 * w)
            let totalAngle = rotation + dragOffset
            let fractional = -totalAngle / UIConstants.Collections.cardAngle
            let cardSize = w * UIConstants.Collections.cardWidthRatio
            let spacing = cardSize * (1 + UIConstants.Collections.cardSpacingRatio)
            let cardsOffsetY = h / 2 - 1.15 * w - 30
            let layouts = cardLayouts(
                fractional: fractional,
                cardSize: cardSize,
                spacing: spacing,
                expandedIndex: expandedIndex
            )

            ZStack {
                Color.black.ignoresSafeArea()

                // ── Carousel cards (zIndex 1) ──
                ForEach(layouts, id: \.index) { layout in
                    let isExpanded = layout.index == expandedIndex
                    let isFocused = abs(Double(layout.index) - fractional) < 0.5
                    // The "primary" card is the one being expanded or dismissed.
                    // During dismiss, expandedIndex is nil but animatingOutIndex retains the card.
                    let isPrimary = layout.index == (expandedIndex ?? animatingInIndex ?? animatingOutIndex)

                    CardView(
                        layout: layout,
                        size: cardSize,
                        expanded: isExpanded,
                        parentOffsetY: cardsOffsetY,
                        dismissOffset: isExpanded ? dismissOffset : .zero,
                        dismissProgress: isExpanded ? dismissProgress() : 0,
                        swipeOffset: isExpanded ? itemSwipeOffset : 0,
                        itemIndex: itemIndex
                    )
                    .equatable()
                    .blur(radius: expandedIndex != nil && !isExpanded ? 10 : 0)
                    .allowsHitTesting(isExpanded || isFocused)
                    .highPriorityGesture(
                        cardFlickGesture(),
                        including: (!isExpanded && isFocused) ? .all : .none
                    )
                    .simultaneousGesture(
                        tapGesture(index: layout.index, expanded: isExpanded, distance: abs(Double(layout.index) - fractional))
                    )
                    .simultaneousGesture(
                        expandedDragGesture(),
                        including: isExpanded ? .all : .none
                    )
                    // Layer 1: non-primary (other carousel cards)
                    // Layer 2: primary at rest (not elevated)
                    // Layer 4: primary elevated (animating in, expanded, or animating out)
                    .zIndex(isPrimary ? (isPrimaryElevated ? 4 : 2) : 1)
                    .offset(y: cardsOffsetY)
                }

                // ── Ghost card (zIndex 2, between non-primary cards and turntable) ──
                // Mirrors the primary card exactly. Visible only while the primary is elevated
                // (zIndex 4), providing visual continuity behind the turntable (zIndex 3).
                // Appears/disappears instantly — no fades or animations.
                if isPrimaryElevated, let gi = expandedIndex ?? animatingInIndex ?? animatingOutIndex {
                    makeCardView(
                        index: gi,
                        fractional: fractional,
                        cardSize: cardSize,
                        spacing: spacing,
                        cardsOffsetY: cardsOffsetY
                    )
                    .allowsHitTesting(false)
                    .transition(.identity)
                    .offset(y: cardsOffsetY)
                    .zIndex(2)
                }

                // ── Layer 3: Turntable ──
                turntableLayer(radius: w, totalAngle: totalAngle, center: center)
                    .allowsHitTesting(expandedIndex == nil)
                    .blur(radius: expandedIndex != nil ? 10 : 0)
                    .zIndex(3)
            }
            .clipped()
        }
        .ignoresSafeArea()
        .onChange(of: expandedIndex) { _, index in
            onCardExpand(index != nil)
            if index != nil {
                itemIndex = 0
                itemSwipeOffset = 0
                dismissOffset = .zero
                expandedDragLock = nil
            }
        }
    }

    /// Shared CardView builder used by the ghost card.
    private func makeCardView(index: Int, fractional: Double, cardSize: CGFloat, spacing: CGFloat, cardsOffsetY: CGFloat) -> CardView {
        let delta  = Double(index) - fractional
        let d      = abs(delta)
        let expanded = index == expandedIndex

        let dismissDistance: CGFloat = expanded
            ? sqrt(dismissOffset.width * dismissOffset.width + dismissOffset.height * dismissOffset.height)
            : 0
        let dismissProgress: CGFloat = expanded
            ? min(1, max(0, dismissDistance / UIConstants.Collections.dismissFullDistance))
            : 0

        return CardView(
            layout: CardLayout(
                index: index,
                scale: max(0.8, 1 - 0.12 * d),
                opacity: max(0, 1 - 0.2 * d),
                rotation: delta * 10,
                offsetX: CGFloat(delta) * spacing,
                offsetY: CGFloat(d * d * 16),
                zIndex: 0
            ),
            size: cardSize,
            expanded: expanded,
            parentOffsetY: cardsOffsetY,
            dismissOffset: expanded ? dismissOffset : .zero,
            dismissProgress: dismissProgress,
            swipeOffset: expanded ? itemSwipeOffset : 0,
            itemIndex: itemIndex
        )
    }

    // MARK: - Dismiss Progress

    private func dismissProgress() -> CGFloat {
        guard expandedIndex != nil else { return 0 }
        let dist = sqrt(dismissOffset.width * dismissOffset.width + dismissOffset.height * dismissOffset.height)
        return min(1, max(0, dist / UIConstants.Collections.dismissFullDistance))
    }

    // MARK: - Tap Gesture

    private func tapGesture(index: Int, expanded: Bool, distance: Double) -> some Gesture {
        TapGesture()
            .onEnded { _ in
                guard !expanded, distance < 0.5, dismissOffset == .zero else { return }
                // Show ghost at carousel position one frame before expand animation.
                animatingInIndex = index
                DispatchQueue.main.async {
                    withAnimation(.cardExpand) {
                        expandedIndex = index
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    animatingInIndex = nil
                }
            }
    }

    // MARK: - Card Flick Gesture

    private func cardFlickGesture() -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                let sign: Double
                if value.velocity.width > 300 { sign = 1 }
                else if value.velocity.width < -300 { sign = -1 }
                else { return }
                withAnimation(.cardSnap) {
                    rotation += sign * UIConstants.Collections.cardAngle
                    dragOffset = 0
                }
                fireHaptics(to: Int(round(-rotation / UIConstants.Collections.cardAngle)))
            }
    }

    // MARK: - Expanded Drag Gesture (unified swipe + dismiss)

    private func expandedDragGesture() -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                // Lock direction once movement exceeds 10pt — never changes mid-gesture.
                if expandedDragLock == nil {
                    let dx = abs(value.translation.width)
                    let dy = abs(value.translation.height)
                    if dx > 10 || dy > 10 {
                        expandedDragLock = dx > dy * 1.5
                    }
                }
                guard let locked = expandedDragLock else { return }
                if locked {
                    itemSwipeOffset = value.translation.width
                } else {
                    dismissOffset = value.translation
                }
            }
            .onEnded { value in
                guard let locked = expandedDragLock else { return }
                expandedDragLock = nil
                let w = UIConstants.General.screenWidth

                if locked {
                    handleItemSwipe(value: value, screenWidth: w)
                } else {
                    handleDismiss(value: value)
                }
            }
    }

    // MARK: - Item Swipe

    private func handleItemSwipe(value: DragGesture.Value, screenWidth w: CGFloat) {
        guard let expanded = expandedIndex else { return }
        let count = getCollection(at: expanded).items.count
        let velocity = value.predictedEndTranslation.width - value.translation.width
        let threshold = w * UIConstants.Collections.itemSwipeThreshold

        if value.translation.width < -threshold || velocity < -UIConstants.Collections.itemSwipeVelocity {
            let newIndex = (itemIndex + 1) % count
            itemSwipeOffset = w + itemSwipeOffset
            itemIndex = newIndex
            withAnimation(.itemSwipe) { itemSwipeOffset = 0 }
        } else if value.translation.width > threshold || velocity > UIConstants.Collections.itemSwipeVelocity {
            let newIndex = (itemIndex - 1 + count) % count
            itemSwipeOffset = -w + itemSwipeOffset
            itemIndex = newIndex
            withAnimation(.itemSwipe) { itemSwipeOffset = 0 }
        } else {
            withAnimation(.itemSwipe) { itemSwipeOffset = 0 }
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
    }

    // MARK: - Dismiss

    private func handleDismiss(value: DragGesture.Value) {
        let verticalDistance = abs(dismissOffset.height)
        let verticalVelocity = abs(value.velocity.height)

        if verticalDistance > UIConstants.Collections.dismissDistance
            || verticalVelocity > UIConstants.Collections.dismissVelocity {
            animatingOutIndex = expandedIndex
            withAnimation(.cardDismiss) {
                expandedIndex = nil
                dismissOffset = .zero
                itemSwipeOffset = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                animatingOutIndex = nil
            }
        } else {
            withAnimation(.cardCancel) {
                dismissOffset = .zero
                itemSwipeOffset = 0
            }
        }
    }

    // MARK: - Turntable

    private func turntableLayer(radius: CGFloat, totalAngle: Double, center: CGPoint) -> some View {
        ZStack {
            Circle().fill(.black.opacity(0.6))
            TickMarksView(rotation: totalAngle, radius: radius)
        }
        .frame(width: radius * 2, height: radius * 2)
        .clipShape(Circle())
        .glassEffect(.regular, in: Circle())
        .position(center)
        .simultaneousGesture(diskDragGesture(center: center))
    }

    // MARK: - Disk Drag Gesture

    private func diskDragGesture(center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let dx = value.location.x - center.x
                let dy = value.location.y - center.y
                let dist = sqrt(dx * dx + dy * dy)

                guard dist >= UIConstants.Collections.diskDeadZone else {
                    if isDragging {
                        isDragging = false
                        snapToNearest()
                    }
                    return
                }

                let angle = atan2(dy, dx) * 180 / .pi
                let now = Date()

                guard isDragging else {
                    isDragging = true
                    lastAngle = angle
                    lastTimestamp = now
                    velocity = 0
                    lastHapticRidge = Int(floor(-totalRotation / UIConstants.Collections.cardAngle))
                    return
                }

                var diff = angle - lastAngle
                if diff > 180 { diff -= 360 }
                if diff < -180 { diff += 360 }

                dragOffset += diff

                let ridge = Int(floor(-totalRotation / UIConstants.Collections.cardAngle))
                let delta = ridge - lastHapticRidge
                if delta != 0 {
                    haptic.prepare()
                    for _ in 0..<abs(delta) { haptic.impactOccurred(intensity: 1) }
                    lastHapticRidge = ridge
                }

                let dt = now.timeIntervalSince(lastTimestamp)
                if dt > 0 { velocity = velocity * 0.7 + (diff / dt) * 0.3 }

                lastAngle = angle
                lastTimestamp = now
            }
            .onEnded { _ in
                isDragging = false
                defer { velocity = 0 }
                guard abs(velocity) > UIConstants.Collections.diskMomentumThreshold else {
                    return snapToNearest()
                }
                // Asymmetric momentum: positive velocity adds -2 steps, negative adds +1.
                let step = velocity > 0 ? -2 : 1
                let target = Int(round(-totalRotation / UIConstants.Collections.cardAngle)) + step
                animateTo(target)
            }
    }

    /// Convenience: total rotation including live drag.
    private var totalRotation: Double { rotation + dragOffset }

    // MARK: - Helpers

    private func snapToNearest() {
        animateTo(Int(round(-totalRotation / UIConstants.Collections.cardAngle)))
    }

    private func animateTo(_ target: Int) {
        withAnimation(.cardSnap) {
            rotation = Double(-target) * UIConstants.Collections.cardAngle
            dragOffset = 0
        }
        fireHaptics(to: target)
    }

    private func fireHaptics(to target: Int) {
        guard target != lastHapticRidge else { return }
        let delta = abs(target - lastHapticRidge)
        haptic.prepare()
        for _ in 0..<delta { haptic.impactOccurred(intensity: 1) }
        lastHapticRidge = target
    }
}

#Preview {
    CollectionsView()
}
