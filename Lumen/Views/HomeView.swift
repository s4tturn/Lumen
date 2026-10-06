import SwiftUI

struct HomeView: View {

    var isLive: Bool = true

    var body: some View {
        DotMatrixView(isLive: isLive)
            .background { Color.black.ignoresSafeArea() }
            .overlay { DotMatrixVignette().ignoresSafeArea() }
            .accessibilityLabel("Dot matrix")
    }
}

#Preview {
    HomeView()
}
