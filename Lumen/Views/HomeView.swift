import SwiftUI

struct HomeView: View {
    var body: some View {
        ZStack {
            Color.blue
            Text("Home")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

#Preview {
    HomeView()
}
