import SwiftUI

/// Room page: the untitled model from the USDZ, seen from a fixed isometric
/// camera that frames the model's own bounds. Drag inside the circle to turn the
/// room; taps and gestures outside it are left for the pager.
///
/// The page holds one piece of state, `stage`, and a drag writes only to fields
/// the stage does not publish — so turning the room costs a quaternion write
/// and no SwiftUI work at all.
struct RoomView: View {
    /// Mirrors the pager's liveness: the RealityKit graph is parked while
    /// off-live and resumes a touch before becoming visible.
    var isLive: Bool = true

    @State private var stage = RoomStage()

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoomRealityStage(stage: stage)
                RoomTurnHandle(diameter: proxy.size.width, stage: stage)
            }
            // TEMP-BASELINE: safe-center shift removed for the model-only
            // test. The pager is full-bleed (ContentView's `ignoresSafeArea`),
            // so without this the look-at lands on the window's center, above
            // the visible center by half the top/bottom inset difference.
            .offset(x: 0, y: 0)
        }
        .overlay(alignment: .topLeading) {
            RoomObjectsMenu(stage: stage)
                .padding(.top, 50)
                .padding(.leading, UIConstants.General.safeSpace)
        }
        .onAppear { stage.setActive(isLive) }
        .onChange(of: isLive) { _, live in stage.setActive(live) }
        .accessibilityLabel("Room")
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    RoomView()
}
