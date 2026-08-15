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

// MARK: - Focused Item Change Environment Key

struct FocusedItemChangeKey: EnvironmentKey {
    static let defaultValue: (FocusedItem?) -> Void = { _ in }
}

extension EnvironmentValues {
    var onFocusedItemChange: (FocusedItem?) -> Void {
        get { self[FocusedItemChangeKey.self] }
        set { self[FocusedItemChangeKey.self] = newValue }
    }
}

// MARK: - Models

/// A single task inside a collection. Each task is an object with its own
/// emoji, name, and description of what the task is.
struct TaskObject: Equatable, Identifiable {
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
    let items: [TaskObject]
}

// MARK: - Sample Data

private let collections: [Collection] = [
    Collection(name: "Desk", color: CollectionBackgrounds.averageColor(named: "DeskBackground") ?? .orange, backgroundImage: "DeskBackground", items: [
        .init(emoji: "🗂️", name: "Inbox", task: "Clear the loose papers from your desk"),
        .init(emoji: "✏️", name: "Pencil", task: "Sharpen and sort your writing tools"),
        .init(emoji: "📄", name: "Paper", task: "File away the stray papers"),
        .init(emoji: "🔌", name: "Cable", task: "Tidy the cables on your desk"),
        .init(emoji: "🖥️", name: "Screen", task: "Wipe your screen and keyboard clean"),
        .init(emoji: "🗑️", name: "Bin", task: "Empty the trash by your desk"),
        .init(emoji: "📋", name: "List", task: "Write out your plan for the day"),
        .init(emoji: "🧲", name: "Magnet", task: "Pin your notes where you can see them"),
        .init(emoji: "📚", name: "Books", task: "Return the books to their shelf"),
        .init(emoji: "🕯️", name: "Focus", task: "Clear a calm, empty space to work"),
    ]),
    Collection(name: "Kitchen", color: CollectionBackgrounds.averageColor(named: "KitchenBackground") ?? .blue, backgroundImage: "KitchenBackground", items: [
        .init(emoji: "🧽", name: "Sponge", task: "Wash the dishes"),
        .init(emoji: "🍽️", name: "Plate", task: "Put the clean dishes away"),
        .init(emoji: "🥄", name: "Spoon", task: "Sort the cutlery"),
        .init(emoji: "🧴", name: "Soap", task: "Refill the soap dispenser"),
        .init(emoji: "🧊", name: "Fridge", task: "Clear the fridge of anything old"),
        .init(emoji: "🔥", name: "Stove", task: "Wipe down the stovetop"),
        .init(emoji: "🗑️", name: "Compost", task: "Take out the compost"),
        .init(emoji: "🥤", name: "Mug", task: "Return the mugs to the cupboard"),
        .init(emoji: "🧂", name: "Spice", task: "Put the spices back in order"),
        .init(emoji: "🧹", name: "Mop", task: "Mop the kitchen floor"),
    ]),
    Collection(name: "Garden", color: CollectionBackgrounds.averageColor(named: "GardenBackground") ?? .green, backgroundImage: "GardenBackground", items: [
        .init(emoji: "💧", name: "Water", task: "Water the thirsty plants"),
        .init(emoji: "🌱", name: "Sprout", task: "Plant a new seed"),
        .init(emoji: "✂️", name: "Snips", task: "Trim the dead leaves"),
        .init(emoji: "🪴", name: "Pot", task: "Repot a plant that's outgrown its pot"),
        .init(emoji: "🌿", name: "Fern", task: "Mist the leafy plants"),
        .init(emoji: "🐞", name: "Ladybug", task: "Check the leaves for little visitors"),
        .init(emoji: "🧤", name: "Gloves", task: "Turn the soil and loosen it"),
        .init(emoji: "☀️", name: "Light", task: "Move the plants toward the sun"),
        .init(emoji: "🪱", name: "Worm", task: "Feed the compost pile"),
        .init(emoji: "🌸", name: "Bloom", task: "Pick the spent flowers"),
    ]),
    Collection(name: "Compassion", color: CollectionBackgrounds.averageColor(named: "CompassionBackground") ?? .red, backgroundImage: "CompassionBackground", items: [
        .init(emoji: "🐾", name: "Paws", task: "Take a dog for a walk"),
        .init(emoji: "🥣", name: "Bowl", task: "Fill the water bowl"),
        .init(emoji: "🦴", name: "Bone", task: "Give a pet a treat"),
        .init(emoji: "🧹", name: "Litter", task: "Scoop the litter box"),
        .init(emoji: "🐦", name: "Seed", task: "Refill the bird feeder"),
        .init(emoji: "🧺", name: "Blanket", task: "Wash the pet's bedding"),
        .init(emoji: "🐈", name: "Cat", task: "Play with a cat for ten minutes"),
        .init(emoji: "🪮", name: "Brush", task: "Groom a furry friend"),
        .init(emoji: "🐝", name: "Bee", task: "Plant something for the bees"),
        .init(emoji: "🚪", name: "Shelter", task: "Give a stray a safe corner"),
    ]),
    Collection(name: "Connection", color: CollectionBackgrounds.averageColor(named: "ConnectionBackground") ?? .purple, backgroundImage: "ConnectionBackground", items: [
        .init(emoji: "📞", name: "Call", task: "Call a friend you've been missing"),
        .init(emoji: "✉️", name: "Letter", task: "Write a note to a loved one"),
        .init(emoji: "👋", name: "Hello", task: "Say hello to someone new"),
        .init(emoji: "🫂", name: "Hug", task: "Hug someone who needs it"),
        .init(emoji: "🎁", name: "Gift", task: "Give a small gift for no reason"),
        .init(emoji: "💬", name: "Bubble", task: "Start a chat with a stranger"),
        .init(emoji: "👂", name: "Ear", task: "Listen fully, without interrupting"),
        .init(emoji: "🌟", name: "Compliment", task: "Give a genuine compliment"),
        .init(emoji: "🪑", name: "Seat", task: "Invite someone for a coffee"),
        .init(emoji: "📅", name: "Plan", task: "Make plans with a friend"),
    ]),
]

// MARK: - Geometry Helpers

/// Wraps any index into the collections array cyclically.
private func getCollection(at index: Int) -> Collection {
    collections[((index % collections.count) + collections.count) % collections.count]
}

/// True Euclidean modulo — always non-negative.
private func positiveMod(_ value: Int, _ modulus: Int) -> Int {
    ((value % modulus) + modulus) % modulus
}

// MARK: - Card Backgrounds

/// Lazily loads and caches the bundled collection background photos.
/// Images are loose resources (bundled via the file-system synchronized
/// group), so they're located through `Bundle` rather than the asset catalog.
private enum CollectionBackgrounds {
    private static let cache: [String: UIImage] = {
        let names = [
            "DeskBackground", "KitchenBackground", "GardenBackground",
            "CompassionBackground", "ConnectionBackground",
        ]
        var loaded: [String: UIImage] = [:]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "jpg"),
                  let image = UIImage(contentsOfFile: url.path) else { continue }
            loaded[name] = image
        }
        return loaded
    }()

    static func image(named name: String) -> Image? {
        cache[name].map(Image.init(uiImage:))
    }

    /// The collection's signature color: the average color of its photo.
    static func averageColor(named name: String) -> Color? {
        cache[name]?.averageColor.map(Color.init(uiColor:))
    }
}

extension UIImage {
    /// Average color of the whole image, computed from a downsampled copy.
    var averageColor: UIColor? {
        let size = CGSize(width: 50, height: 50)
        let sampled = UIGraphicsImageRenderer(size: size).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
        guard let sample = sampled.cgImage,
              let data = sample.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return nil }

        let width = sample.width
        let height = sample.height
        let bytesPerRow = sample.bytesPerRow
        let bytesPerPixel = sample.bitsPerPixel / 8

        var totalRed = 0.0
        var totalGreen = 0.0
        var totalBlue = 0.0
        let count = Double(width * height)

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                totalBlue  += Double(bytes[offset])
                totalGreen += Double(bytes[offset + 1])
                totalRed   += Double(bytes[offset + 2])
            }
        }

        return UIColor(
            red: CGFloat(totalRed / count / 255),
            green: CGFloat(totalGreen / count / 255),
            blue: CGFloat(totalBlue / count / 255),
            alpha: 1
        )
    }
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

// MARK: - Turntable Geometry

/// Number of card stops around the full dial — a property of the turntable,
/// independent of how many collections actually exist.
private var cardStopCount: Int { Int(360.0 / UIConstants.Collections.cardAngle) }

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

/// Derives the visible cards' layouts from the current turntable position.
/// - Parameter fractional: negative rotation / cardAngle — the continuous "rotor position".
/// - Parameter cardSize: width of a single card.
/// - Parameter spacing: center-to-center distance between adjacent cards.
/// - Returns: Array of CardLayouts, ordered from leftmost to rightmost.
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
            .overlay {
                if let background = CollectionBackgrounds.image(
                    named: getCollection(at: layout.index).backgroundImage
                ) {
                    background
                        .resizable()
                        .scaledToFill()
                        // Crop to the card's face — square when collapsed, full
                        // screen when expanded — then round the corners.
                        .frame(
                            width: expanded ? UIConstants.General.screenWidth : size,
                            height: expanded ? UIConstants.General.screenHeight : size
                        )
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        // The photo is always the card's face; it just blurs out
                        // behind the expanded content.
                        .blur(radius: expanded ? UIConstants.Collections.expandedBackgroundBlur : 0)
                }
            }
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
                        VStack(spacing: 8) {
                            Text(item.name)
                                .font(.system(size: 32, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.85))
                            Text(item.task)
                                .font(.system(size: 20, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                        }
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

/// Ridges on the turntable dial: one per card stop around the full circle,
/// evenly spaced by `cardAngle`. Their count is a property of the turntable,
/// not of the data, so they align with the cards regardless of how many
/// collections exist.
///
/// Each ridge is painted with the color of the card currently sitting in its
/// angular slot. Because the slot assignment is derived from the live rotation
/// (and snapped to the dial grid), the ridge pointing at the centered card
/// always matches that card's color — even when scrolling fast, when the
/// ridge cycle (one per stop) and the collection cycle (one per collection)
/// would otherwise drift apart.
private struct TickMarksView: View {
    let rotation: Double
    let radius: CGFloat

    var body: some View {
        let count = cardStopCount
        let step = UIConstants.Collections.cardAngle
        let tW = UIConstants.Collections.tickWidth
        let tH = UIConstants.Collections.tickHeight
        // Card index currently at the top slot, snapped down to the dial grid
        // so each ridge keeps the same card while the dial is between stops.
        let current = Int(round(-rotation / step))
        let baseIndex = current - positiveMod(current, count)

        ZStack {
            ForEach(0..<count, id: \.self) { i in
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white, getCollection(at: baseIndex + i).color],
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
    @Environment(\.onFocusedItemChange) private var onFocusedItemChange

    /// True whenever the expanded card is animating in, fully expanded, or animating out.
    /// Controls primary card elevation (zIndex 4 vs 2) and ghost card visibility.
    private var isPrimaryElevated: Bool {
        expandedIndex != nil || animatingInIndex != nil || animatingOutIndex != nil
    }

    /// The card currently elevated, in priority order.
    private var primaryIndex: Int? {
        expandedIndex ?? animatingInIndex ?? animatingOutIndex
    }

    /// Identity of the emoji item currently centered in the expanded card.
    private var focusedItem: FocusedItem? {
        guard let index = expandedIndex else { return nil }
        let collection = getCollection(at: index)
        let item = collection.items[itemIndex]
        return FocusedItem(
            key: "\(collection.name)/\(item.name)",
            collectionColor: collection.color
        )
    }

    /// Shared haptic generator — created once per view instance (Apple HIG).
    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    /// Convenience: total rotation including live drag.
    private var totalRotation: Double { rotation + dragOffset }

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
                    let isPrimary = layout.index == primaryIndex

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
                // Mirrors the primary card exactly, using the same layout math as
                // the carousel so they can never drift apart. Visible only while
                // the primary is elevated (zIndex 4), providing visual continuity
                // behind the turntable (zIndex 3). Appears/disappears instantly.
                if isPrimaryElevated,
                   let gi = primaryIndex,
                   let ghostLayout = layouts.first(where: { $0.index == gi }) {
                    CardView(
                        layout: ghostLayout,
                        size: cardSize,
                        expanded: gi == expandedIndex,
                        parentOffsetY: cardsOffsetY,
                        dismissOffset: gi == expandedIndex ? dismissOffset : .zero,
                        dismissProgress: gi == expandedIndex ? dismissProgress() : 0,
                        swipeOffset: gi == expandedIndex ? itemSwipeOffset : 0,
                        itemIndex: itemIndex
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
            onFocusedItemChange(focusedItem)
            if index != nil {
                itemIndex = 0
                itemSwipeOffset = 0
                dismissOffset = .zero
                expandedDragLock = nil
            }
        }
        .onChange(of: itemIndex) { _, _ in
            onFocusedItemChange(focusedItem)
        }
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
