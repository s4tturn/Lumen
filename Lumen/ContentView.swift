import SwiftUI

@main struct LumenApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var isPlaying = false

    var body: some View {
        ZStack {
            CoreNavigation()
                .ignoresSafeArea()

            AmbientPlayer(isPlaying: $isPlaying)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 35)

            Image(systemName: "playpause.fill")
                .font(.system(size: 72, weight: .bold))
                .foregroundStyle(isPlaying ? .red : .white)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isPlaying)
        }
    }
}
