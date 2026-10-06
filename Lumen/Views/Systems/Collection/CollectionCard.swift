import SwiftUI

// MARK: - Collection

/// One themed group of tasks — a single spoke of the wheel.
///
/// Immutable and value-typed: the catalog is a `static let`, so a collection's
/// contents can never change while a view holds one.
struct Collection: Identifiable, Equatable, Sendable {
    /// A stable, hand-written identifier such as `self` or `kitchen`.
    ///
    /// Written by hand rather than generated. It outlives the process, the
    /// catalog's ordering, and the device, so anything persisted or synced can
    /// key off it. Never widen this to a `UUID`: a generated identity is
    /// different on every launch, which makes persistence impossible by
    /// construction.
    struct ID: Hashable, Sendable, CustomStringConvertible {
        let rawValue: String

        init(_ rawValue: String) {
            self.rawValue = rawValue
        }

        var description: String { rawValue }
    }

    let id: ID
    /// The wheel slot's name. A `LocalizedStringResource` rather than a `String`
    /// so the string is extractable — a runtime `String` yields no key for the
    /// compiler to localise, and silently stays English forever.
    let title: LocalizedStringResource
    /// Typed asset reference rather than a name string: a renamed or deleted
    /// asset becomes a compile error instead of an empty `Image` at runtime.
    let background: ImageResource
    let tasks: [CollectionTask]

    /// This collection's task with the given identity, if it has one.
    func task(with id: CollectionTask.ID) -> CollectionTask? {
        tasks.first { $0.id == id }
    }
}

// MARK: - Task

/// The smallest thing a person can complete: one task inside a `Collection`.
///
/// Identical in kind to `Collection`, and never interchangeable with it — the two
/// identities are distinct types on purpose, so a collection can never be
/// passed where a task is expected.
struct CollectionTask: Identifiable, Equatable, Sendable {
    /// A stable, hand-written identifier, namespaced by its collection.
    ///
    /// The prefix is load-bearing, not decoration: `space.beauty` and
    /// `joy.beauty` are two different tasks that happen to share a title, so a
    /// bare `beauty` would collide. This value is the key a completion is filed
    /// under in the keychain, so it must never change once written — renaming a
    /// task's *text* is free, renaming this is a data migration.
    struct ID: Hashable, Sendable, CustomStringConvertible {
        let rawValue: String

        init(_ rawValue: String) {
            self.rawValue = rawValue
        }

        var description: String { rawValue }
    }

    let id: ID
    /// A short label — the task's name on its own. Used where the instruction
    /// would be too much: VoiceOver, the completed list in Memory.
    let title: LocalizedStringResource
    /// The instruction itself: the sentence that tells you what to actually do.
    let instruction: LocalizedStringResource
    /// A pictogram standing in for the task. A `String` rather than an SF Symbol
    /// name because emoji need no asset and carry their own colour and weight.
    ///
    /// Emoji do not scale on their own, so whatever draws one is responsible for
    /// sizing it with `@ScaledMetric` — a fixed point size here would be the one
    /// part of a task that ignores Dynamic Type. Swapping the catalog wholesale
    /// to SF Symbols is a one-line change if that trade is ever revisited.
    let symbol: String
}
import SwiftUI

// MARK: - Pager

/// One collection's tasks, one at a time, paged by the system.
///
/// The visible task is not local state — it is the app's `CollectionFocus` —
/// because the ambient player's Complete control acts on whatever is on screen
/// here. Two answers to "which task is showing" would eventually disagree, and
/// the disagreeing one files a completion against the wrong task.
///
/// The binding runs both ways: the scroll view writes the page it settled on,
/// and the wheel writes the first task as a card expands. That second write is
/// what opens the pager where the person left off rather than wherever the
/// content happens to lay out.
struct CollectionTaskPager: View {
    let tasks: [CollectionTask]
    @Bindable var focus: CollectionFocus

    var body: some View {
        VStack(spacing: PagerMetrics.pageGap) {
            pages
            // Handed the focus rather than the visible task on purpose: reading
            // `focus.task` in this body would invalidate the whole pager on every
            // page turn, and the only thing that changes is five capsules.
            PagerDots(tasks: tasks, focus: focus)
        }
        // The pager's own layout inside the open card: pages above,
        // page marks below.
        .debugSurfaceBorder()
    }

    /// `containerRelativeFrame` rather than the card's own width: a page fills
    /// exactly what the scroll view can show, so the pager keeps no second copy
    /// of the layout's dimensions to fall out of step with the card it lives in.
    ///
    /// With `.scrollTargetLayout()` and `.paging` that is the entire paging
    /// contract — no page-index arithmetic, no recycled three-view window, no
    /// velocity thresholds to tune, and off-page tasks cost nothing because the
    /// stack is lazy.
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

// MARK: - Position

/// Where you are in the collection: one capsule per task, the visible one
/// stretched.
///
/// Reads the focus itself rather than being handed a visible task, so a page
/// turn invalidates these few capsules and nothing else — the scroll view and
/// every task page inside it are untouched by which page happens to be showing.
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
        // The page marks' own row: the strip that shows how much is
        // left to page through.
        .debugSurfaceBorder()
        .animation(
            UIConstants.Animation.reduceMotionGate(UIConstants.Animation.commit, reduceMotion: reduceMotion),
            value: focus.task
        )
        // Position, not content: the tasks themselves are already in the
        // accessibility tree, and a row of anonymous capsules would only be read
        // out as noise between them.
        .accessibilityHidden(true)
        // The tick rides the dots because they are the one view that already
        // changes when the visible page does — the trigger is the page, wherever
        // the gesture happened to end.
        .sensoryFeedback(.selection, trigger: focus.task)
    }

    private func isVisible(_ task: CollectionTask) -> Bool {
        task.id == focus.task
    }
}

// MARK: - Page

/// One task: the pictogram, and the sentence that says what to do.
private struct CollectionTaskPage: View {
    let task: CollectionTask

    /// Emoji carry no point size of their own, so this is where the size lives —
    /// and it scales, because a fixed-size pictogram would be the one part of a
    /// task that ignores the person's text size. 150pt is what it reads at the
    /// default size.
    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize: CGFloat = 150

    var body: some View {
        VStack(spacing: PagerMetrics.pageGap) {
            Text(task.symbol)
                .font(.system(size: symbolSize))
                // The sentence below already says it; announcing a bare
                // "walking man" first would only get in the way.
                .accessibilityHidden(true)

            Text(task.instruction)
                .font(.system(.title2, design: .serif))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
        }
        // Padding first, then the greedy frame: the other way round the padding
        // would sit outside the frame and the page would overflow its own width.
        .padding(.horizontal, PagerMetrics.pageInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // One page's own frame inside the scroll view: the unit the
        // pager pages by.
        .debugSurfaceBorder()
        // One element rather than two, so VoiceOver reads a task as the single
        // thing it is instead of as a pictogram followed by a sentence. No line
        // limit: at large text sizes the sentence is allowed to run long rather
        // than be cut off mid-thought.
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Metrics

/// Pager dimensions, in one place. Dot and gap sizes are related by
/// multiplication rather than restated, so the rhythm survives a change to any
/// one of them.
private enum PagerMetrics {
    static let dotHeight: CGFloat = 6
    static let restWidth: CGFloat = 6
    static let activeWidth: CGFloat = 20
    /// Unselected capsules recede rather than shrink to nothing: a page mark that
    /// disappears entirely is one fewer cue about how much is left to see.
    static let restOpacity: Double = 0.4
    static let gap: CGFloat = 8
    /// Space between a task's pictogram and its sentence, and between the pages
    /// and the dots. One value so the two never drift into uneven rhythm.
    static let pageGap: CGFloat = dotHeight * 3
    static let pageInset: CGFloat = 24
}
import SwiftUI

// MARK: - Disk

/// The page's only glass surface in its own container (glass cannot sample
/// glass). Ticks render in one Canvas pass — no per-tick views to invalidate.
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
            // The turntable's glass and hit area, one circle: the
            // surface every drag turns.
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

// MARK: - Orbit Card

/// Transform shell (position/rotation/offset/opacity — renderer-cheap) around
/// a static face. One persistent view morphs both ways; siblings fade out via
/// ternary modifiers (no branching, identity preserved).
struct OrbitCard: View {
    @Bindable var model: CollectionsModel
    let collection: Collection
    let focus: CollectionFocus
    let index: Int
    let geo: Geo
    let isExpanded: Bool
    let anyExpanded: Bool
    /// Fixed corner radius for the card's stroke, hit area and clip — the
    /// screen's own radius, so an expanded card's curve continues the display's
    /// instead of guessing at it.
    let cornerRadius: CGFloat
    let onExpand: (Int) -> Void
    /// Drag in progress and drag finished, reported as drags. One gesture serves
    /// two purposes — it lifts an open card away and it turns the wheel when
    /// nothing is open — and the card does not know which, so it sends the
    /// translation and the view above decides what it meant. Routing here rather
    /// than firing both and letting each decline would make the exclusivity a fact
    /// the reader has to go looking for.
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
            // The shell above is the whole drag: every sample rewrites the wheel's
            // rotation, which re-renders this card. None of it reaches the face —
            // same collection, same size, same opacity — so the check below stops
            // the image, the scrim's radial mask and the title from being rebuilt
            // sixty times a second while nothing about them has moved.
            .equatable()
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(isExpanded ? 0 : 0.2), lineWidth: 1)
            }
            // Each card's own frame, in its own colour: where every
            // slot sits on the wheel, and where a card lands expanded.
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

// MARK: - Card Face

/// Static content: image, material scrim, title, and (when expanded) pager.
///
/// Equatable on purpose, and written by hand because the focus is a shared
/// object: identity is the right comparison for it, and every other input is a
/// value. Turning a disk rewrites the wheel's rotation, which rebuilds every
/// card around it, and a disk drag does all of that sixty times a second without
/// touching one of these inputs. Equating them makes the skip explicit instead
/// of leaving it to the diff.
struct CardFace: View {
    let collection: Collection
    let focus: CollectionFocus
    let size: CGSize
    let isExpanded: Bool
    let contentOpacity: Double
    /// Fixed corner radius — the screen's own, so the clip and the scrim carry
    /// one curve and cannot disagree at the corner.
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
