import SwiftUI

struct AmbientPlayer: View {
    var engine: AmbientEngine

    @State private var mode: PlayerMode = .mini
    @State private var volume: Float = 0.5
    @State private var selectedSourceID: AmbientSource.ID?
    @State private var hoveredSourceID: AmbientSource.ID?

    /// Fluid morph spring — unhurried and seamless, blends smoothly through
    /// rapid mode changes.
    private let spring = Animation.spring(duration: 0.35, bounce: 0.04, blendDuration: 0.2)

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            playerContent
            Spacer().frame(height: mode == .expanded ? 10 : 35)
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .animation(spring, value: mode)
        .animation(spring, value: engine.isPlaying)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.9), trigger: mode)
        .onAppear {
            selectedSourceID = AmbientSource.all[0].id
        }
        .onChange(of: volume) { _, newVolume in
            engine.volume = newVolume
        }
        .onChange(of: selectedSourceID) { _, id in
            guard let source = AmbientSource.all.first(where: { $0.id == id }) else { return }
            let wasPlaying = engine.isPlaying
            engine.load(source)
            if wasPlaying { engine.play() }
        }
        .onChange(of: engine.isPlaying) { _, playing in
            withAnimation(spring) { mode = playing ? .compact : .mini }
        }
    }

    private var playerContent: some View {
        ZStack {
            switch mode {
            case .mini:
                Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            case .compact:
                compactContent
            case .volume:
                volumeContent
            case .expanded:
                expandedContent
            }
        }
        .frame(width: playerWidth, height: playerHeight)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onTapGesture { engine.togglePlayPause() }
        .gesture(dragGesture, including: mode == .mini ? .none : .all)
    }

    private var cornerRadius: CGFloat {
        mode == .expanded ? UIConstants.General.screenCornerRadius - 10 : 22.5
    }

    private var playerHeight: CGFloat {
        guard mode == .expanded else { return 45 }
        let count = CGFloat(AmbientSource.all.count)
        return 66 + count * 60 + (count - 1) * 6 + 10
    }

    private var playerWidth: CGFloat? {
        switch mode {
        case .mini: 45
        case .compact: nil
        case .volume: UIConstants.General.screenWidth * 0.7
        case .expanded: UIConstants.General.screenWidth - 30
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged(handleDrag)
            .onEnded(handleDragEnd)
    }

    private func handleDrag(_ value: DragGesture.Value) {
        let t = value.translation
        switch mode {
        case .compact:
            if t.height < -30, abs(t.height) > abs(t.width) * 1.5 {
                withAnimation(spring) { mode = .expanded }
            } else if abs(t.width) > 15, abs(t.width) > abs(t.height) * 1.5 {
                withAnimation(spring) { mode = .volume }
            }
        case .expanded:
            let row = Int((value.location.y - 66) / 66)
            let clamped = min(AmbientSource.all.count - 1, max(0, row))
            hoveredSourceID = row > 0 ? AmbientSource.all[clamped].id : nil
        case .volume:
            let sliderWidth = UIConstants.General.screenWidth * 0.7 - 30
            volume = max(0, min(1, Float((value.location.x - 15) / sliderWidth)))
        case .mini: break
        }
    }

    private func handleDragEnd(_: DragGesture.Value) {
        if mode == .expanded {
            if let hovered = hoveredSourceID { selectedSourceID = hovered }
            hoveredSourceID = nil
        }
        if mode == .expanded || mode == .volume {
            withAnimation(spring) { mode = engine.isPlaying ? .compact : .mini }
        }
    }
}

// MARK: - Content views

private extension AmbientPlayer {
    var compactContent: some View {
        HStack(spacing: 5) {
            Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
            Text("Ambient")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 15)
    }

    var volumeContent: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.25))
                Capsule().fill(.white).frame(width: geo.size.width * CGFloat(volume))
            }
        }
        .padding(15)
    }

    var expandedContent: some View {
        VStack(spacing: 0) {
            Text("Ambient Sources")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.top, 24)
                .padding(.bottom, 20)
            VStack(spacing: 6) {
                ForEach(AmbientSource.all) { sourceRow($0) }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    func sourceRow(_ source: AmbientSource) -> some View {
        let selected = source.id == selectedSourceID
        let hovered = source.id == hoveredSourceID
        let opacity = (selected ? 0.07 : 0) + (hovered ? 0.15 : 0)

        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(source.color.opacity(0.85))
                    .frame(width: 40, height: 40)
                Image(systemName: source.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(source.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(opacity))
        }
        .animation(.snappy, value: selected)
        .animation(.snappy, value: hovered)
        .sensoryFeedback(.selection, trigger: selected) { _, newValue in newValue }
    }
}

// MARK: - Supporting types

private extension AmbientPlayer {
    enum PlayerMode: Equatable {
        case mini, compact, volume, expanded
    }
}
