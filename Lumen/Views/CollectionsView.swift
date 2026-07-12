import SwiftUI

// MARK: - Model

private struct CollectionTask {
    let emoji: String
    let name: String
}

private struct Collection: Identifiable {
    let id = UUID()
    let name: String
    let color: Color
    let tasks: [CollectionTask]
}

private let collectionsData: [Collection] = [
    Collection(name: "Morning", color: Color(red: 1, green: 0.76, blue: 0.46), tasks: [
        CollectionTask(emoji: "☕️", name: "Coffee"),
        CollectionTask(emoji: "📖", name: "Read"),
        CollectionTask(emoji: "🧘", name: "Stretch"),
    ]),
    Collection(name: "Work", color: Color(red: 0.46, green: 0.76, blue: 1), tasks: [
        CollectionTask(emoji: "💻", name: "Code"),
        CollectionTask(emoji: "📋", name: "Plan"),
        CollectionTask(emoji: "🤝", name: "Meeting"),
    ]),
    Collection(name: "Evening", color: Color(red: 0.76, green: 0.46, blue: 1), tasks: [
        CollectionTask(emoji: "🍜", name: "Dinner"),
        CollectionTask(emoji: "🎮", name: "Play"),
        CollectionTask(emoji: "📺", name: "Watch"),
    ]),
    Collection(name: "Fitness", color: Color(red: 0.46, green: 1, blue: 0.66), tasks: [
        CollectionTask(emoji: "🏃", name: "Run"),
        CollectionTask(emoji: "🏋️", name: "Lift"),
        CollectionTask(emoji: "🚴", name: "Cycle"),
    ]),
    Collection(name: "Mind", color: Color(red: 1, green: 0.46, blue: 0.66), tasks: [
        CollectionTask(emoji: "🧠", name: "Meditate"),
        CollectionTask(emoji: "📚", name: "Learn"),
        CollectionTask(emoji: "🎨", name: "Create"),
    ]),
    Collection(name: "Rest", color: Color(red: 0.66, green: 0.66, blue: 1), tasks: [
        CollectionTask(emoji: "😴", name: "Nap"),
        CollectionTask(emoji: "🛋️", name: "Relax"),
        CollectionTask(emoji: "🌿", name: "Nature"),
    ]),
]

private func collection(for index: Int) -> Collection {
    let i = ((index % collectionsData.count) + collectionsData.count) % collectionsData.count
    return collectionsData[i]
}

// MARK: - Shared Card Style

private func cardFillGradient(_ color: Color) -> LinearGradient {
    LinearGradient(colors: [
        color.opacity(0.18),
        color.opacity(0.04),
    ], startPoint: .topLeading, endPoint: .bottomTrailing)
}

private func cardStrokeGradient(_ color: Color) -> LinearGradient {
    LinearGradient(colors: [
        color.opacity(0.4),
        color.opacity(0.1),
    ], startPoint: .topLeading, endPoint: .bottomTrailing)
}

private struct CardShape: View {
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(cardFillGradient(color))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(cardStrokeGradient(color), lineWidth: 1.5)
            )
    }
}

// MARK: - Card

private struct CardView: View, Equatable {
    let index: Int
    let size: CGFloat
    let scale: CGFloat
    let opacity: Double
    let rotation: Double
    let horizontalOffset: CGFloat
    let verticalOffset: CGFloat

    static func == (lhs: CardView, rhs: CardView) -> Bool {
        lhs.index == rhs.index
        && lhs.scale == rhs.scale
        && lhs.opacity == rhs.opacity
        && lhs.rotation == rhs.rotation
        && lhs.horizontalOffset == rhs.horizontalOffset
        && lhs.verticalOffset == rhs.verticalOffset
    }

    var body: some View {
        let c = collection(for: index)
        CardShape(color: c.color)
            .overlay(
                VStack(spacing: 8) {
                    Spacer()
                    Text(c.tasks.first?.emoji ?? "")
                        .font(.system(size: 72))
                    Text(c.name)
                        .font(.system(size: 28, weight: .medium, design: .serif))
                        .foregroundColor(.white.opacity(0.85))
                        .shadow(color: c.color.opacity(0.3), radius: 10)
                    Spacer()
                }
            )
            .frame(width: size, height: size)
            .shadow(color: c.color.opacity(0.14), radius: 20, x: 0, y: 12)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(x: horizontalOffset, y: verticalOffset)
            .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Subviews

private struct LightGlowView: View {
    let index: Int
    let fractional: Double
    let viewWidth: CGFloat
    let turntableRadius: CGFloat

    var body: some View {
        let cardWidth = viewWidth * 0.7
        ZStack {
            ForEach((index - 1)...(index + 1), id: \.self) { i in
                let delta = Double(i) - fractional
                let distance = abs(delta)
                if distance < 2 {
                    let color = collection(for: i).color
                    let intensity = max(0, 1.0 - distance * 0.6)
                    let glowRadius = cardWidth * 0.4 * CGFloat(intensity)
                    let sign: CGFloat = delta >= 0 ? 1 : -1
                    Ellipse()
                        .fill(
                            RadialGradient(colors: [
                                color.opacity(0.15 * intensity),
                                color.opacity(0.04 * intensity),
                                .clear,
                            ], center: .center, startRadius: 0, endRadius: glowRadius)
                        )
                        .frame(width: glowRadius * 2.5, height: glowRadius * 0.8)
                        .offset(x: CGFloat(distance) * (cardWidth + 20) * sign)
                        .offset(y: -turntableRadius + 80)
                        .opacity(max(0, 1.0 - 0.2 * distance))
                }
            }
        }
    }
}

private struct TurntableReflectionsView: View {
    let index: Int
    let fractional: Double
    let viewWidth: CGFloat
    let turntableRadius: CGFloat

    var body: some View {
        let cardSize = viewWidth * 0.7
        ZStack {
            ForEach((index - 1)...(index + 1), id: \.self) { i in
                let delta = Double(i) - fractional
                let distance = abs(delta)
                if distance < 2 {
                    let color = collection(for: i).color
                    let offsetX = CGFloat(delta) * (cardSize + 20)
                    CardShape(color: color)
                        .frame(width: cardSize, height: cardSize * 0.5)
                        .scaleEffect(x: 1, y: -1)
                        .blur(radius: 40)
                        .mask(
                            LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom)
                        )
                        .opacity(max(0, 1.0 - 0.2 * distance) * 0.2)
                        .offset(x: offsetX, y: -turntableRadius + 50)
                }
            }
        }
    }
}

private struct TurntableTicksView: View {
    let rotation: Double
    let turntableRadius: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { i in
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(colors: [
                            .white.opacity(0.5),
                            .white.opacity(0),
                        ], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 5, height: 30)
                    .offset(y: -turntableRadius + 32)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
        }
        .rotationEffect(.degrees(rotation))
    }
}

// MARK: - CollectionsView

@MainActor
struct CollectionsView: View {
    @State private var rotation: Double = 0
    @State private var dragOffset: Double = 0
    @State private var velocity: Double = 0
    @State private var isDragging = false
    @State private var lastAngle: Double = 0
    @State private var lastTimestamp: Date = Date()
    @State private var lastHapticRidge: Int = 0

    private static let cardAngle: Double = 45
    private static let snapAnimation = Animation.interpolatingSpring(stiffness: 300, damping: 30)
    private static let haptic = UIImpactFeedbackGenerator(style: .heavy)

    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            let turntableRadius = w
            let center = CGPoint(x: w / 2, y: h + 0.2 * w)
            let totalRotation = rotation + dragOffset
            let fractional = -totalRotation / Self.cardAngle
            let currentIndex = Int(round(fractional))
            let cardSize = w * 0.7

            ZStack {
                Color.black.ignoresSafeArea()

                LightGlowView(
                    index: currentIndex,
                    fractional: fractional,
                    viewWidth: w,
                    turntableRadius: turntableRadius
                )
                .position(center)
                .allowsHitTesting(false)

                cardsLayer(
                    currentIndex: currentIndex,
                    fractional: fractional,
                    cardSize: cardSize
                )
                .offset(y: h / 2 - 1.15 * w - 30)

                turntableLayer(
                    turntableRadius: turntableRadius,
                    totalRotation: totalRotation,
                    currentIndex: currentIndex,
                    fractional: fractional,
                    viewWidth: w,
                    center: center
                )
            }
            .clipped()
        }
        .background(Color.black)
        .ignoresSafeArea()
        .onAppear { Self.haptic.prepare() }
    }

    // MARK: - Layers

    private func cardsLayer(currentIndex: Int, fractional: Double, cardSize: CGFloat) -> some View {
        let spacing = cardSize + 20
        return ZStack {
            ForEach((currentIndex - 2)...(currentIndex + 2), id: \.self) { i in
                let delta = Double(i) - fractional
                let d = abs(delta)
                let isCenter = d < 0.5
                CardView(
                    index: i,
                    size: cardSize,
                    scale: max(0.8, 1.0 - 0.12 * CGFloat(d)),
                    opacity: max(0, 1.0 - 0.2 * d),
                    rotation: delta * 10,
                    horizontalOffset: CGFloat(delta) * spacing,
                    verticalOffset: CGFloat(d * d * 16)
                )
                .equatable()
                .allowsHitTesting(isCenter)
                .highPriorityGesture(
                    cardFlickGesture(),
                    including: isCenter ? .all : .none
                )
            }
        }
    }

    private func turntableLayer(
        turntableRadius: CGFloat,
        totalRotation: Double,
        currentIndex: Int,
        fractional: Double,
        viewWidth: CGFloat,
        center: CGPoint
    ) -> some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.6))

            TurntableReflectionsView(
                index: currentIndex,
                fractional: fractional,
                viewWidth: viewWidth,
                turntableRadius: turntableRadius
            )

            TurntableTicksView(
                rotation: totalRotation,
                turntableRadius: turntableRadius
            )
        }
        .frame(width: turntableRadius * 2, height: turntableRadius * 2)
        .clipShape(Circle())
        .glassEffect(.regular, in: Circle())
        .position(center)
        .simultaneousGesture(diskDragGesture(center: center))
    }

    // MARK: - Gestures

    private func cardFlickGesture() -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                let sign: Double
                if value.velocity.width > 300 { sign = 1 }
                else if value.velocity.width < -300 { sign = -1 }
                else { return }
                withAnimation(Self.snapAnimation) {
                    rotation += sign * Self.cardAngle
                    dragOffset = 0
                }
                fireHapticsIfNeeded(to: Int(round(-rotation / Self.cardAngle)))
            }
    }

    private func diskDragGesture(center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let dx = value.location.x - center.x
                let dy = value.location.y - center.y
                let touchDistance = sqrt(dx * dx + dy * dy)

                guard touchDistance >= 100 else {
                    if isDragging {
                        isDragging = false
                        snapToNearest()
                    }
                    return
                }

                let angle = atan2(dy, dx) * 180 / .pi
                let now = Date()

                if !isDragging {
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
                    for _ in 0..<abs(delta) {
                        Self.haptic.impactOccurred(intensity: 1)
                    }
                    lastHapticRidge = ridge
                }

                let dt = now.timeIntervalSince(lastTimestamp)
                if dt > 0 {
                    velocity = velocity * 0.7 + (diff / dt) * 0.3
                }

                lastAngle = angle
                lastTimestamp = now
            }
            .onEnded { _ in
                isDragging = false
                defer { velocity = 0 }
                guard abs(velocity) > 100 else { return snapToNearest() }
                let step: Int = velocity > 0 ? -2 : 1
                let target = Int(round(-(rotation + dragOffset) / Self.cardAngle)) + step
                animateTo(index: target)
            }
    }

    private func snapToNearest() {
        let target = Int(round(-(rotation + dragOffset) / Self.cardAngle))
        animateTo(index: target)
    }

    private func animateTo(index target: Int) {
        let targetRotation = Double(-target) * Self.cardAngle
        withAnimation(Self.snapAnimation) {
            rotation = targetRotation
            dragOffset = 0
        }
        fireHapticsIfNeeded(to: target)
    }

    private func fireHapticsIfNeeded(to target: Int) {
        guard target != lastHapticRidge else { return }
        for _ in 0..<abs(target - lastHapticRidge) {
            Self.haptic.impactOccurred(intensity: 1)
        }
        lastHapticRidge = target
    }
}

#Preview {
    CollectionsView()
}
