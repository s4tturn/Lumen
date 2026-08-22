import SwiftUI

struct AmbientPlayer: View {
    @Binding private var collectionsExpanded: Bool
    @State private var engine = AmbientEngine()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    // MARK: - Reveal State

    private enum Reveal {
        case playing
        case paused
        case expanded
        case volume
        case complete
        case completed
    }

    private enum DragAxis {
        case horizontal
        case vertical
        case ignored
    }

    @State private var reveal: Reveal = .paused
    @State private var dragAxis: DragAxis?
    @State private var dragStart = CGSize.zero
    @State private var startVolume: Float = 0
    @State private var highlightedSourceID: AmbientSource.ID?
    @State private var cardFrames: [AmbientSource.ID: CGRect] = [:]
    @State private var containerWidth: CGFloat = 0
    @Namespace private var morphNamespace

    private let haptic = UIImpactFeedbackGenerator(style: .light)

    // MARK: - Constants

    private static let lockThreshold: CGFloat = 10
    private static let tapMaxMovement: CGFloat = 12
    private static let expandedHeight: CGFloat = 218
    private static let completeWidth: CGFloat = 126
    private static let completedWidth: CGFloat = 136
    private static let trashDiameter: CGFloat = 50

    // MARK: - Springs

    private let engageSpring = Animation.snappy(duration: 0.45, extraBounce: 0.12)
    private let collapseSpring = Animation.snappy(duration: 0.38, extraBounce: 0.06)

    // MARK: - Shapes (cached — avoids repeated allocation)

    private static let pillShape = RoundedRectangle(cornerRadius: 25, style: .continuous)
    private static let bandShape = RoundedRectangle(
        cornerRadius: UIConstants.General.screenCornerRadius - 10,
        style: .continuous
    )

    init(collectionsExpanded: Binding<Bool> = .constant(false)) {
        self._collectionsExpanded = collectionsExpanded
    }

    // MARK: - Geometry

    private var compactWidth: CGFloat {
        engine.isPlaying ? containerWidth * 0.5 : 50
    }

    private var volumeWidth: CGFloat {
        containerWidth * 0.7
    }

    private var currentSize: CGSize {
        switch reveal {
        case .playing, .paused:
            CGSize(width: compactWidth, height: 50)
        case .volume:
            CGSize(width: volumeWidth, height: 44)
        case .expanded:
            CGSize(
                width: containerWidth - 2 * UIConstants.General.safeSpace,
                height: Self.expandedHeight
            )
        case .complete:
            CGSize(width: Self.completeWidth, height: 50)
        case .completed:
            CGSize(width: Self.trashDiameter + 8 + Self.completedWidth, height: 50)
        }
    }

    private var currentBottomPadding: CGFloat {
        reveal == .expanded ? UIConstants.General.safeSpace : 34
    }

    private var playbackGesturesEnabled: Bool {
        !collectionsExpanded && reveal != .complete && reveal != .completed
    }

    private var playbackReveal: Reveal {
        engine.isPlaying ? .playing : .paused
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                playerMorph
                gestureSurface
            }
            .coordinateSpace(name: "AmbientPlayer")
            .onPreferenceChange(SourceCardFrameKey.self) { cardFrames = $0 }
            .onChange(of: collectionsExpanded) { _, isExpanded in
                withAnimation(reduceMotion ? nil : engageSpring) {
                    reveal = isExpanded ? .complete : playbackReveal
                }
            }
            .task(id: revealIsCompleted) {
                guard reveal == .completed else { return }

                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }

                withAnimation(reduceMotion ? nil : collapseSpring) {
                    reveal = .complete
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }
        }
    }

    private var revealIsCompleted: Bool {
        reveal == .completed
    }

    // MARK: - Player Morph

    private var playerMorph: some View {
        GlassEffectContainer(spacing: 12) {
            ZStack {
                if reveal == .expanded {
                    expandedBand
                } else if reveal == .volume {
                    volumePill
                } else if reveal == .complete {
                    completePill
                } else if reveal == .completed {
                    completedControls
                } else {
                    compactPill
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    // MARK: - Gesture Surface

    private var gestureSurface: some View {
        Rectangle()
            .fill(.clear)
            // Keep the recognizer's hit-test geometry stable while the visible
            // player morphs. A changing gesture view can be removed from under
            // the finger, preventing DragGesture.onEnded from being delivered.
            .frame(width: compactWidth, height: 50)
            .contentShape(Rectangle())
            .accessibilityHidden(true)
            .allowsHitTesting(playbackGesturesEnabled)
            .if(playbackGesturesEnabled) { view in
                view.gesture(dragGesture)
            }
            .padding(.bottom, currentBottomPadding)
    }

    // MARK: - Compact Player

    private var compactPill: some View {
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
                .frame(width: compactWidth, height: 50)
                .opacity(engine.isPlaying ? 0 : 1)
        }
        .frame(width: compactWidth, height: 50)
        .clipShape(Self.pillShape)
        .contentShape(Self.pillShape)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(engine.isPlaying ? "Pause ambient sound" : "Play ambient sound")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: engine.isPlaying ? "Pause" : "Play") {
            withAnimation(reduceMotion ? nil : .default) {
                engine.togglePlayPause()
            }
        }
        .accessibleGlass(.clear.interactive(), in: Self.pillShape, reduceTransparency: reduceTransparency)
        .glassEffectID(
            reveal == .playing ? "playing" : "paused",
            in: morphNamespace
        )
        .glassEffectTransition(.matchedGeometry)
        .padding(.bottom, 34)
    }

    // MARK: - Volume

    private var volumePill: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.25))
                Capsule()
                    .fill(Color.white)
                    .frame(width: geo.size.width * CGFloat(engine.volume))
            }
            .clipShape(Capsule())
        }
        .padding(10)
        .frame(width: volumeWidth, height: 44)
        .contentShape(Capsule())
        .accessibleGlass(.clear.interactive(), in: Capsule(), reduceTransparency: reduceTransparency)
        .glassEffectID("volume", in: morphNamespace)
        .glassEffectTransition(.matchedGeometry)
        .padding(.bottom, 34)
    }

    // MARK: - Completion

    private var completePill: some View {
        Button {
            withAnimation(reduceMotion ? nil : engageSpring) {
                reveal = .completed
            }
            haptic.impactOccurred(intensity: 0.7)
        } label: {
            Text("Complete")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: Self.completeWidth, height: 50)
        }
        .buttonStyle(.plain)
        .contentShape(Self.pillShape)
        .accessibilityLabel("Complete")
        .accessibilityAddTraits(.isButton)
        .accessibleGlass(.clear.interactive(), in: Self.pillShape, reduceTransparency: reduceTransparency)
        .glassEffectID("complete", in: morphNamespace)
        .glassEffectTransition(.matchedGeometry)
        .padding(.bottom, 34)
    }

    private var completedControls: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(reduceMotion ? nil : collapseSpring) {
                    reveal = .complete
                }
                haptic.impactOccurred(intensity: 0.7)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(width: Self.trashDiameter, height: Self.trashDiameter)
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .accessibilityLabel("Undo completion")
            .accessibilityAddTraits(.isButton)
            .accessibleGlass(
                .clear.tint(.red.opacity(0.35)).interactive(),
                in: Circle(),
                reduceTransparency: reduceTransparency
            )
            .glassEffectID("completionTrash", in: morphNamespace)
            .glassEffectTransition(.matchedGeometry)

            Text("Completed")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: Self.completedWidth, height: 50)
                .contentShape(Self.pillShape)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Completed")
                .accessibleGlass(.clear.interactive(), in: Self.pillShape, reduceTransparency: reduceTransparency)
                .glassEffectID("completed", in: morphNamespace)
                .glassEffectTransition(.matchedGeometry)
        }
        .frame(width: currentSize.width, height: 50)
        .padding(.bottom, 34)
    }

    // MARK: - Expanded

    private var expandedBand: some View {
        let cardCornerRadius = UIConstants.General.screenCornerRadius - 26

        return VStack(alignment: .center, spacing: 0) {
            Text("Ambient Sources")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.top, 20)
                .padding(.bottom, 16)

            VStack(spacing: 6) {
                ForEach(AmbientSource.all) { source in
                    SourceCard(
                        source: source,
                        cornerRadius: cardCornerRadius,
                        highlighted: highlightedSourceID == source.id
                    )
                    .background {
                        GeometryReader { geo in
                            Color.clear
                                .preference(
                                    key: SourceCardFrameKey.self,
                                    value: [source.id: geo.frame(in: .named("AmbientPlayer"))]
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(
            width: containerWidth - 2 * UIConstants.General.safeSpace,
            height: Self.expandedHeight,
            alignment: .top
        )
        .containerShape(Self.bandShape)
        .contentShape(Self.bandShape)
        .accessibleGlass(.clear.interactive(), in: Self.bandShape, reduceTransparency: reduceTransparency)
        .glassEffectID("expanded", in: morphNamespace)
        .glassEffectTransition(.matchedGeometry)
        .padding(.bottom, UIConstants.General.safeSpace)
    }

    // MARK: - Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("AmbientPlayer"))
            .onChanged { updateDrag($0) }
            .onEnded { endDrag($0) }
    }

    private func updateDrag(_ value: DragGesture.Value) {
        guard dragAxis != .ignored else { return }
        let dx = abs(value.translation.width)
        let dy = abs(value.translation.height)

        if dragAxis == nil, max(dx, dy) > Self.lockThreshold {
            if dx > dy {
                dragAxis = .horizontal
                dragStart = value.translation
                startVolume = engine.volume
                engage(.volume)
            } else if dy > dx {
                if value.translation.height < 0 {
                    dragAxis = .vertical
                    dragStart = value.translation
                    engage(.expanded)
                } else {
                    dragAxis = .ignored
                }
            }
        }

        switch dragAxis {
        case .horizontal:
            updateVolume(from: value.translation.width)
        case .vertical:
            highlightSource(at: value.location)
        default:
            break
        }
    }

    private func highlightSource(at point: CGPoint) {
        highlightedSourceID = AmbientSource.all.first {
            cardFrames[$0.id]?.contains(point) == true
        }?.id
    }

    private func engage(_ target: Reveal) {
        withAnimation(reduceMotion ? nil : engageSpring) { reveal = target }
        haptic.prepare()
        haptic.impactOccurred(intensity: 0.7)
    }

    private func updateVolume(from width: CGFloat) {
        let delta = width - dragStart.width
        let track = volumeWidth - 20
        let adjusted = Double(startVolume) + Double(delta) / Double(track)
        engine.volume = Float(min(max(adjusted, 0), 1))
    }

    private func endDrag(_ value: DragGesture.Value) {
        if dragAxis == .vertical,
           let id = highlightedSourceID,
           let source = AmbientSource.all.first(where: { $0.id == id }) {
            engine.select(source)
        }

        let engaged = dragAxis == .horizontal || dragAxis == .vertical

        if !engaged {
            let movement = max(abs(value.translation.width), abs(value.translation.height))
            if movement < Self.tapMaxMovement {
                withAnimation(reduceMotion ? nil : .default) {
                    engine.togglePlayPause()
                }
            }
        }

        dragAxis = nil
        highlightedSourceID = nil
        withAnimation(reduceMotion ? nil : collapseSpring) {
            reveal = playbackReveal
        }
    }

    // MARK: - Source Card

    private struct SourceCard: View {
        let source: AmbientSource
        let cornerRadius: CGFloat
        let highlighted: Bool

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
                    .fill(highlighted ? .white.opacity(0.16) : .white.opacity(0.075))
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius + 4, style: .continuous)
                    .stroke(.white.opacity(highlighted ? 0.5 : 0), lineWidth: 1.5)
            )
            .scaleEffect(highlighted ? 1.02 : 1)
            .animation(.snappy(duration: 0.22, extraBounce: 0.18), value: highlighted)
        }
    }

    // MARK: - Frame Tracking

    private struct SourceCardFrameKey: PreferenceKey {
        static var defaultValue: [AmbientSource.ID: CGRect] { [:] }
        static func reduce(
            value: inout [AmbientSource.ID: CGRect],
            nextValue: () -> [AmbientSource.ID: CGRect]
        ) {
            value.merge(nextValue(), uniquingKeysWith: { $1 })
        }
    }
}

private extension View {
    @ViewBuilder
    func `if`<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

private extension View {
    @ViewBuilder
    func accessibleGlass(
        _ glass: Glass,
        in shape: some Shape,
        reduceTransparency: Bool
    ) -> some View {
        if reduceTransparency {
            self.background(.ultraThinMaterial, in: shape)
        } else {
            self.glassEffect(glass, in: shape)
        }
    }
}
