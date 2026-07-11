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
            FocusContainer(state: navigationState) {
                CoreNavigation()
            }
            .ignoresSafeArea()

            FocusContainer(state: greetingState) {
                GreetingView()
            }

            FocusContainer(state: ambientState, alignment: .bottom) {
                AmbientPlayer(engine: engine)
            }
            .padding(.bottom, 35)
        }
        .onAppear {
            startSequence()
        }
    }

    private func startSequence() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.5)) {
                greetingState = .visible
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            withAnimation(.easeInOut(duration: 0.5)) {
                greetingState = .hidden
                navigationState = .visible
                ambientState = .visible
            }
        }
    }
}
