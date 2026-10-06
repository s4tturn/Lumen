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

    func fold(epoch: Int) {
        guard epoch == self.epoch, expanded == nil, !dragging else { return }
        let turns = -Int(round(rotation / 360))
        guard turns != 0 else { return }
        withTransaction(Transaction()) { rotation += 360 * Double(turns) }
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
