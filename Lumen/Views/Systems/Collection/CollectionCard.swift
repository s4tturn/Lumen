import SwiftUI

struct Collection: Identifiable, Equatable, Sendable {

    struct ID: Hashable, Sendable, CustomStringConvertible {
        let rawValue: String

        init(_ rawValue: String) {
            self.rawValue = rawValue
        }

        var description: String { rawValue }
    }

    let id: ID

    let title: LocalizedStringResource

    let background: ImageResource
    let tasks: [CollectionTask]

    func task(with id: CollectionTask.ID) -> CollectionTask? {
        tasks.first { $0.id == id }
    }
}

struct CollectionTask: Identifiable, Equatable, Sendable {

    struct ID: Hashable, Sendable, CustomStringConvertible {
        let rawValue: String

        init(_ rawValue: String) {
            self.rawValue = rawValue
        }

        var description: String { rawValue }
    }

    let id: ID

    let title: LocalizedStringResource

    let instruction: LocalizedStringResource

    let symbol: String
}
import SwiftUI

struct CollectionTaskPager: View {
    let tasks: [CollectionTask]
    @Bindable var focus: CollectionFocus

    var body: some View {
        VStack(spacing: PagerMetrics.pageGap) {
            pages

            PagerDots(tasks: tasks, focus: focus)
        }

        .debugSurfaceBorder()
    }

    private var pages: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(tasks) { task in
                    CollectionTaskPage(task: task)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $focus.task)
    }
}

private struct PagerDots: View {
    let tasks: [CollectionTask]
    let focus: CollectionFocus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: PagerMetrics.gap) {
            ForEach(tasks) { task in
                Capsule()
                    .fill(.white)
                    .frame(width: isVisible(task) ? PagerMetrics.activeWidth : PagerMetrics.restWidth,
                           height: PagerMetrics.dotHeight)
                    .opacity(isVisible(task) ? 1 : PagerMetrics.restOpacity)
            }
        }

        .debugSurfaceBorder()
        .animation(
            UIConstants.Animation.reduceMotionGate(UIConstants.Animation.commit, reduceMotion: reduceMotion),
            value: focus.task
        )

        .accessibilityHidden(true)

        .sensoryFeedback(.selection, trigger: focus.task)
    }

    private func isVisible(_ task: CollectionTask) -> Bool {
        task.id == focus.task
    }
}

private struct CollectionTaskPage: View {
    let task: CollectionTask

    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize: CGFloat = 150

    var body: some View {
        VStack(spacing: PagerMetrics.pageGap) {
            Text(task.symbol)
                .font(.system(size: symbolSize))

                .accessibilityHidden(true)

            Text(task.instruction)
                .font(.system(.title2, design: .serif))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
        }

        .padding(.horizontal, PagerMetrics.pageInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        .debugSurfaceBorder()

        .accessibilityElement(children: .combine)
    }
}

private enum PagerMetrics {
    static let dotHeight: CGFloat = 6
    static let restWidth: CGFloat = 6
    static let activeWidth: CGFloat = 20

    static let restOpacity: Double = 0.4
    static let gap: CGFloat = 8

    static let pageGap: CGFloat = dotHeight * 3
    static let pageInset: CGFloat = 24
}
import SwiftUI

struct DiskView: View {
    @Bindable var model: CollectionsModel
    let geo: Geo
    let focusedTitle: LocalizedStringResource
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GlassEffectContainer {
            ZStack {
                Circle().fill(.black.opacity(0.6))
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    for tick in 0..<CollectionCatalog.count {
                        context.drawLayer { layer in
                            layer.translateBy(x: center.x, y: center.y)
                            layer.rotate(by: .radians(Double(tick) * CollectionCatalog.spacing * .pi / 180))
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
                .rotationEffect(.degrees(model.rotation))
            }
            .frame(width: geo.radius * 2, height: geo.radius * 2)
            .glassEffect(.regular, in: Circle())
            .contentShape(Circle())

            .debugSurfaceBorder(Circle())
            .position(geo.center)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Collections disk")
            .accessibilityValue(Text(focusedTitle))
            .accessibilityHint("Swipe up or down to browse collections")
            .accessibilityAdjustableAction { direction in
                model.settle(
                    model.focused + (direction == .increment ? 1 : -1),
                    animation: UIConstants.Animation.reduceMotionGate(
                        UIConstants.Animation.commit, reduceMotion: reduceMotion)
                )
            }
            .gesture(diskDrag)
        }
    }

    private var diskDrag: some Gesture {

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
                    model.ridge = Int(floor(-model.rotation / CollectionCatalog.spacing))
                    return
                }
                let step = norm(model.fingerAngle, current)
                let dt = max(value.time.timeIntervalSince(model.fingerTime), 1e-3)
                model.velocity += 0.35 * ((step / dt) - model.velocity)
                model.rotation += step
                model.fingerAngle = current
                model.fingerTime = value.time
                model.ridge = Int(floor(-model.rotation / CollectionCatalog.spacing))
            }
            .onEnded { value in
                defer {
                    model.dragging = false
                    model.velocity = 0
                }
                guard model.expanded == nil, model.dragging else {
                    model.settle(
                        Int(round(-model.rotation / CollectionCatalog.spacing)),
                        animation: gate(UIConstants.Animation.commit)
                    )
                    return
                }
                func clear(_ point: CGPoint) -> Bool {
                    hypot(point.x - center.x, point.y - center.y) >= dead
                }
                guard clear(value.location), clear(value.predictedEndLocation) else {
                    model.settle(Int(round(-model.rotation / CollectionCatalog.spacing)), animation: gate(UIConstants.Animation.commit))
                    return
                }
                let projected = model.rotation + norm(angle(of: value.location), angle(of: value.predictedEndLocation))
                model.flick(to: Int(round(-projected / CollectionCatalog.spacing))) { normalized in
                    UIConstants.Animation.releaseSpring(initialVelocity: normalized, reduceMotion: reduceMotion)
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
        UIConstants.Animation.reduceMotionGate(animation, reduceMotion: reduceMotion)
    }
}

struct OrbitCard: View {
    @Bindable var model: CollectionsModel
    let collection: Collection
    let focus: CollectionFocus
    let index: Int
    let geo: Geo
    let isExpanded: Bool
    let anyExpanded: Bool

    let cornerRadius: CGFloat
    let onExpand: (Int) -> Void

    let onDragChange: (CGSize) -> Void
    let onDragEnd: (DragGesture.Value, Geo) -> Void

    var body: some View {
        let orbitAngle = model.rotation + Double(index) * CollectionCatalog.spacing
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

        CardFace(
                collection: collection,
                focus: focus,
                size: size,
                isExpanded: isExpanded,
                contentOpacity: fade,
                cornerRadius: cornerRadius
            )

            .equatable()
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(isExpanded ? 0 : 0.2), lineWidth: 1)
            }

            .debugSurfaceBorder(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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
                    .onChanged { onDragChange($0.translation) }
                    .onEnded { onDragEnd($0, geo) }
            )
            .accessibilityLabel(Text(collection.title))
            .accessibilityHint(isExpanded ? "Swipe up to dismiss" : "Double tap to open")
            .accessibilityAddTraits(isExpanded ? [] : .isButton)
    }
}

struct CardFace: View {
    let collection: Collection
    let focus: CollectionFocus
    let size: CGSize
    let isExpanded: Bool
    let contentOpacity: Double

    let cornerRadius: CGFloat

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        ZStack {
            Image(collection.background)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .clipped()

            ZStack(alignment: isExpanded ? .top : .bottom) {
                scrim
                if isExpanded {
                    CollectionTaskPager(tasks: collection.tasks, focus: focus)
                        .padding(.top, max(48, size.height * 0.12))
                        .padding(.bottom, max(72, size.height * 0.12))
                        .opacity(contentOpacity)
                        .transition(.opacity)
                }
                Text(collection.title)
                    .font(.system(size: isExpanded ? 50 : 25, design: .serif))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .padding(.bottom, isExpanded ? 0 : max(12, size.height * 0.06))
                    .padding(.top, isExpanded ? max(20, size.height * 0.08) : 0)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
    }

    private var scrim: some View {
        ZStack {
            shape.fill(.ultraThinMaterial)
            shape.fill(.black.opacity(0.75))
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

extension CardFace: Equatable {
    static func == (a: CardFace, b: CardFace) -> Bool {
        a.collection == b.collection
            && a.focus === b.focus
            && a.size == b.size
            && a.isExpanded == b.isExpanded
            && a.contentOpacity == b.contentOpacity
            && a.cornerRadius == b.cornerRadius
    }
}
