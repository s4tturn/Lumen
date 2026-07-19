import SwiftUI

// MARK: - Model

struct Collection: Identifiable {
    let id = UUID()
    let name: String
    let color: Color
}

private let collections: [Collection] = [
    Collection(name: "Dawn", color: Color(red: 1, green: 0.76, blue: 0.46)),
    Collection(name: "Ocean", color: Color(red: 0.46, green: 0.76, blue: 1)),
    Collection(name: "Dusk", color: Color(red: 0.76, green: 0.46, blue: 1)),
    Collection(name: "Moss", color: Color(red: 0.46, green: 1, blue: 0.66)),
    Collection(name: "Rose", color: Color(red: 1, green: 0.46, blue: 0.66)),
    Collection(name: "Lavender", color: Color(red: 0.66, green: 0.66, blue: 1)),
    Collection(name: "Amber", color: Color(red: 1, green: 0.6, blue: 0.2)),
    Collection(name: "Silver", color: Color(red: 0.75, green: 0.78, blue: 0.82)),
]

private func collection(at index: Int) -> Collection {
    collections[((index % collections.count) + collections.count) % collections.count]
}

// MARK: - CardView

private struct CardView: View, Equatable {
    let index: Int
    let size: CGFloat
    let scale: CGFloat
    let opacity: Double
    let rotation: Double
    let horizontalOffset: CGFloat
    let verticalOffset: CGFloat
    let expanded: Bool
    let parentOffsetY: CGFloat
    let dismissOffset: CGSize
    let dismissProgress: CGFloat

    var body: some View {
        // During a drag-to-dismiss, subtle visual feedback based on progress,
        // but position follows the finger exactly for a direct‑manipulation feel.
        let dragging = expanded && dismissProgress > 0

        // Corner radius transitions gently toward 28 (max 30% of the way)
        let cornerRadiusRange = UIConstants.General.screenCornerRadius - 28
        let currentCornerRadius: CGFloat = dragging
            ? UIConstants.General.screenCornerRadius - dismissProgress * cornerRadiusRange * 0.3
            : expanded ? UIConstants.General.screenCornerRadius : 28

        // Very subtle shrink (max ~3%) so the card doesn't feel rigid
        let currentScale: CGFloat = dragging
            ? 1.0 - dismissProgress * 0.03
            : (expanded ? 1.0 : scale)

        // X and Y follow the finger exactly — no interpolation toward carousel position
        let currentOffsetX: CGFloat = expanded ? dismissOffset.width : horizontalOffset
        let currentOffsetY: CGFloat = expanded
            ? -parentOffsetY + dismissOffset.height
            : verticalOffset

        RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
            .fill(collection(at: index).color)
            .frame(width: expanded ? UIConstants.General.screenWidth : size,
                   height: expanded ? UIConstants.General.screenHeight : size)
            .scaleEffect(currentScale)
            .opacity(expanded ? 1.0 : opacity)
            .offset(x: currentOffsetX, y: currentOffsetY)
            .rotationEffect(.degrees(expanded ? 0 : rotation))
            .edgesIgnoringSafeArea(.all)
    }
}

// MARK: - TickMarksView

private struct TickMarksView: View {
    let rotation: Double
    let radius: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<collections.count, id: \.self) { i in
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white, collections[i].color],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 7, height: 40)
                    .mask(
                        LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom)
                    )
                    .offset(y: -radius + 42)
                    .rotationEffect(.degrees(Double(i) * 360 / Double(collections.count)))
            }
        }
        .rotationEffect(.degrees(rotation))
    }
}

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
    @State private var animatingOutIndex: Int? = nil
    @State private var dismissOffset: CGSize = .zero

    // ── Layout Constants ──

    private static let cardAngle          = 45.0
    private static let dismissThreshold: CGFloat            = 80
    private static let dismissVelocityThreshold: CGFloat    = 300
    private static let dismissFullProgressDistance: CGFloat = 150

    // ── Animation Springs ──

    /// Snappy spring for turntable snap-to, with a subtle bounce for a premium feel.
    private static let snapSpring = Animation.spring(duration: 0.4, bounce: 0.05)

    /// Responsive spring for expand / collapse via tap.
    private static let transitionSpring = Animation.interactiveSpring(response: 0.4, dampingFraction: 0.8)

    /// Bouncy dismiss – respects gesture momentum (WWDC 2023 "Animate with springs").
    private static let dismissSpring = Animation.spring(duration: 0.35, bounce: 0.15)

    /// No‑bounce cancel for when the drag doesn't meet the threshold.
    private static let cancelSpring = Animation.spring(duration: 0.3, bounce: 0)

    // ── Haptics ──

    /// Shared generator – created once and reused (Apple HIG: avoid creating generators repeatedly).
    private static let haptic = UIImpactFeedbackGenerator(style: .medium)

    // ── Body ──

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let center    = CGPoint(x: w / 2, y: h + 0.2 * w)
            let total     = rotation + dragOffset
            let fractional = -total / Self.cardAngle
            let current   = Int(round(fractional))
            let cardSize  = w * 0.7
            let spacing   = cardSize + 20
            let cardsOffsetY = h / 2 - 1.15 * w - 30

            ZStack {
                Color.black.ignoresSafeArea()

                // Dynamic range (5 cards) shifts as the turntable rotates,
                // creating infinite scroll. collection(at:) wraps indices
                // modulo 8 so cards cycle indefinitely.
                ForEach((current - 2)...(current + 2), id: \.self) { i in
                    bottomCard(
                        index: i,
                        fractional: fractional,
                        cardSize: cardSize,
                        spacing: spacing,
                        cardsOffsetY: cardsOffsetY
                    )
                }

                turntableLayer(radius: w, totalAngle: total, center: center)
                    .allowsHitTesting(expandedIndex == nil)
                    .zIndex(1)
            }
            .clipped()
        }
        .ignoresSafeArea()
    }

    // MARK: - Card Factory

    /// Shared CardView builder used by `bottomCard`.
    private func makeCardView(index: Int, fractional: Double, cardSize: CGFloat, spacing: CGFloat, cardsOffsetY: CGFloat) -> CardView {
        let delta  = Double(index) - fractional
        let d      = abs(delta)
        let expanded = index == expandedIndex

        let dismissDistance: CGFloat = expanded
            ? sqrt(dismissOffset.width * dismissOffset.width + dismissOffset.height * dismissOffset.height)
            : 0
        let dismissProgress: CGFloat = expanded
            ? min(1, max(0, dismissDistance / Self.dismissFullProgressDistance))
            : 0

        return CardView(
            index: index,
            size: cardSize,
            scale: max(0.8, 1 - 0.12 * d),
            opacity: max(0, 1 - 0.2 * d),
            rotation: delta * 10,
            horizontalOffset: CGFloat(delta) * spacing,
            verticalOffset: CGFloat(d * d * 16),
            expanded: expanded,
            parentOffsetY: cardsOffsetY,
            dismissOffset: expanded ? dismissOffset : .zero,
            dismissProgress: dismissProgress
        )
    }

    // MARK: - Bottom Card

    /// The interactive card that sits below the turntable.
    private func bottomCard(index: Int, fractional: Double, cardSize: CGFloat, spacing: CGFloat, cardsOffsetY: CGFloat) -> some View {
        let delta  = Double(index) - fractional
        let d      = abs(delta)
        let isFocused = d < 0.5
        let expanded   = index == expandedIndex

        return makeCardView(
            index: index,
            fractional: fractional,
            cardSize: cardSize,
            spacing: spacing,
            cardsOffsetY: cardsOffsetY
        )
        .equatable()
        .allowsHitTesting(expanded || isFocused)
        .highPriorityGesture(cardFlickGesture(), including: (!expanded && isFocused) ? .all : .none)
        .simultaneousGesture(tapGesture(index: index, expanded: expanded, distance: d))
        .simultaneousGesture(dismissDragGesture(), including: expanded ? .all : .none)
        .zIndex(index == expandedIndex ? 2 : (index == animatingOutIndex ? 1 : 0))
        .offset(y: cardsOffsetY)
    }

    // MARK: Tap Gesture

    private func tapGesture(index: Int, expanded: Bool, distance: Double) -> some Gesture {
        TapGesture()
            .onEnded { _ in
                guard dismissOffset == .zero else { return }
                if expanded {
                    animatingOutIndex = index
                    withAnimation(Self.transitionSpring) {
                        expandedIndex = nil
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        animatingOutIndex = nil
                    }
                } else if distance < 0.5 {
                    withAnimation(Self.transitionSpring) {
                        expandedIndex = index
                    }
                }
            }
    }

    // MARK: Turntable

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

    // MARK: Card Flick Gesture

    private func cardFlickGesture() -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                let sign: Double
                if value.velocity.width > 300 { sign = 1 }
                else if value.velocity.width < -300 { sign = -1 }
                else { return }
                withAnimation(Self.snapSpring) {
                    rotation += sign * Self.cardAngle
                    dragOffset = 0
                }
                fireHaptics(to: Int(round(-rotation / Self.cardAngle)))
            }
    }

    // MARK: Dismiss Gesture

    private func dismissDragGesture() -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                dismissOffset = value.translation
            }
            .onEnded { value in
                let distance = sqrt(dismissOffset.width * dismissOffset.width + dismissOffset.height * dismissOffset.height)
                let velocityMag = sqrt(value.velocity.width * value.velocity.width + value.velocity.height * value.velocity.height)
                if distance > Self.dismissThreshold || velocityMag > Self.dismissVelocityThreshold {
                    animatingOutIndex = expandedIndex
                    withAnimation(Self.dismissSpring) {
                        expandedIndex = nil
                        dismissOffset = .zero
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        animatingOutIndex = nil
                    }
                } else {
                    withAnimation(Self.cancelSpring) {
                        dismissOffset = .zero
                    }
                }
            }
    }

    // MARK: Disk Drag Gesture

    private func diskDragGesture(center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let dx = value.location.x - center.x
                let dy = value.location.y - center.y
                let dist = sqrt(dx * dx + dy * dy)

                guard dist >= 100 else {
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
                    lastHapticRidge = Int(floor(-(rotation + dragOffset) / Self.cardAngle))
                    return
                }

                var diff = angle - lastAngle
                if diff > 180 { diff -= 360 }
                if diff < -180 { diff += 360 }

                dragOffset += diff

                let ridge = Int(floor(-(rotation + dragOffset) / Self.cardAngle))
                let delta = ridge - lastHapticRidge
                if delta != 0 {
                    Self.haptic.prepare()
                    for _ in 0..<abs(delta) { Self.haptic.impactOccurred(intensity: 1) }
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
                guard abs(velocity) > 100 else { return snapToNearest() }
                let step = velocity > 0 ? -2 : 1
                let target = Int(round(-(rotation + dragOffset) / Self.cardAngle)) + step
                animateTo(target)
            }
    }

    // MARK: Helpers

    private func snapToNearest() {
        animateTo(Int(round(-(rotation + dragOffset) / Self.cardAngle)))
    }

    private func animateTo(_ target: Int) {
        withAnimation(Self.snapSpring) {
            rotation = Double(-target) * Self.cardAngle
            dragOffset = 0
        }
        fireHaptics(to: target)
    }

    private func fireHaptics(to target: Int) {
        guard target != lastHapticRidge else { return }
        let delta = abs(target - lastHapticRidge)
        Self.haptic.prepare()
        for _ in 0..<delta { Self.haptic.impactOccurred(intensity: 1) }
        lastHapticRidge = target
    }
}

#Preview {
    CollectionsView()
}
