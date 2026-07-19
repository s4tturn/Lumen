import SwiftUI

@main struct LumenApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var engine = AmbientEngine()
    @State private var greetingState: FocusedState = .hidden
    @State private var navigationState: FocusedState = .subduedAlt
    @State private var ambientState: FocusedState = .subdued
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            FocusContainer(state: navigationState) {
                CoreNavigation()
            }

            FocusContainer(state: greetingState) {
                GreetingView()
            }

            FocusContainer(state: ambientState, alignment: .bottom) {
                AmbientPlayer(engine: engine)
            }
            .padding(.bottom, 35)
        }
        .ignoresSafeArea()
        .environment(\.onDotMatrixPress) { pressing in
            withAnimation(.smooth(duration: 0.6)) {
                ambientState = pressing ? .subdued : .visible
            }
        }
        .onAppear {
            startSequence()
        }
    }

    private func startSequence() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.smooth(duration: 0.8)) {
                greetingState = .visible
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.1) {
            withAnimation(.smooth(duration: 0.8)) {
                greetingState = .hidden
                navigationState = .visible
                ambientState = .visible
            }
        }
    }
}
