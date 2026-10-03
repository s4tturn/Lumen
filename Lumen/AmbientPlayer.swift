import SwiftUI

private let ambientPillShape = RoundedRectangle(cornerRadius: 24, style: .continuous)

struct AmbientPlayer: View {
    @State private var engine = AmbientEngine()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// What the open collection is showing, and what is already finished. The
    /// only two facts the complete control needs, and both are derived: this view
    /// keeps no record of "am I completed" of its own to fall out of step.
    @Environment(CollectionFocus.self) private var focus
    @Environment(CollectionCompletionStore.self) private var completions
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
    /// The screen's own corner radius, read here — and only here — because this
    /// is the outermost point in the tree still resolving against the screen
    /// container. Inside the band the container is `bandShape`, so a radius read
    /// below that line would come back band-relative.
    @State private var screenCornerRadius: CGFloat = 0
    @State private var hapticTrigger = 0

    private enum Metrics {
        static let lockThreshold: CGFloat = 8
        static let tapMaxMovement: CGFloat = 12
        // Outer inset of the expanded band: how far the band itself sits from the
        // screen's edge. Single value so the band's width, its bottom inset and
        // the gesture area's reach can never drift apart.
        static let expandedOuterPadding: CGFloat = 5
        // Single inner inset for the expanded band: horizontal and bottom
        // read from the same value so they can never drift apart.
        static let expandedInnerPadding: CGFloat = 5
        static let completeWidth: CGFloat = 128
        static let completedWidth: CGFloat = 136
        static let trashDiameter: CGFloat = 48
        static let pillHeight: CGFloat = 48
        static let volumeHeight: CGFloat = 44
        /// The floor under each row's concentric radius: the screen's own radius
        /// less exactly the distance a row sits from the screen's edge — the
        /// band's outer inset, then the band's inner padding. A row at the
        /// screen's corner would resolve that radius on its own; this is the same
        /// number, handed to rows further in so the curvature never drops away.
        ///
        /// Clamped at zero because the screen radius is zero until SwiftUI
        /// resolves it, and a negative minimum is not a corner style.
        static func rowCornerRadius(screenRadius: CGFloat) -> CGFloat {
            max(0, screenRadius - expandedOuterPadding - expandedInnerPadding)
        }
        static let pillShape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        /// The band's own radius, and the floor under it: the screen's radius
        /// less the band's outer inset — the distance between the band's corner
        /// and the screen's. Concentric resolution would arrive at this number
        /// on its own; stating it means the band still curves at corners the
        /// screen's curve never reaches, and means the glass, the hit area and
        /// the published container all read one value instead of three.
        ///
        /// Clamped at zero for the same reason as the row floor below.
        static func bandCornerRadius(screenRadius: CGFloat) -> CGFloat {
            max(0, screenRadius - expandedOuterPadding)
        }
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
        state == .expanded ? Metrics.expandedOuterPadding : 32
    }
    /// The transport is off for exactly as long as a collection is open: the
    /// focus is non-`nil` for the card's whole lifetime, so one signal covers
    /// both "a card is up" and "there is a task to complete".
    private var gesturesEnabled: Bool { focus.task == nil }

    /// The open collection's task, resolved from the catalog.
    ///
    /// `nil` when nothing is open *and* if a focus ever named a task this build
    /// no longer has — in which case the transport comes back rather than
    /// offering to complete something with no content to complete.
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
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }
        .onGeometryChange(for: CGFloat.self) { $0.screenCornerRadius } action: { screenCornerRadius = $0 }
        .sensoryFeedback(.selection, trigger: hapticTrigger)
    }

    /// Which control belongs at the bottom, decided entirely by what the
    /// collection is showing: a card up swaps the transport for Complete, and a
    /// task that is already finished swaps Complete for the way back out of it.
    ///
    /// Completion is not a state machine here. The finished answer comes from the
    /// store and the visible answer from the pager, so undoing restores Complete
    /// on the same frame and it stays there until the card closes.
    @ViewBuilder
    private var content: some View {
        if let task = visibleTask {
            if completions.isCompleted(task.id) {
                undoControl(for: task)
            } else {
                completeControl(for: task)
            }
        } else {
            switch state {
            case .expanded: expandedBand
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
            .padding(.bottom, 32)
    }

    private func completeControl(for task: CollectionTask) -> some View {
        Button {
            // The store answers on this frame and the keychain write follows it,
            // so the morph is the tap's own feedback rather than a wait on
            // `securityd`.
            withAnimation(motion(UIConstants.Animation.smoothSpring)) { completions.complete(task.id) }
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
        // Which task, announced: the button acts on one specific task, and the
        // card holding it is not where VoiceOver’s focus is.
        .accessibilityValue(Text(task.title))
        .accessibilityAddTraits(.isButton)
        .glassEffect(.clear.interactive(), in: Metrics.pillShape)
        .glassEffectID("complete", in: morphNamespace)
        .glassEffectTransition(morphTransition)
        .padding(.bottom, 32)
    }

    private func undoControl(for task: CollectionTask) -> some View {
        HStack(spacing: 32) {
            Button {
                withAnimation(motion(UIConstants.Animation.snappySpring)) { completions.undo(task.id) }
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
            .accessibilityValue(Text(task.title))
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
                .accessibilityValue(Text(task.title))
                .glassEffect(.clear.interactive(), in: Metrics.pillShape)
                .glassEffectID("completed", in: morphNamespace)
        }
        .padding(.bottom, 32)
    }

    private var expandedBand: some View {
        let bandCornerRadius = Metrics.bandCornerRadius(screenRadius: screenCornerRadius)
        return VStack(alignment: .center, spacing: 0) {
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
                        isPlaying: engine.currentSource?.id == source.id,
                        isHovered: highlightedSourceID == source.id,
                        cornerRadius: Metrics.rowCornerRadius(screenRadius: screenCornerRadius)
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
            width: measuredWidth - 2 * Metrics.expandedOuterPadding,
            alignment: .top
        )
        // The band publishes its own glass geometry as the rows' container.
        // Same radius as the glass below, so rows share the glass's center and
        // nest by inset: the band's radius less the 5pt inner padding at its
        // corners, and no more than that further in.
        //
        // The container is the one surface that could not be a
        // `ConcentricRectangle` even if we wanted it: `containerShape` takes a
        // `RoundedRectangularShape`, which `ConcentricRectangle` does not
        // conform to (Shape only). It carries the same radius as a fixed rounded
        // rectangle, so the three surfaces agree on one number and only the
        // glass additionally pins per-corner variation out — see below.
        .containerShape(RoundedRectangle(cornerRadius: bandCornerRadius, style: .continuous))
        .contentShape(ConcentricRectangle(corners: .concentric(minimum: .fixed(bandCornerRadius))))
        // The glass itself takes a FIXED rounded rectangle, not a concentric one,
        // even though it shares the concentric radius above. Apple's Liquid Glass
        // examples only ever place fixed shapes in `glassEffect(in:)`: a
        // container-relative shape there does not resolve on the interactive
        // layer, and the material falls back to capsule-like geometry — a second,
        // hyper-rounded pill reads inside the band. `.interactive()` is what
        // surfaces it. The radius is still the concentric one, so the band's
        // curve is unchanged; only the spelling differs, and the container and
        // hit area above keep the concentric form because neither renders glass.
        .glassEffect(
            .clear.interactive(),
            in: RoundedRectangle(cornerRadius: bandCornerRadius, style: .continuous)
        )
        .glassEffectID("expanded", in: morphNamespace)
        .glassEffectTransition(morphTransition)
        .padding(.bottom, Metrics.expandedOuterPadding)
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
    let isPlaying: Bool
    let isHovered: Bool
    /// Floor under this row's concentric radius, derived once by the band from
    /// the screen's radius and both of the band's insets.
    let cornerRadius: CGFloat

    /// Row body. `ConcentricRectangle` against the band's published container,
    /// floored at `cornerRadius`: rows near the band's corners resolve the
    /// container's own radius less the inset, and rows further in — where that
    /// reaches zero — keep the screen's curve instead of squaring off.
    private var cardShape: ConcentricRectangle {
        ConcentricRectangle(corners: .concentric(minimum: .fixed(cornerRadius)))
    }
    /// State layers (playing tint, hover lift, hover ring). Same container,
    /// same frame and same floor as the body, so a state layer can never render
    /// less round than the surface it sits on and detach from its corners.
    private var highlightShape: ConcentricRectangle {
        ConcentricRectangle(
            corners: .concentric(minimum: .fixed(cornerRadius)),
            isUniform: false
        )
    }
    /// Icon tile, concentric in spelling. Fixed radius ignores the container,
    /// so this renders exactly the historical 5pt tile — now in the same
    /// shape family as every other layer in the card.
    private static let iconShape = ConcentricRectangle(
        corners: .fixed(5),
        isUniform: true
    )

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
            // Base + highlight A (playing: source-color tint) + highlight B
            // (hovered: white lift) as additive layers — a playing source
            // under the finger shows A + B combined.
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
    }
}
