import SwiftUI

// MARK: - Collections View

struct CollectionsView: View {

    @Binding private var collectionsExpanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expandedIndex: Int?
    // Top card = last tapped card. Only taps write it; rotation/focus never
    // does. It persists after dismiss so rapid expand/dismiss/expand can't
    // desync layering via animation-completion clearing — latest tap wins.
    @State private var topCardIndex: Int?
    // Nearest straight-angle landing for the expanding card (a multiple of
    // 360 look-identical to 0). Pre-set at tap time so the expand morph
    // always rotates ≤180° via the shortest path, however many turns the
    // disk has accumulated.
    @State private var expandLanding: Double = 0
    // Guards snap-completion rotation normalization against overlapping snaps.
    @State private var snapEpoch = 0

    private let pageSize: CGSize

    init(
        collectionsExpanded: Binding<Bool> = .constant(false),
        pageSize: CGSize = CGSize(width: 390, height: 844)
    ) {
        self._collectionsExpanded = collectionsExpanded
        self.pageSize = pageSize
    }

    @State private var rotation: Double = 0
    @State private var isDraggingDisk = false
    @State private var lastFingerAngle: Double = 0
    @State private var lastFingerTime = Date.distantPast
    // Smoothed finger angular velocity (deg/sec) for release handoff.
    @State private var diskVelocity: Double = 0
    @State private var lastHapticRidge = 0
    @State private var dismissDrag: CGFloat = 0
    @State private var dismissAxisLocked = false

    /// Shared haptic generator — created once per view instance (Apple HIG).
    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    private var expandAnimation: Animation {
        UIConstants.Animation.motionGate(UIConstants.Animation.smoothSpring, reduceMotion: reduceMotion)
    }

    private var dismissAnimation: Animation {
        UIConstants.Animation.motionGate(UIConstants.Animation.snappySpring, reduceMotion: reduceMotion)
    }

    var body: some View {
        let geometry = CollectionsGeometry(size: pageSize)
        let anyExpanded = expandedIndex != nil

        ZStack {
            Color.black
                .ignoresSafeArea()

            diskView(geometry: geometry)
                .zIndex(2)
                .allowsHitTesting(!anyExpanded)

            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                let isExpanded = expandedIndex == index

                ghostCardView(
                    card: card,
                    index: index,
                    geometry: geometry,
                    isExpanded: isExpanded,
                    anyExpanded: anyExpanded
                )

                cardView(
                    card: card,
                    index: index,
                    geometry: geometry,
                    isExpanded: isExpanded,
                    anyExpanded: anyExpanded
                )
            }
        }
        .frame(width: pageSize.width, height: pageSize.height)
        .coordinateSpace(.named(CoordinateSpaces.collections))
        // No trailing ignoresSafeArea: pageSize is already fullscreen, and per
        // Apple ("If your view has a fixed size, the alignment of the view may
        // not be what you expect") a fixed frame + expansion resolves alignment
        // from the ignored edges — ambiguity around every .position child.
        // The base Color's own ignoresSafeArea still lets it bleed if needed.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Collections")
        .accessibilityHint("Rotate the disk to browse collections, tap a card to open it")
    }

    // MARK: - Disk

    @ViewBuilder
    private func diskView(geometry: CollectionsGeometry) -> some View {
        // One shared GlassEffectContainer so the disk's glass samples a single
        // region. The disk is the collection page's only glass surface; it is
        // kept separate from AmbientPlayer's container because they are
        // independent controls (they do not morph into each other), but the
        // container still guarantees a consistent sampling region for the
        // disk's own material. The frame/position/gesture live on the inner
        // content, never the container (container sizing fights the sampling
        // region it establishes).
        GlassEffectContainer {
            ZStack {
                Circle()
                    .fill(.black.opacity(0.6))

                TickMarksView(
                    rotation: rotation,
                    radius: geometry.diskRadius,
                    tickWidth: geometry.tickWidth,
                    tickHeight: geometry.tickHeight
                )
            }
            .frame(width: geometry.diskDiameter, height: geometry.diskDiameter)
            .glassEffect(.regular, in: Circle())
            .contentShape(Circle())
            .position(geometry.diskCenter)
            // No geometryGroup: the barrier re-times static positions against
            // the in-flight pager spring (see PageView), diverging the disk
            // from its frame mid-settle. Positions are static values — pass
            // through.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Collections disk")
            .accessibilityValue(cards[focusedCardIndex].name)
            .accessibilityHint("Swipe up or down to browse collections")
            .accessibilityAdjustableAction { direction in
                adjustDisk(direction == .increment ? 1 : -1)
            }
            .gesture(diskDragGesture(center: geometry.diskCenter, geometry: geometry))
        }
    }

    // MARK: - Card Layout

    private func cardLayout(
        index: Int,
        isExpanded: Bool,
        geometry: CollectionsGeometry
    ) -> CardLayout {
        let angle = radians(
            fromDegrees: rotation + Double(index) * Layout.cardSpacing
        )

        let position = CGPoint(
            x: isExpanded
                ? geometry.size.width / 2
                : geometry.diskCenter.x + geometry.orbitRadius * sin(angle),
            y: isExpanded
                ? geometry.size.height / 2
                : geometry.diskCenter.y - geometry.orbitRadius * cos(angle)
        )

        let size = CGSize(
            width: isExpanded ? geometry.size.width : geometry.cardSize,
            height: isExpanded ? geometry.size.height : geometry.cardSize
        )

        let progress = isExpanded
            ? min(max(-dismissDrag / geometry.dismissThreshold, 0), 1)
            : 0

        let cornerRadius = isExpanded
            ? geometry.screenCornerRadius
                + (geometry.collapsedCornerRadius - geometry.screenCornerRadius) * progress
            : geometry.collapsedCornerRadius

        // Orientation is continuous (unbounded) so disk spins never hit a
        // ±180° wrap seam mid-gesture — every frame interpolates from its
        // predecessor along the shortest path. The expanded target is the
        // nearest straight angle (multiple of 360, visually 0), so the morph
        // also takes the shortest path: e.g. resting at 270° eases +90° home
        // through 360°, resting at 90° eases -90° back. Driver rotation is
        // folded back into (-180, 180°] after each snap (see
        // normalizeRotation), so values never compound across turns.
        let orbitAngle = rotation + Double(index) * Layout.cardSpacing

        return CardLayout(
            position: position,
            size: size,
            offsetY: dismissDrag,
            cornerRadius: cornerRadius,
            rotation: isExpanded ? expandLanding : orbitAngle
        )
    }

    @ViewBuilder
    private func ghostCardView(
        card: Card,
        index: Int,
        geometry: CollectionsGeometry,
        isExpanded: Bool,
        anyExpanded: Bool
    ) -> some View {
        let layout = cardLayout(
            index: index,
            isExpanded: isExpanded,
            geometry: geometry
        )
        let dimmed = anyExpanded && !isExpanded

        // Ghost holds the fullscreen slot during the expand morph: same asset,
        // blurred under ultraThinMaterial, no second decode, no UIKit.
        Image(card.imageName)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: layout.size.width, height: layout.size.height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .fill(.ultraThinMaterial)
                    .opacity(isExpanded ? 1 : 0)
            }
            .rotationEffect(.degrees(layout.rotation))
            .offset(y: layout.offsetY)
            .position(layout.position)
            .blur(radius: dimmed ? 10 : 0)
            .opacity(dimmed ? 0 : 1)
            // Below the disk: normal ghosts 0, top ghost 1, disk 2,
            // normal cards 3, top card 4.
            .zIndex(topCardIndex == index ? 1 : 0)
    }

    @ViewBuilder
    private func cardView(
        card: Card,
        index: Int,
        geometry: CollectionsGeometry,
        isExpanded: Bool,
        anyExpanded: Bool
    ) -> some View {
        let layout = cardLayout(
            index: index,
            isExpanded: isExpanded,
            geometry: geometry
        )

        let expandedContentOpacity = isExpanded ? 1 - min(max(-dismissDrag / geometry.dismissThreshold, 0), 1) : 0

        ZStack {
            Image(card.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: layout.size.width, height: layout.size.height)
                .clipped()

            ZStack(alignment: isExpanded ? .top : .bottom) {
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .fill(.ultraThinMaterial)
                    .mask(gradientMask(isExpanded: isExpanded, width: layout.size.width))

                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .fill(Color(red: 0.05, green: 0.07, blue: 0.12)
                        .opacity(isExpanded ? 0 : 0.22))
                    .mask(gradientMask(isExpanded: isExpanded, width: layout.size.width))

                // Carousels exist only when expanded: six always-laid-out
                // GeometryReaders (even at opacity 0) re-resolve on every
                // parent invalidation. Insertion animates via the expand
                // transaction at the tap site; removal via dismiss.
                if isExpanded {
                    InfiniteEmojiCarousel(items: card.items)
                        .id(card.id)
                        .padding(.top, max(48, layout.size.height * 0.12))
                        .padding(.bottom, max(72, layout.size.height * 0.12))
                        .opacity(expandedContentOpacity)
                        .transition(.opacity)
                        .allowsHitTesting(isExpanded)
                }

                Text(card.name)
                    .font(.system(size: isExpanded ? 50 : 25, design: .serif))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .padding(.bottom, isExpanded ? 0 : max(12, layout.size.height * 0.06))
                    .padding(.top, isExpanded ? max(20, layout.size.height * 0.08) : 0)
            }
        }
        .frame(width: layout.size.width, height: layout.size.height)
        .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius))
        // Constrain tap + dismiss hit-testing to the visible card geometry so
        // touches in the gaps (card↔disk, card↔top edge) fall through to the
        // CoreNavigation paging gesture behind.
        .contentShape(RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous))
            .overlay {
            RoundedRectangle(cornerRadius: layout.cornerRadius)
                .stroke(.white.opacity(isExpanded ? 0 : 0.2), lineWidth: 1)
        }
            .rotationEffect(.degrees(layout.rotation))
            .offset(y: layout.offsetY)
            .position(layout.position)
            .blur(radius: anyExpanded && !isExpanded ? 10 : 0)
            .opacity(isExpanded ? 1 : (anyExpanded ? 0 : 1))
            // Above the disk: normal ghosts 0, top ghost 1, disk 2,
            // normal cards 3, top card 4.
            .zIndex(topCardIndex == index ? 4 : 3)
        .allowsHitTesting(!anyExpanded || isExpanded)
        .onTapGesture {
            guard expandedIndex == nil else { return }

            // Landing is invisible until the flip below (layout only reads it
            // when expanded), so pre-setting it outside the transaction can't
            // glitch — the expand then interpolates orbitAngle → landing.
            let start = rotation + Double(index) * Layout.cardSpacing
            expandLanding = 360 * round(start / 360)
            withAnimation(expandAnimation) {
                expandedIndex = index
                topCardIndex = index
                collectionsExpanded = true
            }
        }
        .simultaneousGesture(
            expandDismissGesture(geometry: geometry, isExpanded: isExpanded)
        )
        .accessibilityLabel(card.imageName.replacingOccurrences(of: "Background", with: ""))
        .accessibilityHint(isExpanded ? "Swipe up to dismiss" : "Double tap to open")
        .accessibilityAddTraits(isExpanded ? [] : .isButton)
    }

    private func gradientMask(isExpanded: Bool, width: CGFloat) -> some View {
        RadialGradient(
            stops: [
                .init(color: isExpanded ? .black : .clear, location: 0.0),
                .init(color: .black, location: 1.0)
            ],
            center: UnitPoint(x: 0.5, y: 0.0),
            startRadius: 0,
            endRadius: width * 0.9
        )
    }

    // MARK: - Expand / Dismiss

    private func expandDismissGesture(
        geometry: CollectionsGeometry,
        isExpanded: Bool
    ) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                guard isExpanded else { return }

                // Recomputed per event, never latched across cancellations: a
                // cancelled gesture delivers no onEnded, so a latched flag
                // would stick. Vertical takes the dismiss, horizontal yields
                // to the carousel.
                if abs(value.translation.height) > abs(value.translation.width) {
                    dismissAxisLocked = true
                    dismissDrag = min(0, value.translation.height)
                } else {
                    dismissAxisLocked = false
                    dismissDrag = 0
                }
            }
            .onEnded { value in
                guard isExpanded, dismissAxisLocked else {
                    dismissAxisLocked = false
                    dismissDrag = 0
                    return
                }

                defer { dismissAxisLocked = false }

                let shouldDismiss =
                    value.translation.height < -geometry.dismissThreshold
                    || value.velocity.height < -Layout.dismissVelocity

                // No completion handler by design: topCardIndex persists so the
                // collapsing card stays frontmost through the shrink, and a
                // re-tap mid-dismiss simply overwrites it — latest tap wins.
                withAnimation(shouldDismiss ? dismissAnimation : UIConstants.Animation.motionGate(UIConstants.Animation.smoothSpring, reduceMotion: reduceMotion)) {
                    if shouldDismiss {
                        expandedIndex = nil
                        collectionsExpanded = false
                    }
                    dismissDrag = 0
                }
            }
    }

    // MARK: - Disk Gesture

    private func diskDragGesture(
        center: CGPoint,
        geometry: CollectionsGeometry
    ) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(CoordinateSpaces.collections))
            .onChanged { value in
                guard expandedIndex == nil else { return }

                let dx = value.location.x - center.x
                let dy = value.location.y - center.y
                guard hypot(dx, dy) >= geometry.diskDeadZone else { return }

                let currentAngle = angle(of: value.location, around: center)

                guard isDraggingDisk else {
                    isDraggingDisk = true
                    lastFingerAngle = currentAngle
                    lastFingerTime = value.time
                    diskVelocity = 0
                    lastHapticRidge = Int(floor(-rotation / Layout.cardSpacing))
                    return
                }

                // Rotation tracks the finger 1:1 — no animation context while
                // down. Velocity is low-passed for the release handoff; raw
                // touch samples jitter too much to hand over directly.
                let delta = normalizedAngleDelta(from: lastFingerAngle, to: currentAngle)
                let dt = max(value.time.timeIntervalSince(lastFingerTime), 1e-3)
                diskVelocity += 0.35 * ((delta / dt) - diskVelocity)
                rotation += delta
                lastFingerAngle = currentAngle
                lastFingerTime = value.time

                let ridge = Int(floor(-rotation / Layout.cardSpacing))
                let ridgeDelta = ridge - lastHapticRidge
                if ridgeDelta != 0 {
                    haptic.prepare()
                    for _ in 0..<abs(ridgeDelta) { haptic.impactOccurred(intensity: 1) }
                    lastHapticRidge = ridge
                }
            }
            .onEnded { value in
                defer {
                    isDraggingDisk = false
                    diskVelocity = 0
                }

                guard expandedIndex == nil else { return }

                guard isDraggingDisk else {
                    snapToNearest()
                    return
                }

                let current = value.location
                let predicted = value.predictedEndLocation

                guard hypot(current.x - center.x, current.y - center.y) >= geometry.diskDeadZone,
                      hypot(predicted.x - center.x, predicted.y - center.y) >= geometry.diskDeadZone
                else {
                    snapToNearest()
                    return
                }

                let predictedRotation = rotation + normalizedAngleDelta(
                    from: angle(of: current, around: center),
                    to: angle(of: predicted, around: center)
                )

                animateToCard(nearestCardIndex(to: predictedRotation), releaseVelocity: diskVelocity)
            }
    }

    // MARK: - Rotation / Snapping

    private func nearestCardIndex(to rotation: Double) -> Int {
        Int(round(-rotation / Layout.cardSpacing))
    }

    /// Index into `cards` for the card nearest the top, wrapped.
    private var focusedCardIndex: Int {
        let raw = nearestCardIndex(to: rotation)
        return ((raw % cards.count) + cards.count) % cards.count
    }

    /// VoiceOver-friendly stepping; reuses the calm programmatic snap.
    private func adjustDisk(_ direction: Int) {
        settleToCard(nearestCardIndex(to: rotation) + direction)
    }

    private func snapToNearest() {
        settleToCard(nearestCardIndex(to: rotation))
    }

    /// Programmatic settle (disk tap, VoiceOver stepping): critically damped,
    /// no velocity, no overshoot.
    private func settleToCard(_ target: Int) {
        snapEpoch += 1
        let epoch = snapEpoch
        withAnimation(UIConstants.Animation.motionGate(UIConstants.Animation.snappySpring, reduceMotion: reduceMotion)) {
            rotation = Double(-target) * Layout.cardSpacing
        } completion: {
            normalizeRotation(epoch: epoch)
        }
        fireHaptics(to: target)
    }

    /// Flick release: target is velocity-projected (multi-card throws land
    /// multiple cards away), and the release velocity is handed to the spring
    /// normalized by remaining travel — Apple's initialVelocity semantics
    /// (fraction of the animated magnitude per second), clamped so tiny
    /// remainders can't explode. Bounce stays in the brisk band; overlapping
    /// snaps from consecutive flicks blend via interpolatingSpring instead of
    /// restarting from a stale value.
    /// See https://sosumi.ai/documentation/swiftui/animation/interpolatingspring(duration:bounce:initialvelocity:)
    private func animateToCard(_ target: Int, releaseVelocity: Double = 0) {
        snapEpoch += 1
        let epoch = snapEpoch
        let destination = Double(-target) * Layout.cardSpacing
        let remaining = destination - rotation
        let normalized = remaining == 0 ? 0 : min(
            max(releaseVelocity / remaining, -Layout.maxReleaseVelocity),
            Layout.maxReleaseVelocity
        )

        withAnimation(
            UIConstants.Animation.motionGate(
                .interpolatingSpring(
                    duration: Layout.flickSnapDuration,
                    bounce: Layout.flickSnapBounce,
                    initialVelocity: normalized
                ),
                reduceMotion: reduceMotion
            )
        ) {
            rotation = destination
        } completion: {
            normalizeRotation(epoch: epoch)
        }
        fireHaptics(to: target)
    }

    /// Folds accumulated disk rotation back into (-180, 180°] once the snap
    /// lands. Positions/orientations are mod-360 invariant so this is
    /// invisible. Superseded completions (rapid re-flicks) and mid-expand
    /// states never normalize.
    private func normalizeRotation(epoch: Int) {
        guard epoch == snapEpoch, expandedIndex == nil, !isDraggingDisk else { return }
        let turns = -Int(round(rotation / 360))
        guard turns != 0 else { return }
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            rotation += 360 * Double(turns)
        }
    }

    // MARK: - Haptics

    private func fireHaptics(to target: Int) {
        guard target != lastHapticRidge else { return }
        let delta = abs(target - lastHapticRidge)
        haptic.prepare()
        for _ in 0..<delta { haptic.impactOccurred(intensity: 1) }
        lastHapticRidge = target
    }
}

// MARK: - Preview

#Preview {
    CollectionsView()
}
