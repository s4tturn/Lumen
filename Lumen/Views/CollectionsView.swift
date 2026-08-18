import SwiftUI
import UIKit

// MARK: - Models

struct CollectionItem: Identifiable, Equatable {
    let id = UUID()
    let emoji: String
    let name: String
    let task: String
}

struct Collection: Identifiable {
    let id = UUID()
    let name: String
    let color: Color
    let backgroundImage: String
    let items: [CollectionItem]
}

// MARK: - Sample Data

private let sampleCollections: [Collection] = [
    Collection(
        name: "Desk",
        color: .orange,
        backgroundImage: "DeskBackground",
        items: [
            CollectionItem(
                emoji: "🗂️",
                name: "Inbox",
                task: "Clear the loose papers from your desk"
            )
        ]
    ),

    Collection(
        name: "Kitchen",
        color: .blue,
        backgroundImage: "KitchenBackground",
        items: [
            CollectionItem(
                emoji: "🧽",
                name: "Sponge",
                task: "Wash the dishes"
            )
        ]
    ),

    Collection(
        name: "Garden",
        color: .green,
        backgroundImage: "GardenBackground",
        items: [
            CollectionItem(
                emoji: "💧",
                name: "Water",
                task: "Water the thirsty plants"
            )
        ]
    ),

    Collection(
        name: "Compassion",
        color: .red,
        backgroundImage: "CompassionBackground",
        items: [
            CollectionItem(
                emoji: "🐾",
                name: "Paws",
                task: "Take a dog for a walk"
            )
        ]
    ),

    Collection(
        name: "Connection",
        color: .purple,
        backgroundImage: "ConnectionBackground",
        items: [
            CollectionItem(
                emoji: "📞",
                name: "Call",
                task: "Call a friend you've been missing"
            )
        ]
    )
]

// MARK: - Card Configuration

private struct Card: Identifiable {
    let id = UUID()
    let imageName: String
    let name: String
}

private let cards: [Card] = [
    Card(imageName: "SelfBackground", name: "Self"),
    Card(imageName: "SpaceBackground", name: "Space"),
    Card(imageName: "KitchenBackground", name: "Kitchen"),
    Card(imageName: "ConnectionBackground", name: "Connection"),
    Card(imageName: "GrowthBackground", name: "Growth"),
    Card(imageName: "JoyBackground", name: "Joy")
]

// MARK: - Constants

private enum Layout {
    static let cardCount = cards.count

    // Distance between actual cards.
    static let cardSpacing: Double = 360.0 / Double(cardCount)

    // Tick marks can have their own spacing.
    static let tickSpacing: Double = UIConstants.Collections.cardAngle

    static let diskDiameterRatio: CGFloat = 1.5
    static let squareSizeRatio: CGFloat = 0.7
    static let orbitPadding: CGFloat = 50

    static let tickWidth: CGFloat = UIConstants.Collections.tickWidth
    static let tickHeight: CGFloat = UIConstants.Collections.tickHeight

    static let collapsedCornerRadius: CGFloat = 60
    static let dismissThreshold: CGFloat = 100

    static let expandAnimation: Animation = .spring(
        Spring.smooth(
            duration: 0.5,
            extraBounce: 0
        )
    )

    // A swipe carries momentum, so per the HIG fluid-interface guidance
    // ("Designing Fluid Interfaces", WWDC18) we let the dismiss follow
    // through with a little bounce as the card springs back into its slot
    // on the turntable, mirroring the path it expanded along.
    static let dismissAnimation: Animation = .spring(
        Spring.snappy(
            duration: 0.45,
            extraBounce: 0
        )
    )

    // Releasing below the threshold rubber-bands back to the expanded state
    // with no overshoot; a tap carries no momentum, so it must not bounce.
    static let snapBackAnimation: Animation = .spring(
        Spring.smooth(
            duration: 0.4,
            extraBounce: 0
        )
    )

    static let dismissVelocity: CGFloat = 800

    static let snapSpring = Spring.smooth(
        duration: 0.55,
        extraBounce: 0
    )
}

// MARK: - Coordinate Space

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

/// Returns an angle in degrees in the range (-180, 180].
private func normalizedAngleDelta(
    from start: Double,
    to end: Double
) -> Double {
    var delta = end - start

    while delta > 180 {
        delta -= 360
    }

    while delta < -180 {
        delta += 360
    }

    return delta
}

/// Returns the polar angle of a point around a center.
private func angle(
    of point: CGPoint,
    around center: CGPoint
) -> Double {
    degrees(
        fromRadians: atan2(
            point.y - center.y,
            point.x - center.x
        )
    )
}

// MARK: - Ghost Card Assets

/// Downsampled, extremely low-resolution copies of the card art. These are
/// pre-rendered once per asset and stretched to the card's full frame with
/// nearest-neighbor sampling so the ghost layer stays cheap to draw while
/// tracking the real card exactly.
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
            source.draw(
                in: CGRect(
                    origin: .zero,
                    size: target
                )
            )
        }

    lowResImageCache[name] = small
    return Image(uiImage: small)
}

// MARK: - Shared Card Layout

/// Single source of truth for a card's geometry. Both the visible card and
/// its invisible low-resolution ghost are derived from this so the two can
/// never be displaced from one another.
private struct CardLayout {
    let position: CGPoint
    let width: CGFloat
    let height: CGFloat
    let offsetY: CGFloat
    let cornerRadius: CGFloat
}

// MARK: - Tick Marks

private struct TickMarksView: View {
    let rotation: Double
    let radius: CGFloat

    var body: some View {
        ZStack {
            ForEach(
                0..<Int(360.0 / Layout.tickSpacing),
                id: \.self
            ) { index in
                Capsule(style: .continuous)
                    .fill(.white)
                    .frame(
                        width: Layout.tickWidth,
                        height: Layout.tickHeight
                    )
                    .offset(
                        y: -radius + Layout.tickHeight + 2
                    )
                    .rotationEffect(
                        .degrees(
                            Double(index) * Layout.tickSpacing
                        )
                    )
            }
        }
        .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Collections View

struct CollectionsView: View {

    @State private var expandedIndex: Int?

    // This is the single source of truth for turntable rotation.
    @State private var rotation: Double = 0

    // Gesture state.
    @State private var isDraggingDisk = false
    @State private var lastFingerAngle: Double = 0

    // Discrete haptic trigger.
    @State private var hapticTrigger = 0
    @State private var lastHapticRidge = 0

    // Live, finger-following upward drag of the expanded card. Kept as
    // @State (not @GestureState) so we can animate it back to rest on
    // release instead of letting it snap, which was the source of the
    // janky dismissal.
    @State private var dismissDrag: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            let squareSize =
                min(size.width, size.height)
                * Layout.squareSizeRatio

            let screenCornerRadius =
                UIConstants.General.screenCornerRadius

            let diskDiameter =
                size.width * Layout.diskDiameterRatio

            let diskRadius =
                diskDiameter / 2

            let diskCenter = CGPoint(
                x: size.width / 2,
                y: size.height
            )

            let orbitRadius =
                diskRadius
                + Layout.orbitPadding
                + squareSize / 2

            let anyExpanded =
                expandedIndex != nil

            ZStack {
                Color.black
                    .ignoresSafeArea()

                // Ghost layer (bottom): invisible, low-resolution cards that
                // track the real cards exactly.
                ForEach(
                    Array(cards.enumerated()),
                    id: \.element.id
                ) { index, card in

                    ghostCardView(
                        card: card,
                        index: index,
                        size: size,
                        squareSize: squareSize,
                        diskCenter: diskCenter,
                        orbitRadius: orbitRadius,
                        screenCornerRadius: screenCornerRadius,
                        isExpanded: expandedIndex == index
                    )
                }

                // Turntable (middle).
                diskView(
                    radius: diskRadius,
                    center: diskCenter
                )
                .allowsHitTesting(!anyExpanded)

                // Real cards (top).
                ForEach(
                    Array(cards.enumerated()),
                    id: \.element.id
                ) { index, card in

                    cardView(
                        card: card,
                        index: index,
                        size: size,
                        squareSize: squareSize,
                        diskCenter: diskCenter,
                        orbitRadius: orbitRadius,
                        screenCornerRadius: screenCornerRadius,
                        isExpanded: expandedIndex == index,
                        anyExpanded: anyExpanded
                    )
                }
            }
            .coordinateSpace(
                .named(CoordinateSpaces.collections)
            )
        }
        .ignoresSafeArea()

        .sensoryFeedback(
            .selection,
            trigger: hapticTrigger
        )

        .accessibilityElement(children: .contain)
        .accessibilityLabel("Collections")
        .accessibilityHint(
            "Rotate the disk to browse collections, tap a card to open it"
        )
    }

    // MARK: - Disk

    @ViewBuilder
    private func diskView(
        radius: CGFloat,
        center: CGPoint
    ) -> some View {

        ZStack {
            Circle()
                .fill(.black.opacity(0.6))

            TickMarksView(
                rotation: rotation,
                radius: radius
            )
        }
        .frame(
            width: radius * 2,
            height: radius * 2
        )
        .clipShape(Circle())
        .glassEffect(.regular, in: Circle())
        .position(center)
        .geometryGroup()
        .gesture(
            diskDragGesture(center: center)
        )
    }

    // MARK: - Card

    private func cardLayout(
        index: Int,
        isExpanded: Bool,
        size: CGSize,
        squareSize: CGFloat,
        diskCenter: CGPoint,
        orbitRadius: CGFloat,
        screenCornerRadius: CGFloat
    ) -> CardLayout {

        let angle = radians(
            fromDegrees:
                rotation
                + Double(index) * Layout.cardSpacing
        )

        let orbitX =
            diskCenter.x
            + orbitRadius * sin(angle)

        let orbitY =
            diskCenter.y
            - orbitRadius * cos(angle)

        let positionX =
            isExpanded
            ? size.width / 2
            : orbitX

        let positionY =
            isExpanded
            ? size.height / 2
            : orbitY

        let width =
            isExpanded
            ? size.width
            : squareSize

        let height =
            isExpanded
            ? size.height
            : squareSize

        let progress =
            isExpanded
            ? min(
                max(
                    -dismissDrag / Layout.dismissThreshold,
                    0
                ),
                1
            )
            : 0

        let cornerRadius =
            isExpanded
            ? screenCornerRadius
                + (
                    Layout.collapsedCornerRadius
                    - screenCornerRadius
                ) * progress
            : Layout.collapsedCornerRadius

        return CardLayout(
            position: CGPoint(
                x: positionX,
                y: positionY
            ),
            width: width,
            height: height,
            offsetY: dismissDrag,
            cornerRadius: cornerRadius
        )
    }

    @ViewBuilder
    private func ghostCardView(
        card: Card,
        index: Int,
        size: CGSize,
        squareSize: CGFloat,
        diskCenter: CGPoint,
        orbitRadius: CGFloat,
        screenCornerRadius: CGFloat,
        isExpanded: Bool
    ) -> some View {

        let layout = cardLayout(
            index: index,
            isExpanded: isExpanded,
            size: size,
            squareSize: squareSize,
            diskCenter: diskCenter,
            orbitRadius: orbitRadius,
            screenCornerRadius: screenCornerRadius
        )

        lowResImage(for: card.imageName)
            .resizable()
            .interpolation(.none)
            .aspectRatio(contentMode: .fill)
            .frame(
                width: layout.width,
                height: layout.height
            )
            .clipped()
            .clipShape(
                RoundedRectangle(
                    cornerRadius: layout.cornerRadius
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: layout.cornerRadius
                )
                .fill(.ultraThinMaterial)
                .opacity(isExpanded ? 1 : 0)
            }
            .offset(y: layout.offsetY)
            .position(
                x: layout.position.x,
                y: layout.position.y
            )
            .geometryGroup()
    }

    @ViewBuilder
    private func cardView(
        card: Card,
        index: Int,
        size: CGSize,
        squareSize: CGFloat,
        diskCenter: CGPoint,
        orbitRadius: CGFloat,
        screenCornerRadius: CGFloat,
        isExpanded: Bool,
        anyExpanded: Bool
    ) -> some View {

        let layout = cardLayout(
            index: index,
            isExpanded: isExpanded,
            size: size,
            squareSize: squareSize,
            diskCenter: diskCenter,
            orbitRadius: orbitRadius,
            screenCornerRadius: screenCornerRadius
        )

        Image(card.imageName)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(
                width: layout.width,
                height: layout.height
            )
            .clipped()
            .clipShape(
                RoundedRectangle(
                    cornerRadius: layout.cornerRadius
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: layout.cornerRadius
                )
                .stroke(
                    .white.opacity(isExpanded ? 0 : 0.2),
                    lineWidth: 1
                )
            }
            .overlay {
                ZStack(alignment: isExpanded ? .top : .bottom) {
                    // Frosted glass — gradient fills the card on expand.
                    RoundedRectangle(
                        cornerRadius: layout.cornerRadius
                    )
                    .fill(.ultraThinMaterial)
                    .mask {
                        RadialGradient(
                            stops: [
                                .init(
                                    color: isExpanded
                                        ? .black : .clear,
                                    location: 0.0
                                ),
                                .init(
                                    color: isExpanded
                                        ? .black : .clear,
                                    location: 0
                                ),
                                .init(
                                    color: .black,
                                    location: 1.0
                                )
                            ],
                            center: UnitPoint(x: 0.5, y: 0.0),
                            startRadius: 0,
                            endRadius: layout.width * 0.9
                        )
                    }

                    // Cool-tinted dim at the bottom edge.
                    RoundedRectangle(
                        cornerRadius: layout.cornerRadius
                    )
                    .fill(
                        Color(
                            red: 0.05,
                            green: 0.07,
                            blue: 0.12
                        )
                        .opacity(isExpanded ? 0 : 0.22)
                    )
                    .mask {
                        RadialGradient(
                            stops: [
                                .init(
                                    color: isExpanded
                                        ? .black : .clear,
                                    location: 0.0
                                ),
                                .init(
                                    color: isExpanded
                                        ? .black : .clear,
                                    location: 0
                                ),
                                .init(
                                    color: .black,
                                    location: 1.0
                                )
                            ],
                            center: UnitPoint(x: 0.5, y: 0.0),
                            startRadius: 0,
                            endRadius: layout.width * 0.9
                        )
                    }

                    Text(card.name)
                        .font(
                            .system(
                                size: isExpanded ? 50 : 25,
                                design: .serif
                            )
                        )
                        .foregroundStyle(.white)
                        .shadow(
                            color: .black.opacity(0.35),
                            radius: 2,
                            y: 1
                        )
                        .padding(
                            .bottom,
                            isExpanded
                                ? 0
                                : max(12, layout.height * 0.06)
                        )
                        .padding(
                            .top,
                            isExpanded
                                ? max(20, layout.height * 0.08)
                                : 0
                        )
                        .animation(
                            .easeInOut(duration: 0.5),
                            value: isExpanded
                        )
                }
            }
            .offset(y: layout.offsetY)
            .position(
                x: layout.position.x,
                y: layout.position.y
            )
            .geometryGroup()
            .allowsHitTesting(
                !anyExpanded || isExpanded
            )
            .onTapGesture {
                guard expandedIndex == nil else {
                    return
                }

                withAnimation(Layout.expandAnimation) {
                    expandedIndex = index
                }
            }
            .gesture(
                expandDismissGesture(
                    isExpanded: isExpanded
                )
            )
            .accessibilityLabel(
                card.imageName.replacingOccurrences(
                    of: "Background",
                    with: ""
                )
            )
            .accessibilityHint(
                isExpanded
                ? "Swipe up to dismiss"
                : "Double tap to open"
            )
    }

    // MARK: - Expand / Dismiss

    private func expandDismissGesture(
        isExpanded: Bool
    ) -> some Gesture {

        DragGesture(
            minimumDistance: 0,
            coordinateSpace: .local
        )
        .onChanged { value in
            guard isExpanded else {
                return
            }

            // Track the finger 1:1, allowing only an upward drag so the
            // card follows the gesture exactly (HIG: "work with behavior
            // rather than animation").
            let translation = value.translation.height

            dismissDrag = translation < 0 ? translation : 0
        }
        .onEnded { value in
            guard isExpanded else {
                return
            }

            let translation = value.translation.height
            let velocity = value.velocity.height

            let shouldDismiss =
                translation < -Layout.dismissThreshold
                || velocity < -Layout.dismissVelocity

            if shouldDismiss {
                // Follow through: keep the finger's offset while the card
                // springs back down into its slot on the turntable,
                // retracing the expansion path in reverse (spatial
                // consistency).
                withAnimation(Layout.dismissAnimation) {
                    expandedIndex = nil
                    dismissDrag = 0
                }
            } else {
                // Rubber-band return to the expanded state.
                withAnimation(Layout.snapBackAnimation) {
                    dismissDrag = 0
                }
            }
        }
    }

    // MARK: - Disk Gesture

    private func diskDragGesture(
        center: CGPoint
    ) -> some Gesture {

        DragGesture(
            minimumDistance: 0,
            coordinateSpace: .named(
                CoordinateSpaces.collections
            )
        )
        .onChanged { value in
            guard expandedIndex == nil else {
                return
            }

            let location = value.location

            let dx =
                location.x - center.x

            let dy =
                location.y - center.y

            let distance =
                hypot(dx, dy)

            // Do not try to calculate an angle close to
            // the center of the turntable.
            guard distance >=
                    UIConstants.Collections.diskDeadZone
            else {
                return
            }

            let currentAngle =
                angle(
                    of: location,
                    around: center
                )

            // First valid event establishes the angular baseline.
            guard isDraggingDisk else {
                isDraggingDisk = true
                lastFingerAngle = currentAngle

                lastHapticRidge =
                    currentHapticRidge()

                return
            }

            // Only use the angular change between consecutive
            // finger positions. This is the direct-manipulation
            // portion of the interaction.
            let delta =
                normalizedAngleDelta(
                    from: lastFingerAngle,
                    to: currentAngle
                )

            rotation += delta
            lastFingerAngle = currentAngle

            updateHapticRidge()
        }
        .onEnded { value in
            defer {
                isDraggingDisk = false
            }

            guard expandedIndex == nil else {
                return
            }

            guard isDraggingDisk else {
                snapToNearest()
                return
            }

            let currentLocation =
                value.location

            let predictedLocation =
                value.predictedEndLocation

            let currentDistance =
                hypot(
                    currentLocation.x - center.x,
                    currentLocation.y - center.y
                )

            let predictedDistance =
                hypot(
                    predictedLocation.x - center.x,
                    predictedLocation.y - center.y
                )

            // We need both points to be far enough from
            // the center for a reliable angular prediction.
            guard currentDistance >=
                    UIConstants.Collections.diskDeadZone,
                  predictedDistance >=
                    UIConstants.Collections.diskDeadZone
            else {
                snapToNearest()
                return
            }

            let currentAngle =
                angle(
                    of: currentLocation,
                    around: center
                )

            let predictedAngle =
                angle(
                    of: predictedLocation,
                    around: center
                )

            // Apple's predictedEndLocation is already based
            // on the drag's current velocity. Convert the
            // predicted finger movement directly into angular
            // movement around the turntable.
            let predictedAngularDelta =
                normalizedAngleDelta(
                    from: currentAngle,
                    to: predictedAngle
                )

            let predictedRotation =
                rotation + predictedAngularDelta

            let target =
                nearestCardIndex(
                    to: predictedRotation
                )

            animateToCard(target)
        }
    }

    // MARK: - Rotation / Snapping

    private func nearestCardIndex(
        to rotation: Double
    ) -> Int {

        Int(
            round(
                -rotation / Layout.cardSpacing
            )
        )
    }

    private func snapToNearest() {
        let target =
            nearestCardIndex(
                to: rotation
            )

        animateToCard(target)
    }

    private func animateToCard(_ target: Int) {
        let targetRotation =
            Double(-target) * Layout.cardSpacing

        var transaction = Transaction(
            animation: .smooth(
                duration: Layout.snapSpring.duration,
                extraBounce: 0
            )
        )

        transaction.tracksVelocity = false

        withTransaction(transaction) {
            rotation = targetRotation
        }

        updateHapticRidge(to: target)
    }

    // MARK: - Haptics

    private func currentHapticRidge() -> Int {
        Int(
            round(
                -rotation / Layout.cardSpacing
            )
        )
    }

    private func updateHapticRidge() {
        let ridge =
            currentHapticRidge()

        guard ridge != lastHapticRidge else {
            return
        }

        let delta =
            ridge - lastHapticRidge

        // Change the trigger once for every crossed card
        // position. SwiftUI's sensoryFeedback modifier then
        // provides the actual feedback.
        hapticTrigger += abs(delta)

        lastHapticRidge = ridge
    }

    private func updateHapticRidge(
        to target: Int
    ) {
        let delta =
            target - lastHapticRidge

        guard delta != 0 else {
            return
        }

        hapticTrigger += abs(delta)
        lastHapticRidge = target
    }
}

// MARK: - Preview

#Preview {
    CollectionsView()
}
