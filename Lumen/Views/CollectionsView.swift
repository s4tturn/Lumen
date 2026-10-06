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
    /// Which task the open card is showing, shared with the ambient player so the
    /// Complete control acts on what is actually on screen.
    @Environment(CollectionFocus.self) private var focus
    @State private var model = CollectionsModel()
    /// The screen's own corner radius, handed to every card as its fixed corner
    /// radius. Starts at zero until SwiftUI resolves it — the same first-frame
    /// settle `CollectionsModel` already has.
    @State private var screenCornerRadius: CGFloat = 0

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

            DiskView(model: model, geo: geo, focusedTitle: CollectionCatalog.all[model.focused].title)
                .zIndex(2)
                .allowsHitTesting(expanded == nil)

            // The catalog's own index range, which is constant: identity is the
            // slot rather than a value rebuilt per evaluation, so the loop
            // allocates nothing and reuses one view per card.
            ForEach(CollectionCatalog.all.indices, id: \.self) { index in
                OrbitCard(
                    model: model,
                    collection: CollectionCatalog.all[index],
                    focus: focus,
                    index: index,
                    geo: geo,
                    isExpanded: expanded == index,
                    anyExpanded: expanded != nil,
                    cornerRadius: screenCornerRadius,
                    onExpand: expand,
                    onDragChange: cardDragChanged,
                    onDragEnd: cardDragEnded
                )
            }
        }
        .frame(width: pageSize.width, height: pageSize.height)
        // The screen's own corner radius, read here because this is the outermost
        // point in the page still resolving against the screen container — every
        // card below reads the one number this hands down.
        .onGeometryChange(for: CGFloat.self) { $0.screenCornerRadius } action: { screenCornerRadius = $0 }
        .coordinateSpace(.named("CollectionsView"))
        .sensoryFeedback(.selection, trigger: model.ridge)
        .sensoryFeedback(.impact, trigger: expanded)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Collections")
        .accessibilityHint("Rotate the disk to browse collections, tap a card to open it")
    }

    private var expandAnimation: Animation {
        UIConstants.Animation.reduceMotionGate(UIConstants.Animation.dwell, reduceMotion: reduceMotion)
    }

    private func expand(_ index: Int) {
        guard model.expanded == nil else { return }
        // Nearest straight angle: the morph always takes the shortest path.
        model.landing = 360 * round((model.rotation + Double(index) * CollectionCatalog.spacing) / 360)
        withAnimation(expandAnimation) {
            model.expanded = index
            model.front = index
            collectionsExpanded = true
            // Opened on the first task, inside this same animation so the
            // ambient control morphs in with the card rather than a frame later.
            focus.task = CollectionCatalog.all[index].tasks.first?.id
        }
    }

    /// An open card's drag in progress: it follows the finger straight up and
    /// holds still sideways, so a horizontal swipe on an open card does not read
    /// as half-dismissing it. Only translates, never rotates — no animation is
    /// involved, because the card is already moving because the finger is.
    private func cardDragChanged(_ translation: CGSize) {
        guard model.expanded != nil else { return }
        model.dismiss = abs(translation.height) > abs(translation.width) ? min(0, translation.height) : 0
    }

    /// The one drag, split by the state that tells the two purposes apart: a card
    /// that is open gets lifted away, a card on the wheel gets turned. Nothing but
    /// `expanded` separates them, which is why it cannot be a coincidence of
    /// direction — a card is either open or it is not.
    private func cardDragEnded(_ value: DragGesture.Value, geo: Geo) {
        if model.expanded != nil {
            dismissCard(value, geo: geo)
        } else {
            stepWheel(value, geo: geo)
        }
    }

    /// Called only from `cardDragEnded`, which has already established that a card
    /// is open.
    private func dismissCard(_ value: DragGesture.Value, geo: Geo) {
        let vertical = abs(value.translation.height) > abs(value.translation.width)
        let shouldDismiss = vertical
            && (value.translation.height < -geo.dismissAt || value.velocity.height < -800)
        withAnimation(
            UIConstants.Animation.reduceMotionGate(
                shouldDismiss ? UIConstants.Animation.commit : UIConstants.Animation.dwell, reduceMotion: reduceMotion)
        ) {
            if shouldDismiss {
                model.expanded = nil
                collectionsExpanded = false
                // Retracted with the card, never before: a completion can only be
                // made against a task that is on screen, so the focus's lifetime
                // is exactly the card's.
                focus.task = nil
            }
            model.dismiss = 0
        }
    }

    /// A swipe on a card while none is open, turning the wheel one card along: the
    /// wheel's own answer for anyone who wants to browse without turning it.
    ///
    /// Scoped by construction, not by a test. The gesture is attached to the card,
    /// whose `contentShape` is its own rounded rect and whose z-order puts it above
    /// the disk, so a touch that lands on a card is the card's and a touch beside
    /// one falls through to the disk's turntable drag untouched. Nothing here has to
    /// know where the card is on screen to keep the swipe off the space around it.
    ///
    /// One card per swipe, decided on release, and deliberately not a 1:1 drag: the
    /// wheel already has a gesture that tracks the finger, and a second one
    /// measuring the same movement differently would leave the rotation depending on
    /// which part of the screen the finger started in. A step is also what every
    /// other sideways carousel does, and what the wheel's adjustable action does,
    /// so the two ways of moving here agree exactly.
    ///
    /// `settle` rather than `flick`: `flick` hands the spring the wheel's own
    /// angular velocity, which a horizontal swipe does not produce and this does not
    /// invent. It sets `ridge` as it goes, which is the trigger for the selection
    /// tick — so arriving on the next card ticks, the same way settling a turn does.
    private func stepWheel(_ value: DragGesture.Value, geo: Geo) {
        // Horizontal intent only, so a diagonal or vertical drag on a card is not
        // read as a request to change collection. Same axis test as the dismiss.
        let travel = abs(value.translation.width) > abs(value.translation.height)
            ? value.translation.width
            : value.velocity.width
        guard abs(value.translation.width) >= geo.stepAt || abs(value.velocity.width) >= geo.stepFlick
        else { return }
        // Left brings the next card in from the right: a card index is an angle
        // added to the rotation, so moving left is a smaller angle, a bigger index.
        // `settle` derives the rotation from a wrapped index, so this always lands
        // inside one turn however often it is repeated.
        model.settle(
            model.focused + (travel < 0 ? 1 : -1),
            animation: UIConstants.Animation.reduceMotionGate(
                UIConstants.Animation.commit, reduceMotion: reduceMotion)
        )
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
        let raw = Int(round(-rotation / CollectionCatalog.spacing))
        let count = CollectionCatalog.count
        return ((raw % count) + count) % count
    }

    func settle(_ target: Int, animation: Animation) {
        epoch += 1
        let current = epoch
        withAnimation(animation) {
            rotation = Double(-target) * CollectionCatalog.spacing
        } completion: {
            self.fold(epoch: current)
        }
        ridge = target
    }

    func flick(to target: Int, animation: (Double) -> Animation) {
        epoch += 1
        let current = epoch
        let destination = Double(-target) * CollectionCatalog.spacing
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
///
/// Internal because the wheel's card and disk read the same geometry the page
/// derived — one measurement, shared, rather than a second copy that could drift.
struct Geo: Sendable {
    let size: CGSize
    var radius: CGFloat { size.height * 0.35 }
    var card: CGFloat { radius * 2 * 0.5 }
    var orbit: CGFloat { radius * 1.2 + card / 2 }
    var center: CGPoint { CGPoint(x: size.width / 2, y: size.height) }
    var deadZone: CGFloat { radius * 0.06 }
    var dismissAt: CGFloat { card * 0.15 }
    /// Horizontal travel, or the speed of a flick too short for that, that turns
    /// the wheel one card along from a swipe on a card.
    ///
    /// A quarter of the card's own width rather than a fraction of the page, so
    /// the commitment scales with the thing being swiped. Deliberately larger than
    /// `dismissAt`: putting a card away and changing collection are not the same
    /// level of decision, and one gesture now answers to both.
    var stepAt: CGFloat { card * 0.25 }
    /// Points per second at which a card swipe counts without having travelled
    /// `stepAt`, in the same band as the dismiss's own velocity escape. A sharp
    /// flick is as deliberate as a long slow drag, and neither should be thrown
    /// away for being small.
    var stepFlick: CGFloat { 900 }
    var tick: CGSize { CGSize(width: radius * 0.03, height: radius * 0.125) }
}

// MARK: - Preview

#Preview {
    CollectionsView()
}
