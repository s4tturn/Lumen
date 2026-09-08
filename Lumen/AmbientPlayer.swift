import SwiftUI

private let ambientPillShape = RoundedRectangle(cornerRadius: 24, style: .continuous)

struct AmbientPlayer: View {
    @Binding private var collectionsExpanded: Bool
    @State private var engine = AmbientEngine()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var morphNamespace

    private enum Mode { case compact, expanded, volume, complete, completed }
    private enum DragAxis { case horizontal, vertical, ignored }

    @State private var state: Mode = .compact
    @State private var dragAxis: DragAxis?
    @State private var dragStart = CGSize.zero
    @State private var startVolume: Float = 0
    @State private var highlightedSourceID: AmbientSource.ID?
    @State private var cardFrames: [AmbientSource.ID: CGRect] = [:]
    @State private var containerWidth: CGFloat = 0
    @State private var hapticTrigger = 0

    private enum Metrics {
        static let lockThreshold: CGFloat = 8
        static let tapMaxMovement: CGFloat = 12
        // Single inner inset for the expanded band: horizontal and bottom
        // read from the same value so they can never drift apart.
        static let expandedInnerPadding: CGFloat = 12
        static let completeWidth: CGFloat = 128
        static let completedWidth: CGFloat = 136
        static let trashDiameter: CGFloat = 48
        static let pillHeight: CGFloat = 48
        static let volumeHeight: CGFloat = 44
        static let cardCornerRadius: CGFloat = UIConstants.General.screenCornerRadius - 24
        static let pillShape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        static let bandShape = RoundedRectangle(
            cornerRadius: UIConstants.General.screenCornerRadius - 8, style: .continuous
        )
    }

    init(collectionsExpanded: Binding<Bool> = .constant(false)) {
        _collectionsExpanded = collectionsExpanded
    }

    private func motion(_ base: Animation) -> Animation {
        UIConstants.Animation.motionGate(base, reduceMotion: reduceMotion)
    }

    private var contentTransition: AnyTransition {
        reduceMotion ? .opacity : .modifier(
            active: ContentBlur(radius: UIConstants.Animation.contentTransition.blur, opacity: UIConstants.Animation.contentTransition.opacity, scale: UIConstants.Animation.contentTransition.scale),
            identity: ContentBlur(radius: 0, opacity: 1, scale: 1)
        )
    }

    private var morphTransition: GlassEffectTransition {
        reduceMotion ? .materialize : .matchedGeometry
    }

    private var measuredWidth: CGFloat { max(containerWidth, 1) }
    private var compactWidth: CGFloat { engine.isPlaying ? measuredWidth * 0.5 : 50 }
    private var volumeWidth: CGFloat { measuredWidth * 0.7 }
    private var bottomPadding: CGFloat {
        state == .expanded ? UIConstants.General.safeSpace : 32
    }
    private var gesturesEnabled: Bool {
        !collectionsExpanded && state != .complete && state != .completed
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            GlassEffectContainer(spacing: 24) {
                ZStack {
                    switch state {
                    case .expanded: expandedBand
                    case .volume: volumePill
                    case .complete: completePill
                    case .completed: completedControls
                    case .compact: compactPill
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

            Rectangle()
                .fill(.clear)
                .frame(width: compactWidth, height: Metrics.pillHeight)
                .contentShape(Rectangle())
                .accessibilityHidden(true)
                .allowsHitTesting(gesturesEnabled)
                .gesture(
                    DragGesture(
                        minimumDistance: Metrics.lockThreshold,
                        coordinateSpace: .named("AmbientPlayer")
                    )
                    .onChanged(updateDrag)
                    .onEnded(endDrag)
                )
                .onTapGesture { toggle() }
                .disabled(!gesturesEnabled)
                .padding(.bottom, bottomPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .coordinateSpace(name: "AmbientPlayer")
        .onPreferenceChange(SourceCardFrameKey.self) { cardFrames = $0 }
        .onChange(of: collectionsExpanded) { _, expanded in
            withAnimation(motion(UIConstants.Animation.smoothSpring)) {
                state = expanded ? .complete : .compact
            }
        }
        .task(id: state == .completed) {
            guard state == .completed else { return }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(motion(UIConstants.Animation.snappySpring)) { state = .complete }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }
        .sensoryFeedback(.selection, trigger: hapticTrigger)
    }

    private var compactPill: some View {
        CompactPill(
            engine: engine,
            width: compactWidth,
            transition: contentTransition,
            namespace: morphNamespace,
            morph: morphTransition,
            onToggle: toggle
        )
    }

    private var volumePill: some View {
        VolumePill(engine: engine, width: volumeWidth, transition: contentTransition)
            .glassEffectID("volume", in: morphNamespace)
            .glassEffectTransition(morphTransition)
            .padding(.bottom, 32)
    }

    private var completePill: some View {
        Button {
            withAnimation(motion(UIConstants.Animation.smoothSpring)) { state = .completed }
            hapticTrigger += 1
        } label: {
            Text("Complete")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: Metrics.completeWidth, height: Metrics.pillHeight)
                .transition(contentTransition)
        }
        .buttonStyle(.plain)
        .contentShape(Metrics.pillShape)
        .accessibilityLabel("Complete")
        .accessibilityAddTraits(.isButton)
        .glassEffect(.clear.interactive(), in: Metrics.pillShape)
        .glassEffectID("complete", in: morphNamespace)
        .glassEffectTransition(morphTransition)
        .padding(.bottom, 32)
    }

    private var completedControls: some View {
        HStack(spacing: 32) {
            Button {
                withAnimation(motion(UIConstants.Animation.snappySpring)) { state = .complete }
                hapticTrigger += 1
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(width: Metrics.trashDiameter, height: Metrics.trashDiameter)
                    .transition(contentTransition)
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .accessibilityLabel("Undo completion")
            .accessibilityAddTraits(.isButton)
            .glassEffect(.clear.tint(.red).interactive(), in: Circle())
            .glassEffectID("completionTrash", in: morphNamespace)
            .glassEffectTransition(morphTransition)

            Text("Completed")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: Metrics.completedWidth, height: Metrics.pillHeight)
                .transition(contentTransition)
                .contentShape(Metrics.pillShape)
                .accessibilityLabel("Completed")
                .glassEffect(.clear.interactive(), in: Metrics.pillShape)
                .glassEffectID("completed", in: morphNamespace)
                .glassEffectTransition(morphTransition)
        }
        .padding(.bottom, 32)
    }

    private var expandedBand: some View {
        VStack(alignment: .center, spacing: 0) {
            Text("Ambient Sources")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.top, 20)
                .padding(.bottom, 16)
                .transition(contentTransition)

            VStack(spacing: 8) {
                ForEach(AmbientSource.all) { source in
                    SourceCard(
                        source: source,
                        cornerRadius: Metrics.cardCornerRadius,
                        isPlaying: engine.currentSource?.id == source.id,
                        isHovered: highlightedSourceID == source.id
                    )
                    .background {
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: SourceCardFrameKey.self,
                                value: [source.id: geo.frame(in: .named("AmbientPlayer"))]
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, Metrics.expandedInnerPadding)
            .padding(.bottom, Metrics.expandedInnerPadding)
            .transition(contentTransition)
        }
        // No fixed height: the band hugs its content (title + cards + the
        // identical inner padding on all sides) instead of compressing it
        // into a rigid frame and eating the bottom inset.
        .frame(
            width: measuredWidth - 2 * UIConstants.General.safeSpace,
            alignment: .top
        )
        .contentShape(Metrics.bandShape)
        .glassEffect(.clear.interactive(), in: Metrics.bandShape)
        .glassEffectID("expanded", in: morphNamespace)
        .glassEffectTransition(morphTransition)
        .padding(.bottom, UIConstants.General.safeSpace)
    }

    private func toggle() {
        withAnimation(motion(UIConstants.Animation.smoothSpring)) { engine.togglePlayPause() }
    }

    private func updateDrag(_ value: DragGesture.Value) {
        guard dragAxis != .ignored else { return }
        let dx = abs(value.translation.width)
        let dy = abs(value.translation.height)

        if dragAxis == nil, max(dx, dy) > Metrics.lockThreshold {
            if dx > dy {
                dragAxis = .horizontal
                dragStart = value.translation
                startVolume = engine.volume
                withAnimation(motion(UIConstants.Animation.snappySpring)) { state = .volume }
                hapticTrigger += 1
            } else if dy > dx {
                if value.translation.height < 0 {
                    dragAxis = .vertical
                    dragStart = value.translation
                    withAnimation(motion(UIConstants.Animation.snappySpring)) { state = .expanded }
                    hapticTrigger += 1
                } else {
                    dragAxis = .ignored
                }
            }
        }

        switch dragAxis {
        case .horizontal:
            let track = volumeWidth - 16
            guard track > 0 else { return }
            let delta = Float(value.translation.width - dragStart.width) / Float(track)
            engine.volume = min(max(startVolume + delta, 0), 1)
        case .vertical:
            let next = AmbientSource.all.first {
                cardFrames[$0.id]?.contains(value.location) == true
            }?.id
            guard next != highlightedSourceID else { return }
            withAnimation(motion(UIConstants.Animation.snappySpring)) { highlightedSourceID = next }
        default:
            break
        }
    }

    private func endDrag(_ value: DragGesture.Value) {
        if dragAxis == .vertical,
           let id = highlightedSourceID,
           let source = AmbientSource.all.first(where: { $0.id == id })
        {
            engine.select(source)
        }

        let engaged = dragAxis == .horizontal || dragAxis == .vertical
        if !engaged,
           max(abs(value.translation.width), abs(value.translation.height)) < Metrics.tapMaxMovement
        {
            toggle()
        }

        dragAxis = nil
        highlightedSourceID = nil
        withAnimation(motion(UIConstants.Animation.snappySpring)) { state = .compact }
    }

    private struct ContentBlur: ViewModifier {
        let radius: CGFloat
        let opacity: Double
        let scale: CGFloat

        func body(content: Content) -> some View {
            content.blur(radius: radius).opacity(opacity).scaleEffect(scale)
        }
    }

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

private struct CompactPill: View {
    let engine: AmbientEngine
    let width: CGFloat
    let transition: AnyTransition
    let namespace: Namespace.ID
    let morph: GlassEffectTransition
    let onToggle: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill((engine.currentSource?.color ?? .white).opacity(0.85))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: engine.currentSource?.icon ?? "music.note")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                Text(engine.currentSource?.name ?? "Source")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.leading, 8)

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
            .blur(radius: engine.isPlaying || reduceMotion ? 0 : UIConstants.Animation.contentTransition.blur)
            .scaleEffect(engine.isPlaying || reduceMotion ? 1 : UIConstants.Animation.contentTransition.scale)

            Image(systemName: "play.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: width, height: 48)
                .opacity(engine.isPlaying ? 0 : 1)
                .blur(radius: !engine.isPlaying || reduceMotion ? 0 : 12)
                .scaleEffect(!engine.isPlaying || reduceMotion ? 1 : UIConstants.Animation.contentTransition.scale)
        }
        .transition(transition)
        .frame(width: width, height: 48)
        .glassEffect(.clear.interactive(), in: ambientPillShape)
        .contentShape(ambientPillShape)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(engine.isPlaying ? "Pause ambient sound" : "Play ambient sound")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: engine.isPlaying ? "Pause" : "Play", onToggle)
        .glassEffectID("compact", in: namespace)
        .glassEffectTransition(morph)
        .padding(.bottom, 32)
    }
}

private struct VolumePill: View {
    let engine: AmbientEngine
    let width: CGFloat
    let transition: AnyTransition

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.3))
                Capsule()
                    .fill(Color.white)
                    .frame(width: geo.size.width * CGFloat(engine.volume))
            }
            .clipShape(Capsule())
            .transition(transition)
        }
        .padding(8)
        .frame(width: width, height: 44)
        .contentShape(Capsule())
        .glassEffect(.clear.interactive(), in: Capsule())
    }
}

private struct SourceCard: View {
    let source: AmbientSource
    let cornerRadius: CGFloat
    let isPlaying: Bool
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 12) {
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

            if isPlaying {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 20, height: 20)
                    .padding(.trailing, 8)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 72)
        .background {
            // Base + highlight A (playing: source-color tint) + highlight B
            // (hovered: white lift) as additive layers — a playing source
            // under the finger shows A + B combined.
            RoundedRectangle(cornerRadius: cornerRadius + 4, style: .continuous)
                .fill(.white.opacity(0.15))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius + 4, style: .continuous)
                        .fill(source.color.opacity(isPlaying ? 0.3 : 0))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius + 4, style: .continuous)
                        .fill(.white.opacity(isHovered ? 0.15 : 0))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius + 4, style: .continuous)
                .stroke(.white.opacity(isHovered ? 0.5 : 0), lineWidth: 1.5)
        }
        .scaleEffect(isHovered ? 1.02 : 1)
    }
}
