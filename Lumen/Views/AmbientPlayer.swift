import SwiftUI

enum Metrics {

    static let expandedOuterPadding: CGFloat = 5

    static let expandedInnerPadding: CGFloat = 10

    static let completeWidth: CGFloat = 128
    static let completedWidth: CGFloat = 136
    static let trashDiameter: CGFloat = 48
    static let pillHeight: CGFloat = 48

    static let volumeHeight: CGFloat = 44
    static let volumeInset: CGFloat = 8

    static let restingBottomPadding: CGFloat = 32

    static let pillShape = RoundedRectangle(cornerRadius: 24, style: .continuous)

    static func rowCornerRadius(screenRadius: CGFloat) -> CGFloat {
        max(0, screenRadius - expandedOuterPadding - expandedInnerPadding)
    }

    static func bandCornerRadius(screenRadius: CGFloat) -> CGFloat {
        max(0, screenRadius - expandedOuterPadding)
    }

    static let iconShape = Circle()
}

private enum Drag {
    static let lockThreshold: CGFloat = 8
    static let tapMaxMovement: CGFloat = 12
}

struct AmbientPlayer: View {
    @State private var engine = AmbientEngine()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Environment(CollectionFocus.self) private var focus
    @Environment(CollectionStore.self) private var completions
    @Namespace private var morphNamespace

    private enum Mode { case compact, expanded, volume }
    private enum DragAxis { case horizontal, vertical, ignored }

    @State private var state: Mode = .compact
    @State private var dragAxis: DragAxis?
    @State private var dragStart = CGSize.zero
    @State private var startVolume: Float = 0
    @State private var highlightedSourceID: AmbientSource.ID?
    @State private var cardFrames: [AmbientSource.ID: CGRect] = [:]
    @State private var containerWidth: CGFloat = 0

    @State private var screenCornerRadius: CGFloat = 0
    @State private var hapticTrigger = 0

    private func motion(_ base: Animation) -> Animation {
        UIConstants.Animation.reduceMotionGate(base, reduceMotion: reduceMotion)
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
        state == .expanded ? Metrics.expandedOuterPadding : Metrics.restingBottomPadding
    }

    private var gesturesEnabled: Bool { focus.task == nil }

    private var visibleTask: CollectionTask? {
        focus.task.flatMap { CollectionCatalog.entry(for: $0)?.1 }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            GlassEffectContainer(spacing: 24) {
                ZStack {
                    content
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
                        minimumDistance: Drag.lockThreshold,
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
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }
        .onGeometryChange(for: CGFloat.self) { $0.screenCornerRadius } action: { screenCornerRadius = $0 }
        .sensoryFeedback(.selection, trigger: hapticTrigger)
    }

    @ViewBuilder
    private var content: some View {
        if let task = visibleTask {
            if completions.isCompleted(task.id) {
                UndoControl(
                    task: task,
                    hapticTrigger: $hapticTrigger,
                    transition: contentTransition,
                    morph: morphTransition,
                    namespace: morphNamespace
                )
            } else {
                CompleteControl(
                    task: task,
                    hapticTrigger: $hapticTrigger,
                    transition: contentTransition,
                    morph: morphTransition,
                    namespace: morphNamespace
                )
            }
        } else {
            switch state {
            case .expanded:
                ExpandedBand(
                    engine: engine,
                    screenRadius: screenCornerRadius,
                    width: measuredWidth,
                    highlightedID: highlightedSourceID,
                    transition: contentTransition,
                    morph: morphTransition,
                    namespace: morphNamespace
                )
            case .volume: volumePill
            case .compact: compactPill
            }
        }
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
            .padding(.bottom, Metrics.restingBottomPadding)
    }

    private func toggle() {
        withAnimation(motion(UIConstants.Animation.dwell)) { engine.togglePlayPause() }
    }

    private func updateDrag(_ value: DragGesture.Value) {
        guard dragAxis != .ignored else { return }
        let dx = abs(value.translation.width)
        let dy = abs(value.translation.height)

        if dragAxis == nil, max(dx, dy) > Drag.lockThreshold {
            if dx > dy {
                dragAxis = .horizontal
                dragStart = value.translation
                startVolume = engine.volume
                withAnimation(motion(UIConstants.Animation.commit)) { state = .volume }
                hapticTrigger += 1
            } else if dy > dx {
                if value.translation.height < 0 {
                    dragAxis = .vertical
                    dragStart = value.translation
                    withAnimation(motion(UIConstants.Animation.commit)) { state = .expanded }
                    hapticTrigger += 1
                } else {
                    dragAxis = .ignored
                }
            }
        }

        switch dragAxis {
        case .horizontal:

            let track = volumeWidth - 2 * Metrics.volumeInset
            guard track > 0 else { return }
            let delta = Float(value.translation.width - dragStart.width) / Float(track)
            engine.volume = min(max(startVolume + delta, 0), 1)
        case .vertical:
            let next = AmbientSource.all.first {
                cardFrames[$0.id]?.contains(value.location) == true
            }?.id
            guard next != highlightedSourceID else { return }
            withAnimation(motion(UIConstants.Animation.commit)) { highlightedSourceID = next }
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
           max(abs(value.translation.width), abs(value.translation.height)) < Drag.tapMaxMovement
        {
            toggle()
        }

        dragAxis = nil
        highlightedSourceID = nil
        withAnimation(motion(UIConstants.Animation.commit)) { state = .compact }
    }

    private struct ContentBlur: ViewModifier {
        let radius: CGFloat
        let opacity: Double
        let scale: CGFloat

        func body(content: Content) -> some View {
            content.blur(radius: radius).opacity(opacity).scaleEffect(scale)
        }
    }
}

struct SourceCardFrameKey: PreferenceKey {
    static var defaultValue: [AmbientSource.ID: CGRect] { [:] }
    static func reduce(
        value: inout [AmbientSource.ID: CGRect],
        nextValue: () -> [AmbientSource.ID: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct CompactPill: View {
    let engine: AmbientEngine
    let width: CGFloat
    let transition: AnyTransition
    let namespace: Namespace.ID
    let morph: GlassEffectTransition
    let onToggle: () -> Void

    var body: some View {
        ZStack {

            HStack(spacing: 0) {
                if engine.isPlaying {
                    Metrics.iconShape
                        .fill((engine.currentSource?.color ?? .white).opacity(0.85))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: engine.currentSource?.icon ?? "music.note")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .transition(transition)

                    Text(engine.currentSource?.name ?? "Source")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.leading, 8)
                        .transition(transition)

                    Spacer(minLength: 0)
                }

                Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
            }

            .padding(.horizontal, engine.isPlaying ? 20 : 0)
            .frame(maxWidth: .infinity)
        }
        .transition(transition)
        .frame(width: width, height: Metrics.pillHeight)
        .glassEffect(.clear.interactive(), in: Metrics.pillShape)
        .contentShape(Metrics.pillShape)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(engine.isPlaying ? "Pause ambient sound" : "Play ambient sound")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: engine.isPlaying ? "Pause" : "Play", onToggle)
        .glassEffectID("compact", in: namespace)
        .glassEffectTransition(morph)
        .padding(.bottom, Metrics.restingBottomPadding)
        .debugSurfaceBorder(Metrics.pillShape)
    }
}

struct VolumePill: View {
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
        .padding(Metrics.volumeInset)
        .frame(width: width, height: Metrics.volumeHeight)
        .contentShape(Capsule())
        .glassEffect(.clear.interactive(), in: Capsule())
        .debugSurfaceBorder(Capsule())
    }
}

struct ExpandedBand: View {
    let engine: AmbientEngine

    let screenRadius: CGFloat

    let width: CGFloat

    let highlightedID: AmbientSource.ID?
    let transition: AnyTransition
    let morph: GlassEffectTransition
    let namespace: Namespace.ID

    var body: some View {
        let bandCornerRadius = Metrics.bandCornerRadius(screenRadius: screenRadius)
        return VStack(alignment: .center, spacing: 0) {
            Text("Ambient Sources")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.top, 20)
                .padding(.bottom, 16)
                .transition(transition)

            VStack(spacing: 8) {
                ForEach(AmbientSource.all) { source in
                    SourceCard(
                        source: source,
                        isPlaying: engine.currentSource?.id == source.id,
                        isHovered: highlightedID == source.id,
                        cornerRadius: Metrics.rowCornerRadius(screenRadius: screenRadius)
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
            .transition(transition)
        }
        .frame(
            width: width - 2 * Metrics.expandedOuterPadding,
            alignment: .top
        )

        .containerShape(RoundedRectangle(cornerRadius: bandCornerRadius, style: .continuous))
        .contentShape(ConcentricRectangle(corners: .concentric(minimum: .fixed(bandCornerRadius))))

        .glassEffect(
            .clear.interactive(),
            in: RoundedRectangle(cornerRadius: bandCornerRadius, style: .continuous)
        )
        .glassEffectID("expanded", in: namespace)
        .glassEffectTransition(morph)
        .padding(.bottom, Metrics.expandedOuterPadding)
        .debugSurfaceBorder(RoundedRectangle(cornerRadius: bandCornerRadius, style: .continuous))
    }
}

struct SourceCard: View {
    let source: AmbientSource
    let isPlaying: Bool
    let isHovered: Bool

    let cornerRadius: CGFloat

    private var cardShape: ConcentricRectangle {
        ConcentricRectangle(corners: .concentric(minimum: .fixed(cornerRadius)))
    }

    private var highlightShape: ConcentricRectangle {
        ConcentricRectangle(
            corners: .concentric(minimum: .fixed(cornerRadius)),
            isUniform: false
        )
    }

    private static let iconShape = Metrics.iconShape

    var body: some View {
        HStack(spacing: 12) {
            Self.iconShape
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

            cardShape
                .fill(.white.opacity(0.15))
                .overlay {
                    highlightShape.fill(source.color.opacity(isPlaying ? 0.3 : 0))
                }
                .overlay {
                    highlightShape.fill(.white.opacity(isHovered ? 0.15 : 0))
                }
        }
        .overlay {
            highlightShape.stroke(.white.opacity(isHovered ? 0.5 : 0), lineWidth: 1.5)
        }
        .scaleEffect(isHovered ? 1.02 : 1)
        .debugSurfaceBorder(cardShape)
    }
}

struct CompleteControl: View {
    @Environment(CollectionStore.self) private var completions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let task: CollectionTask

    @Binding var hapticTrigger: Int
    let transition: AnyTransition
    let morph: GlassEffectTransition
    let namespace: Namespace.ID

    var body: some View {
        Button {
            withAnimation(UIConstants.Animation.reduceMotionGate(UIConstants.Animation.dwell, reduceMotion: reduceMotion)) { completions.complete(task.id) }
            hapticTrigger += 1
        } label: {
            Text("Complete")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: Metrics.completeWidth, height: Metrics.pillHeight)
                .transition(transition)
        }
        .buttonStyle(.plain)
        .contentShape(Metrics.pillShape)
        .accessibilityLabel("Complete")

        .accessibilityValue(Text(task.title))
        .accessibilityAddTraits(.isButton)
        .glassEffect(.clear.interactive(), in: Metrics.pillShape)
        .glassEffectID("completionPill", in: namespace)
        .glassEffectTransition(morph)
        .padding(.bottom, Metrics.restingBottomPadding)
        .debugSurfaceBorder(Metrics.pillShape)
    }
}

struct UndoControl: View {
    @Environment(CollectionStore.self) private var completions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let task: CollectionTask

    @Binding var hapticTrigger: Int
    let transition: AnyTransition
    let morph: GlassEffectTransition
    let namespace: Namespace.ID

    var body: some View {

        HStack(spacing: Metrics.restingBottomPadding) {
            Button {
                withAnimation(UIConstants.Animation.reduceMotionGate(UIConstants.Animation.commit, reduceMotion: reduceMotion)) { completions.undo(task.id) }
                hapticTrigger += 1
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(width: Metrics.trashDiameter, height: Metrics.trashDiameter)
                    .transition(transition)
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .accessibilityLabel("Undo completion")
            .accessibilityValue(Text(task.title))
            .accessibilityAddTraits(.isButton)
            .glassEffect(.clear.tint(.red).interactive(), in: Circle())
            .glassEffectID("completionTrash", in: namespace)
            .glassEffectTransition(morph)
            .debugSurfaceBorder(Circle())

            Text("Completed")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: Metrics.completedWidth, height: Metrics.pillHeight)
                .transition(transition)
                .contentShape(Metrics.pillShape)
                .accessibilityLabel("Completed")
                .accessibilityValue(Text(task.title))
                .glassEffect(.clear.interactive(), in: Metrics.pillShape)
                .glassEffectID("completionPill", in: namespace)
        }
        .padding(.bottom, Metrics.restingBottomPadding)
    }
}
