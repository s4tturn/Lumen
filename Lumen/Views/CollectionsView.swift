import SwiftUI

struct CollectionsView: View {
    var body: some View {
        ZStack {
            Color.purple
            Text("Collections")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

#Preview {
    CollectionsView()
}
