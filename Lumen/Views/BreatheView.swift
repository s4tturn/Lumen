import SwiftUI

struct BreatheView: View {
    var body: some View {
        ZStack {
            Color.orange
            Text("Breathe")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.white)
        }
        .accessibilityLabel("Breathe")
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    BreatheView()
}
