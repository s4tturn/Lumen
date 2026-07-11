import SwiftUI

struct AmbientPlayer: View {
    @Binding var isPlaying: Bool

    var body: some View {
        HStack(spacing: isPlaying ? 0 : 6) {
            Image(systemName: "play.fill")
                .font(.system(size: isPlaying ? 18 : 14, weight: .semibold))

            Text("Ambient")
                .font(.system(size: 14, weight: .semibold))
                .opacity(isPlaying ? 0 : 1)
                .scaleEffect(isPlaying ? 0.5 : 1, anchor: .leading)
                .frame(width: isPlaying ? 0 : nil, alignment: .leading)
                .clipped()
        }
        .foregroundStyle(.white)
        .frame(width: isPlaying ? 45 : nil, height: 45)
        .padding(.horizontal, isPlaying ? 0 : 20)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22.5))
        .contentShape(.capsule)
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isPlaying.toggle()
            }
        }
    }
}

#Preview {
    AmbientPlayer(isPlaying: .constant(false))
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 35)
        .background(.blue)
}
