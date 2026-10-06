import SwiftUI

struct RoomView: View {

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

                RoomRealityStage(stage: stage, scene: stage.shown)

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

        .onChange(of: isLive, initial: true) { _, live in stage.setActive(live) }

        .earnRewards(stage: stage)

        .task(id: isLive) {
            guard isLive else { return }
            await stage.prefetchOthers()
        }

        .sensoryFeedback(.selection, trigger: stage.settleTick)

        .sensoryFeedback(.impact(flexibility: .soft), trigger: stage.pinchTick)
        .sensoryFeedback(.selection, trigger: stage.pinchArriveTick)
        .accessibilityLabel("Room")
        .accessibilityAddTraits(.isHeader)
    }

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
