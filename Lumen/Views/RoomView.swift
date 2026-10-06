import SwiftUI

/// Room page: a room from `RoomScene.all`, seen from a fixed isometric camera
/// that centres that room's own silhouette. Drag inside the circle to turn it;
/// taps and gestures outside it are left for the pager.
///
/// The page holds one piece of state, `stage`, and a drag writes only to fields
/// the stage does not publish — so turning a room costs a quaternion write, a
/// handful of wall opacities, and no SwiftUI work at all.
///
/// Switching rooms is the one thing here that does drive SwiftUI, because it is
/// a transition and a transition is the view's job. The tab names a room, the
/// stage travels to it, and the page reads back only `slide` and `fade` — two
/// numbers, each written twice per switch.
struct RoomView: View {
    /// Mirrors the pager's liveness: the RealityKit graph is parked while
    /// off-live and resumes a touch before becoming visible.
    var isLive: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showCredits = false
    @State private var stage: RoomStage

    init(isLive: Bool = true) {
        self.isLive = isLive
        _stage = State(initialValue: RoomStage())
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // The model travels; the turn handle does not. A circle that
                // slid off screen mid-switch would take the drag target with it,
                // and the room has to be turnable the instant it lands.
                RoomRealityStage(stage: stage, scene: stage.shown)
                    // The switch. The room leaves through the edge the tab moved
                    // towards and comes back in from the far one, receding as it
                    // goes, so the two are never both on screen and the seam is
                    // never drawn. Reduce Motion leaves `slide` at zero and
                    // carries the change on `fade` instead — a dissolve, not a
                    // room sent across the screen.
                    .offset(x: stage.slide * proxy.size.width)
                    .scaleEffect(1 - abs(stage.slide) * RoomStage.travelRecede)
                    .opacity(stage.fade)
                RoomTurnHandle(diameter: proxy.size.width, stage: stage)
            }
            .overlay(alignment: .top) {
                RoomTab(selection: roomBinding, isCreditsActive: showCredits) {
                    showCredits = true
                }
                .padding(.top, proxy.size.height * RoomTabMetrics.topFraction)
                .padding(.horizontal, UIConstants.General.safeSpace)
            }
            // The camera fits itself to the viewport it is drawn into, so the
            // page has to hand that viewport over — once here, and again on every
            // rotation or window drag, which is what stops a room framed for a
            // portrait screen being measured against a landscape one.
            .onGeometryChange(for: CGSize.self) { $0.size } action: {
                stage.setViewport($0)
            }
        }
        .sheet(isPresented: $showCredits) {
            CreditsSheet()
                .presentationDetents([.fraction(0.8)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
        }
        // `initial` so the page parks itself the moment it mounts. Without it the
        // room graph stayed enabled for a whole session whenever the app opened
        // anywhere but the room tab: invisible, untouchable, and still costing
        // RealityKit a full render of a scene nobody could see. `setActive` is a
        // no-op when the state already matches, so the live case still pays one
        // comparison.
        .onChange(of: isLive, initial: true) { _, live in stage.setActive(live) }
        // Rewards follow the keychain's record of finished tasks, in whichever
        // direction they are filed. In a modifier of its own rather than inline,
        // because the finished set is read only to feed the stage and never to
        // draw anything: leaving it in this body would have every completion
        // re-evaluate the whole page — the stage's scene and turn handle, the tab
        // overlay, and with them every update pass through the RealityView — for a
        // dependency that changes nothing on screen. Owning it here also keeps the
        // read out from behind the `.equatable()` layers this page is built on, so
        // the stage is told what has been finished rather than being told only
        // when something else happens to redraw.
        .earnRewards(stage: stage)
        // Warms the other rooms while this page is the one on screen, so the
        // middle of a switch is a graph swap rather than a load. Keyed to
        // liveness because a page nobody is looking at gains nothing by it, and
        // warm graphs are kept either way.
        .task(id: isLive) {
            guard isLive else { return }
            await stage.prefetchOthers()
        }
        // Rides the switch rather than the tap that asked for it, so the tick
        // lands with the room arriving instead of with the tab leaving.
        .sensoryFeedback(.selection, trigger: stage.settleTick)
        // The pinch's two haptics, and deliberately two of them. A soft
        // impact the instant the band takes hold says *push harder*, and it is the
        // only cue that can make a limit feel like elasticity rather than like a
        // mistake; the selection tick when the room lands back on its framing says
        // *stop*, and it rides the pixels arriving rather than the fingers leaving,
        // which is the same argument `settleTick` makes above. One haptic asked to
        // mean both would say neither.
        .sensoryFeedback(.impact(flexibility: .soft), trigger: stage.pinchTick)
        .sensoryFeedback(.selection, trigger: stage.pinchArriveTick)
        .accessibilityLabel("Room")
        .accessibilityAddTraits(.isHeader)
    }

    /// The tab's selection. Writing it is a request, not an assignment: the stage
    /// drops a tap on the room already showing, and otherwise starts the switch —
    /// or retargets one already running, which the tab has already committed to.
    private var roomBinding: Binding<RoomScene> {
        Binding(
            get: { stage.selection },
            set: { stage.select($0, reduceMotion: reduceMotion) }
        )
    }
}

#Preview {
    RoomView()
        .environment(CollectionStore())
}