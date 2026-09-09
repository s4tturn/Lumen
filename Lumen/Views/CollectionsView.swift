import SwiftUI

// MARK: - Collections
//
// One persistent view per card morphs orbit <-> fullscreen (transforms only,
// so every frame interpolates — never an identity swap). Rotation drives just
// position/rotation; faces, materials and the pager are static inputs that
// diff to no-ops at gesture frequency. Haptics are declarative
// (.sensoryFeedback) — zero imperative generators on the touch path.

struct CollectionsView: View {
    @Binding private var collectionsExpanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model = CollectionsModel()

    private let pageSize: CGSize

    init(
        collectionsExpanded: Binding<Bool> = .constant(false),
        pageSize: CGSize = CGSize(width: 390, height: 844)
    ) {
        self._collectionsExpanded = collectionsExpanded
        self.pageSize = pageSize
    }

    var body: some View {
        let geo = Geo(size: pageSize)
        let expanded = model.expanded

        ZStack {
            Color.black.ignoresSafeArea()

            DiskView(model: model, geo: geo, focusedName: cards[model.focused].name)
                .zIndex(2)
                .allowsHitTesting(expanded == nil)

            ForEach(cards.indices, id: \.self) { index in
                OrbitCard(
                    model: model,
                    card: cards[index],
                    index: index,
                    geo: geo,
                    isExpanded: expanded == index,
                    anyExpanded: expanded != nil,
                    onExpand: expand,
                    onDismissChange: dismissChanged,
                    onDismissEnd: dismissEnded
                )
            }
        }
        .frame(width: pageSize.width, height: pageSize.height)
        .coordinateSpace(.named("CollectionsView"))
        .sensoryFeedback(.selection, trigger: model.ridge)
        .sensoryFeedback(.impact, trigger: expanded)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Collections")
        .accessibilityHint("Rotate the disk to browse collections, tap a card to open it")
    }

    private var expandAnimation: Animation {
        UIConstants.Animation.motionGate(UIConstants.Animation.smoothSpring, reduceMotion: reduceMotion)
    }

    private func expand(_ index: Int) {
        guard model.expanded == nil else { return }
        // Nearest straight angle: the morph always takes the shortest path.
        model.landing = 360 * round((model.rotation + Double(index) * Geo.spacing) / 360)
        withAnimation(expandAnimation) {
            model.expanded = index
            model.front = index
            collectionsExpanded = true
        }
    }

    private func dismissChanged(_ translation: CGSize) {
        guard model.expanded != nil else { return }
        model.dismiss = abs(translation.height) > abs(translation.width) ? min(0, translation.height) : 0
    }

    private func dismissEnded(_ value: DragGesture.Value, geo: Geo) {
        guard model.expanded != nil else { return }
        let vertical = abs(value.translation.height) > abs(value.translation.width)
        let shouldDismiss = vertical
            && (value.translation.height < -geo.dismissAt || value.velocity.height < -800)
        withAnimation(
            UIConstants.Animation.motionGate(
                shouldDismiss ? UIConstants.Animation.snappySpring : UIConstants.Animation.smoothSpring, reduceMotion: reduceMotion)
        ) {
            if shouldDismiss {
                model.expanded = nil
                collectionsExpanded = false
            }
            model.dismiss = 0
        }
    }
}

// MARK: - Model

/// Single source of truth. View-read state is observed; transient gesture
/// bookkeeping is ignored so it never invalidates the tree.
@MainActor @Observable
final class CollectionsModel {
    var rotation = 0.0
    var expanded: Int?
    var front: Int?
    var dismiss: CGFloat = 0
    var landing = 0.0
    var ridge = 0
    var dragging = false
    @ObservationIgnored var fingerAngle = 0.0
    @ObservationIgnored var fingerTime = Date.distantPast
    @ObservationIgnored var velocity = 0.0
    @ObservationIgnored var epoch = 0

    var focused: Int {
        let raw = Int(round(-rotation / Geo.spacing))
        return ((raw % cards.count) + cards.count) % cards.count
    }

    func settle(_ target: Int, animation: Animation) {
        epoch += 1
        let current = epoch
        withAnimation(animation) {
            rotation = Double(-target) * Geo.spacing
        } completion: {
            self.fold(epoch: current)
        }
        ridge = target
    }

    func flick(to target: Int, animation: (Double) -> Animation) {
        epoch += 1
        let current = epoch
        let destination = Double(-target) * Geo.spacing
        let remaining = destination - rotation
        withAnimation(animation(remaining == 0 ? 0 : velocity / remaining)) {
            rotation = destination
        } completion: {
            self.fold(epoch: current)
        }
        ridge = target
    }

    /// Folds accumulated turns back into (-180, 180°] once a snap lands.
    /// Mod-360 invariant, so invisible; unanimated via empty transaction.
    func fold(epoch: Int) {
        guard epoch == self.epoch, expanded == nil, !dragging else { return }
        let turns = -Int(round(rotation / 360))
        guard turns != 0 else { return }
        withTransaction(Transaction()) { rotation += 360 * Double(turns) }
    }
}

// MARK: - Geometry

/// Pure function of the stable page size; one instance per body evaluation.
private struct Geo: Sendable {
    static let spacing = 360.0 / Double(cards.count)

    let size: CGSize
    var radius: CGFloat { size.height * 0.35 }
    var card: CGFloat { radius * 2 * 0.5 }
    var orbit: CGFloat { radius * 1.2 + card / 2 }
    var center: CGPoint { CGPoint(x: size.width / 2, y: size.height) }
    var deadZone: CGFloat { radius * 0.06 }
    var dismissAt: CGFloat { card * 0.15 }
    var collapsedCorner: CGFloat { card * 0.15 }
    var tick: CGSize { CGSize(width: radius * 0.03, height: radius * 0.125) }
    var screenCorner: CGFloat { UIConstants.General.screenCornerRadius }
}

// MARK: - Disk

/// The page's only glass surface in its own container (glass cannot sample
/// glass). Ticks render in one Canvas pass — no per-tick views to invalidate.
private struct DiskView: View {
    @Bindable var model: CollectionsModel
    let geo: Geo
    let focusedName: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GlassEffectContainer {
            ZStack {
                Circle().fill(.black.opacity(0.6))
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    for tick in 0..<6 {
                        context.drawLayer { layer in
                            layer.translateBy(x: center.x, y: center.y)
                            layer.rotate(by: .radians((model.rotation + Double(tick) * 60) * .pi / 180))
                            layer.fill(
                                Path(roundedRect: CGRect(
                                    x: -geo.tick.width / 2,
                                    y: -geo.radius + 2 + geo.tick.height / 2,
                                    width: geo.tick.width,
                                    height: geo.tick.height
                                ), cornerRadius: geo.tick.width / 2),
                                with: .color(.white)
                            )
                        }
                    }
                }
            }
            .frame(width: geo.radius * 2, height: geo.radius * 2)
            .glassEffect(.regular, in: Circle())
            .contentShape(Circle())
            .position(geo.center)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Collections disk")
            .accessibilityValue(focusedName)
            .accessibilityHint("Swipe up or down to browse collections")
            .accessibilityAdjustableAction { direction in
                model.settle(
                    model.focused + (direction == .increment ? 1 : -1),
                    animation: UIConstants.Animation.motionGate(
                        UIConstants.Animation.snappySpring, reduceMotion: reduceMotion)
                )
            }
            .gesture(diskDrag)
        }
    }

    /// Tracks 1:1 with no animation while down (the user is the animation);
    /// release projects via predicted rotation and hands velocity to the
    /// spring (momentum earns bounce: 0.15, inside the 0.3–0.4s band).
    private var diskDrag: some Gesture {
        // Hoisted for the nonisolated end-handler below (Sendable copies).
        let center = geo.center
        let dead = geo.deadZone
        return DragGesture(minimumDistance: 0, coordinateSpace: .named("CollectionsView"))
            .onChanged { value in
                guard model.expanded == nil else { return }
                let delta = CGPoint(x: value.location.x - geo.center.x, y: value.location.y - geo.center.y)
                guard hypot(delta.x, delta.y) >= geo.deadZone else { return }
                let current = angle(of: value.location)
                guard model.dragging else {
                    model.dragging = true
                    model.fingerAngle = current
                    model.fingerTime = value.time
                    model.velocity = 0
                    model.ridge = Int(floor(-model.rotation / Geo.spacing))
                    return
                }
                let step = norm(model.fingerAngle, current)
                let dt = max(value.time.timeIntervalSince(model.fingerTime), 1e-3)
                model.velocity += 0.35 * ((step / dt) - model.velocity)
                model.rotation += step
                model.fingerAngle = current
                model.fingerTime = value.time
                model.ridge = Int(floor(-model.rotation / Geo.spacing))
            }
            .onEnded { value in
                defer {
                    model.dragging = false
                    model.velocity = 0
                }
                guard model.expanded == nil, model.dragging else {
                    model.settle(
                        Int(round(-model.rotation / Geo.spacing)),
                        animation: gate(UIConstants.Animation.snappySpring)
                    )
                    return
                }
                func clear(_ point: CGPoint) -> Bool {
                    hypot(point.x - center.x, point.y - center.y) >= dead
                }
                guard clear(value.location), clear(value.predictedEndLocation) else {
                    model.settle(Int(round(-model.rotation / Geo.spacing)), animation: gate(UIConstants.Animation.snappySpring))
                    return
                }
                let projected = model.rotation + norm(angle(of: value.location), angle(of: value.predictedEndLocation))
                model.flick(to: Int(round(-projected / Geo.spacing))) { normalized in
                    gate(.interpolatingSpring(
                        duration: 0.38,
                        bounce: 0.15,
                        initialVelocity: min(max(normalized, -6), 6)
                    ))
                }
            }
    }

    private func angle(of point: CGPoint) -> Double {
        atan2(point.y - geo.center.y, point.x - geo.center.x) * 180 / .pi
    }

    private func norm(_ from: Double, _ to: Double) -> Double {
        var delta = to - from
        while delta > 180 { delta -= 360 }
        while delta < -180 { delta += 360 }
        return delta
    }

    private func gate(_ animation: Animation) -> Animation {
        UIConstants.Animation.motionGate(animation, reduceMotion: reduceMotion)
    }
}

// MARK: - Orbit Card

/// Transform shell (position/rotation/offset/opacity — renderer-cheap) around
/// a static face. One persistent view morphs both ways; siblings fade out via
/// ternary modifiers (no branching, identity preserved).
private struct OrbitCard: View {
    @Bindable var model: CollectionsModel
    let card: Card
    let index: Int
    let geo: Geo
    let isExpanded: Bool
    let anyExpanded: Bool
    let onExpand: (Int) -> Void
    let onDismissChange: (CGSize) -> Void
    let onDismissEnd: (DragGesture.Value, Geo) -> Void

    var body: some View {
        let orbitAngle = model.rotation + Double(index) * Geo.spacing
        let angle = orbitAngle * .pi / 180
        let full = CGSize(width: geo.size.width, height: geo.size.height)
        let size = isExpanded ? full : CGSize(width: geo.card, height: geo.card)
        let position = isExpanded
            ? CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            : CGPoint(
                x: geo.center.x + geo.orbit * sin(angle),
                y: geo.center.y - geo.orbit * cos(angle)
            )
        let fade = isExpanded ? 1 - min(max(-model.dismiss / geo.dismissAt, 0), 1) : 0
        let corner = isExpanded
            ? geo.screenCorner + (geo.collapsedCorner - geo.screenCorner) * (1 - fade)
            : geo.collapsedCorner

        CardFace(card: card, size: size, corner: corner, isExpanded: isExpanded, contentOpacity: fade, geo: geo)
            .overlay {
                RoundedRectangle(cornerRadius: corner)
                    .stroke(.white.opacity(isExpanded ? 0 : 0.2), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .rotationEffect(.degrees(isExpanded ? model.landing : orbitAngle))
            .offset(y: model.dismiss)
            .position(position)
            .blur(radius: anyExpanded && !isExpanded ? 10 : 0)
            .opacity(isExpanded ? 1 : (anyExpanded ? 0 : 1))
            .zIndex(isExpanded ? 4 : (model.front == index ? 3.1 : 3))
            .allowsHitTesting(!anyExpanded || isExpanded)
            .onTapGesture { onExpand(index) }
            .simultaneousGesture(
                DragGesture(minimumDistance: 12, coordinateSpace: .local)
                    .onChanged { onDismissChange($0.translation) }
                    .onEnded { onDismissEnd($0, geo) }
            )
            .accessibilityLabel(card.name)
            .accessibilityHint(isExpanded ? "Swipe up to dismiss" : "Double tap to open")
            .accessibilityAddTraits(isExpanded ? [] : .isButton)
    }
}

// MARK: - Card Face

/// Static content: image, material scrim, title, and (when expanded) pager.
/// Inputs never change during disk drags, so re-evaluation diffs to nothing.
private struct CardFace: View {
    let card: Card
    let size: CGSize
    let corner: CGFloat
    let isExpanded: Bool
    let contentOpacity: Double
    let geo: Geo

    var body: some View {
        ZStack {
            Image(card.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .clipped()

            ZStack(alignment: isExpanded ? .top : .bottom) {
                scrim
                if isExpanded {
                    LoopPager(items: card.items, size: size)
                        .padding(.top, max(48, size.height * 0.12))
                        .padding(.bottom, max(72, size.height * 0.12))
                        .opacity(contentOpacity)
                        .transition(.opacity)
                }
                Text(card.name)
                    .font(.system(size: isExpanded ? 50 : 25, design: .serif))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .padding(.bottom, isExpanded ? 0 : max(12, size.height * 0.06))
                    .padding(.top, isExpanded ? max(20, size.height * 0.08) : 0)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: corner))
    }

    private var scrim: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner).fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: corner).fill(.black.opacity(0.75))
        }
        .mask(
            RadialGradient(
                stops: [
                    .init(color: isExpanded ? .black : .clear, location: 0),
                    .init(color: .black, location: 1)
                ],
                center: UnitPoint(x: 0.5, y: 0),
                startRadius: 0,
                endRadius: size.width * 0.9
            )
        )
    }
}

// MARK: - Infinite Pager

/// Three recycled pages (previous/current/next) instead of a thousand-view
/// TabView window: constant memory, no rebase hacks, native paging feel via
/// a velocity-projected snappy settle.
private struct LoopPager: View {
    let items: [CollectionItem]
    let size: CGSize
    @State private var index = 0
    @State private var drag: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let count = max(items.count, 1)
        HStack(spacing: 0) {
            Page(item: items[(index - 1 + count) % count], size: size)
            Page(item: items[index % count], size: size)
            Page(item: items[(index + 1) % count], size: size)
        }
        .frame(width: size.width * 3, alignment: .leading)
        .offset(x: -size.width + drag)
        .animation(
            UIConstants.Animation.motionGate(UIConstants.Animation.snappySpring, reduceMotion: reduceMotion),
            value: index
        )
        .gesture(
            DragGesture(minimumDistance: 12, coordinateSpace: .local)
                .onChanged { value in
                    guard count > 1 else { return }
                    drag = abs(value.translation.width) > abs(value.translation.height)
                        ? value.translation.width : 0
                }
                .onEnded { value in
                    guard count > 1 else { return }
                    let step: Int
                    if value.translation.width < -size.width * 0.25 || value.velocity.width < -700 {
                        step = 1
                    } else if value.translation.width > size.width * 0.25 || value.velocity.width > 700 {
                        step = -1
                    } else {
                        step = 0
                    }
                    drag = 0
                    if step != 0 { index = (index + step + count * 1024) % count }
                }
        )
        .sensoryFeedback(.selection, trigger: index)
        .accessibilityElement(children: .contain)
    }
}

private struct Page: View {
    let item: CollectionItem
    let size: CGSize

    var body: some View {
        VStack(spacing: 16) {
            Text(item.emoji)
                .font(.system(size: min(size.width * 0.34, 150)))
            Text(item.task)
                .font(.system(.title2, design: .serif))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 24)
        }
        .frame(width: size.width, height: size.height)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), \(item.task)")
    }
}

// MARK: - Preview

#Preview {
    CollectionsView()
}
