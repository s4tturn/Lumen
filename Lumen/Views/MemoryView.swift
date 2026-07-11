import SwiftUI

struct MemoryView: View {
    var body: some View {
        ZStack {
            Color.green
            Text("Memory")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

#Preview {
    MemoryView()
}
