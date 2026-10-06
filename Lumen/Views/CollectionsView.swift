import SwiftUI

struct CollectionsView: View {
    @Binding private var collectionsExpanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Environment(CollectionFocus.self) private var focus
    @State private var model = CollectionsModel()

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

        model.landing = 360 * round((model.rotation + Double(index) * CollectionCatalog.spacing) / 360)
        withAnimation(expandAnimation) {
            model.expanded = index
            model.front = index
            collectionsExpanded = true

            focus.task = CollectionCatalog.all[index].tasks.first?.id
        }
    }

    private func cardDragChanged(_ translation: CGSize) {
        guard model.expanded != nil else { return }
        model.dismiss = abs(translation.height) > abs(translation.width) ? min(0, translation.height) : 0
    }

    private func cardDragEnded(_ value: DragGesture.Value, geo: Geo) {
        if model.expanded != nil {
            dismissCard(value, geo: geo)
        } else {
            stepWheel(value, geo: geo)
        }
    }

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

                focus.task = nil
            }
            model.dismiss = 0
        }
    }

    private func stepWheel(_ value: DragGesture.Value, geo: Geo) {

        let travel = abs(value.translation.width) > abs(value.translation.height)
            ? value.translation.width
            : value.velocity.width
        guard abs(value.translation.width) >= geo.stepAt || abs(value.velocity.width) >= geo.stepFlick
        else { return }

        model.settle(
            model.focused + (travel < 0 ? 1 : -1),
            animation: UIConstants.Animation.reduceMotionGate(
                UIConstants.Animation.commit, reduceMotion: reduceMotion)
        )
    }
}

@MainActor @Observable
final class CollectionsModel {
    var rotation = 0.0            // kept within [-180, 180] so the orbit never spins the long way
    var expanded: Int?
    var front: Int?
    var dismiss: CGFloat = 0
    var landing = 0.0
    var ridge = 0
    var dragging = false
    @ObservationIgnored var fingerAngle = 0.0
    @ObservationIgnored var fingerTime = Date.distantPast
    @ObservationIgnored var velocity = 0.0

    var focused: Int {
        let raw = Int(round(-rotation / CollectionCatalog.spacing))
        let count = CollectionCatalog.count
        return ((raw % count) + count) % count
    }

    /// Wraps any angle into [-180, 180].
    func normalized(_ degrees: Double) -> Double {
        var d = degrees.truncatingRemainder(dividingBy: 360)
        while d > 180 { d -= 360 }
        while d < -180 { d += 360 }
        return d
    }

    /// Keeps `rotation` wrapped so card rotation and orbit position always animate
    /// along the shortest path instead of spinning multiple turns.
    func normalizeRotation() {
        rotation = normalized(rotation)
    }

    /// The multiple-of-360 shift of the destination closest to `rotation`, so a
    /// settle or flick never interpolates more than half a turn.
    private func destinationClosest(to target: Int) -> Double {
        var destination = Double(-target) * CollectionCatalog.spacing
        while destination - rotation > 180 { destination -= 360 }
        while destination - rotation < -180 { destination += 360 }
        return destination
    }

    func settle(_ target: Int, animation: Animation) {
        normalizeRotation()
        let destination = destinationClosest(to: target)
        withAnimation(animation) {
            rotation = destination
        } completion: {
            self.normalizeRotation()
        }
        ridge = target
    }

    func flick(to target: Int, animation: (Double) -> Animation) {
        normalizeRotation()
        let destination = destinationClosest(to: target)
        let remaining = destination - rotation
        withAnimation(animation(remaining == 0 ? 0 : velocity / remaining)) {
            rotation = destination
        } completion: {
            self.normalizeRotation()
        }
        ridge = target
    }
}

struct Geo: Sendable {
    let size: CGSize
    var radius: CGFloat { size.height * 0.35 }
    var card: CGFloat { radius * 2 * 0.5 }
    var orbit: CGFloat { radius * 1.2 + card / 2 }
    var center: CGPoint { CGPoint(x: size.width / 2, y: size.height) }
    var deadZone: CGFloat { radius * 0.06 }
    var dismissAt: CGFloat { card * 0.15 }

    var stepAt: CGFloat { card * 0.25 }

    var stepFlick: CGFloat { 900 }
    var tick: CGSize { CGSize(width: radius * 0.03, height: radius * 0.125) }
}

#Preview {
    CollectionsView()
}
