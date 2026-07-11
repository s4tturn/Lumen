import SwiftUI

struct AmbientPlayer: View {
    @Binding var isPlaying: Bool

    var body: some View {
        Image(systemName: "cloud.sun.fill")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(isPlaying ? .orange : .white)
            .frame(height: 45)
            .padding(.horizontal, 20)
            .glassEffect(.regular.interactive(), in: .capsule)
            .contentShape(.capsule)
            .onTapGesture { isPlaying.toggle() }
    }
}

#Preview {
    AmbientPlayer(isPlaying: .constant(false))
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 35)
        .background(.blue)
}
