import SwiftUI

struct AmbientPlayer: View {
    @State private var engine = AmbientEngine()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // #EXPANDEDVIEW
    // Original expanded glass band, kept as a reference while the compact
    // player is rebuilt:
    //
    // var body: some View {
    //     bandShape
    //         .contentShape(bandShape)
    //         .glassEffect(.regular.interactive(), in: bandShape)
    //         .padding(UIConstants.General.safeSpace)
    //         .ignoresSafeArea()
    //         .frame(height: 240.0)
    //         .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    // }
    //
    // private var bandShape: RoundedRectangle {
    //     RoundedRectangle(
    //         cornerRadius: UIConstants.General.screenCornerRadius - UIConstants.General.safeSpace,
    //         style: .continuous
    //     )
    // }
    
    // #PAUSEDVIEW
    // Compact single-source circle button:
    //
    // var body: some View {
    //     Button(action: {}) {
    //         Image(systemName: "play.fill")
    //             .font(.system(size: 22, weight: .medium))
    //             .foregroundStyle(.white)
    //         .frame(width: 50, height: 50)
    //             .contentShape(Circle())
    //             .glassEffect(.regular.interactive(), in: Circle())
    //     }
    //     .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    //     .padding(.bottom, 34)
    // }
    
    // #PLAYINGVIEW
    // Dynamic pill wrapping its content, kept as a reference:
    //
    // var body: some View {
    //     HStack(spacing: 0) {
    //         RoundedRectangle(cornerRadius: 5, style: .continuous)
    //             .fill(.white.opacity(0.25))
    //             .frame(width: 30, height: 30)
    //
    //         Text("SourceText")
    //             .font(.system(size: 15, weight: .semibold))
    //             .foregroundStyle(.white)
    //             .lineLimit(1)
    //             .padding(.leading, 10)
    //
    //         Spacer(minLength: 0)
    //
    //         Image(systemName: "pause.fill")
    //             .resizable()
    //             .aspectRatio(contentMode: .fit)
    //             .frame(maxWidth: 20, maxHeight: 20)
    //             .foregroundStyle(.white)
    //     }
    //     .padding(.leading, 20)
    //     .padding(.trailing, 20)
    //     .frame(width: UIConstants.General.screenWidth * 0.5, height: 50)
    //     .contentShape(Capsule())
    //     .glassEffect(.regular.interactive(), in: Capsule())
    //     .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    //     .padding(.bottom, 34)
    // }
    
    // #VOLUMEVIEW
    // Draggable volume slider, kept as a reference:
    //
    // var body: some View {
    //     ZStack {
    //         GeometryReader { geo in
    //             ZStack(alignment: .leading) {
    //                 Capsule()
    //                     .fill(Color.white.opacity(0.25))
    //                 Capsule()
    //                     .fill(Color.white)
    //                     .frame(width: geo.size.width * progress)
    //             }
    //             .clipShape(Capsule())
    //             .gesture(
    //                 DragGesture(minimumDistance: 0)
    //                     .onChanged { value in
    //                         let newProgress = value.location.x / geo.size.width
    //                         progress = min(max(newProgress, 0), 1)
    //                     }
    //             )
    //         }
    //         .padding(10)
    //     }
    //     .contentShape(Capsule())
    //     .glassEffect(.regular.interactive(), in: Capsule())
    //     .frame(width: UIConstants.General.screenWidth * 0.7, height: 44)
    //     .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    //     .padding(.bottom, 34)
    // }

    var body: some View {
        playerButton
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 34)
    }

    private var glassShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 25, style: .continuous)
    }

    private var playerButton: some View {
        ZStack {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill((engine.currentSource?.color ?? .white).opacity(0.85))
                    .frame(width: 30, height: 30)
                    .overlay {
                        Image(systemName: engine.currentSource?.icon ?? "music.note")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                Text(engine.currentSource?.name ?? "Source")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.leading, 10)

                Spacer(minLength: 0)

                Image(systemName: "pause.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 20, maxHeight: 20)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .opacity(engine.isPlaying ? 1 : 0)

            Image(systemName: "play.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white)
                .opacity(engine.isPlaying ? 0 : 1)
        }
        .frame(width: engine.isPlaying ? UIConstants.General.screenWidth * 0.5 : 50, height: 50)
        .clipShape(glassShape)
        .contentShape(glassShape)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(engine.isPlaying ? "Pause ambient sound" : "Play ambient sound")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: engine.isPlaying ? "Pause" : "Play") {
            withAnimation(reduceMotion ? nil : .default) {
                engine.togglePlayPause()
            }
        }
        .onTapGesture {
            withAnimation(reduceMotion ? nil : .default) {
                engine.togglePlayPause()
            }
        }
        .glassEffect(.clear.interactive(), in: glassShape)
    }
    
    // #EXPANDEDVIEW
    // Current expanded view with ambient sources list:
    //
    // var body: some View {
    //     VStack(alignment: .center, spacing: 0) {
    //         Text("Ambient Sources")
    //             .font(.system(size: 20, weight: .semibold))
    //             .foregroundStyle(.white)
    //             .padding(.top, 20)
    //             .padding(.bottom, 16)
    //         
    //         VStack(spacing: 6) {
    //             ForEach(AmbientSource.all) { source in
    //                 SourceCard(source: source, cornerRadius: sourceCardCornerRadius)
    //             }
    //         }
    //         .padding(.horizontal, 12)
    //         .padding(.bottom, 12)
    //     }
    //     .frame(maxWidth: .infinity, alignment: .top)
    //     .containerShape(bandShape)
    //     .contentShape(bandShape)
    //     .glassEffect(.regular.interactive(), in: bandShape)
    //     .padding(.horizontal, UIConstants.General.safeSpace)
    //     .padding(.bottom, 12)
    //     .ignoresSafeArea()
    //     .frame(
    //         maxWidth: .infinity,
    //         maxHeight: .infinity,
    //         alignment: .bottom
    //     )
    // }
    
    private struct SourceCard: View {
        let source: AmbientSource
        let cornerRadius: CGFloat
        
        var body: some View {
            HStack(spacing: 13) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(source.color.opacity(0.85))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: source.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                
                Text(source.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                
                Spacer(minLength: 8)
                
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 20, height: 20)
                    .padding(.trailing, 10)
            }
            .padding(.horizontal, 15)
            .frame(height: 70)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius + 4, style: .continuous)
                    .fill(.white.opacity(0.075))
            }
        }
    }
    
    private var bandShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: UIConstants.General.screenCornerRadius - 10,
            style: .continuous
        )
    }
    
    private var sourceCardCornerRadius: CGFloat {
        UIConstants.General.screenCornerRadius - 26
    }
}
