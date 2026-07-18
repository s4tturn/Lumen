import SwiftUI

struct ExpandedCollectionView: View, Equatable {
    let collection: Collection
    let onDismiss: () -> Void

    @State private var cardCenter: CGPoint = .zero
    @State private var cardSize: CGSize = .zero
    @State private var cardCornerRadius: CGFloat = 28
    @State private var contentBlend: CGFloat = 1.0

    private let maxDismissDistance: CGFloat = 160

    private var cs: CGFloat { UIConstants.General.screenWidth * 0.7 }
    private var cx: CGFloat { UIConstants.General.screenWidth / 2 }
    private var cy: CGFloat { UIConstants.General.screenHeight / 2 - UIConstants.General.screenHeight * 0.03 }

    static func == (lhs: ExpandedCollectionView, rhs: ExpandedCollectionView) -> Bool {
        lhs.collection.id == rhs.collection.id
    }

    var body: some View {
        let w = UIConstants.General.screenWidth
        let h = UIConstants.General.screenHeight
        let cardColor = collection.color

        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture { dismissCard() }

            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [cardColor.opacity(0.18), cardColor.opacity(0.04)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [cardColor.opacity(0.4), cardColor.opacity(0.1)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .overlay(cardContent(cardColor: cardColor))
                .frame(width: cardSize.width, height: cardSize.height)
                .position(cardCenter)
                .gesture(
                    DragGesture(minimumDistance: 10, coordinateSpace: .local)
                        .onChanged { value in handleDragChanged(value, w: w, h: h) }
                        .onEnded { value in handleDragEnded(value, w: w, h: h) }
                )
        }
        .onAppear { triggerExpansion(w: w, h: h) }
    }

    @State private var showCompletionUIForTask: [Int: Bool] = [:]
    @State private var taskCounters: [Int: Int] = [:]
    @State private var completionTask: Task<Void, Never>?
    @Namespace private var glassMorph

    @State private var counterBounce: CGFloat = 1.0
    @State private var trashWobble: Double = 0
    @State private var containerBounce: CGFloat = 0

    @State private var pageIndex: Int = 0
    @State private var pageDragOffset: CGFloat = 0

    private var currentTasks: [CollectionTask] {
        collection.tasks
    }

    private var currentTaskIndex: Int {
        abs(pageIndex) % currentTasks.count
    }

    private var currentItem: CollectionTask {
        currentTasks[currentTaskIndex]
    }

    // MARK: - Content

    @ViewBuilder
    private func cardContent(cardColor: Color) -> some View {
        ZStack {
            compactContent(cardColor: cardColor)
                .opacity(Double(contentBlend))
                .blur(radius: (1.0 - contentBlend) * 12.0)

            detailContent(cardColor: cardColor)
                .opacity(1.0 - Double(contentBlend))
                .blur(radius: contentBlend * 12.0)
        }
    }

    @ViewBuilder
    private func compactContent(cardColor: Color) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Text(collection.tasks.first?.emoji ?? "")
                .font(.system(size: 72))
            Text(collection.name)
                .font(.system(size: 28, weight: .medium, design: .serif))
                .foregroundColor(.white.opacity(0.85))
                .shadow(color: cardColor.opacity(0.3), radius: 10)
            Spacer()
        }
    }

    @ViewBuilder
    private func detailContent(cardColor: Color) -> some View {
        let bubblePad: CGFloat = 15

        ZStack(alignment: .bottom) {
            GeometryReader { geo in
                let pw = geo.size.width
                ZStack {
                    ForEach(Array(currentTasks.enumerated()), id: \.offset) { i, task in
                        let offset = CGFloat(i - currentTaskIndex) * pw + pageDragOffset
                        let dist = abs(offset) / pw
                        VStack(spacing: 0) {
                            Spacer()
                            Text(task.emoji)
                                .font(.system(size: 110))
                                .shadow(color: cardColor.opacity(0.5), radius: 25, x: 0, y: 8)
                            Spacer().frame(height: 30)
                            Text(task.name)
                                .font(.system(size: 28, weight: .medium, design: .serif))
                                .foregroundColor(.white.opacity(0.9))
                            Spacer()
                        }
                        .frame(width: pw)
                        .offset(x: offset)
                        .blur(radius: dist < 1.5 ? min(10, dist * 10) : 0)
                        .opacity(dist < 1.5 ? 1 : 0)
                    }
                }
                .clipped()
            }

            GlassEffectContainer(spacing: 10) {
                if showCompletionUIForTask[currentTaskIndex, default: false] {
                    HStack(spacing: 10) {
                        trashButton
                        completedPill
                        countPill
                    }
                } else {
                    idleCompletePill
                }
            }
            .animation(.bouncy(duration: 0.5), value: showCompletionUIForTask)
            .padding(.horizontal, bubblePad)
            .padding(.bottom, bubblePad)
            .offset(y: containerBounce - 50)
        }
        .overlay(alignment: .top) {
            Text(collection.name)
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundColor(.white.opacity(0.6))
                .padding(.top, 90)
        }
    }

    // MARK: - Completion UI

    private var idleCompletePill: some View {
        HStack(spacing: 6) {
            Text(currentItem.emoji)
                .font(.system(size: 18))
            Text("Complete")
                .font(.system(size: 16, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 28)
        .frame(height: 48)
        .glassEffect(.regular.interactive(), in: Capsule())
        .glassEffectID("complete", in: glassMorph)
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            triggerContainerBounce()
            let idx = currentTaskIndex
            withAnimation(.bouncy(duration: 0.5)) {
                showCompletionUIForTask[idx] = true
            }
            startCompletionTimer()
        }
    }

    private var trashButton: some View {
        Image(systemName: "trash.fill")
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 48, height: 48)
            .glassEffect(.regular.tint(.red).interactive(), in: Capsule())
            .glassEffectID("trash", in: glassMorph)
            .rotationEffect(.degrees(trashWobble))
            .onTapGesture {
                cancelCompletionTimer()
                triggerContainerBounce()
                let idx = currentTaskIndex
                withAnimation(.bouncy(duration: 0.5)) {
                    showCompletionUIForTask[idx] = false
                }
                triggerTrashWobble()
            }
    }

    private var completedPill: some View {
        Text("Completed")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white.opacity(0.45))
            .padding(.horizontal, 24)
            .frame(height: 48)
            .glassEffect(.regular, in: Capsule())
            .glassEffectID("completed", in: glassMorph)
    }

    private var countPill: some View {
        Text("\(taskCounters[currentTaskIndex, default: 0] + 1)")
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 48, height: 48)
            .contentTransition(.numericText())
            .scaleEffect(counterBounce)
            .glassEffect(.regular.interactive(), in: Capsule())
            .glassEffectID("counter", in: glassMorph)
    }

    private func startCompletionTimer() {
        let taskIndex = currentTaskIndex
        completionTask?.cancel()
        completionTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard showCompletionUIForTask[taskIndex] == true else { return }
                completeAction(for: taskIndex)
            }
        }
    }

    private func completeAction(for taskIndex: Int) {
        taskCounters[taskIndex, default: 0] += 1
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        triggerContainerBounce()
        withAnimation(.bouncy(duration: 0.5)) {
            showCompletionUIForTask[taskIndex] = false
        }
        withAnimation(.interpolatingSpring(mass: 0.6, stiffness: 180, damping: 8)) {
            counterBounce = 1.35
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.interpolatingSpring(mass: 0.6, stiffness: 180, damping: 10)) {
                counterBounce = 1.0
            }
        }
    }

    private func cancelCompletionTimer() {
        completionTask?.cancel()
        completionTask = nil
    }

    private func triggerTrashWobble() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.interpolatingSpring(mass: 0.4, stiffness: 80, damping: 4)) {
            trashWobble = trashWobble == 0 ? 14 : 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.interpolatingSpring(mass: 0.4, stiffness: 80, damping: 6)) {
                trashWobble = 0
            }
        }
    }

    private func triggerContainerBounce() {
        withAnimation(.spring(response: 0.12, dampingFraction: 0.6)) {
            containerBounce = -22
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.35)) {
                containerBounce = 0
            }
        }
    }

    // MARK: - Expansion Sequence

    private func triggerExpansion(w: CGFloat, h: CGFloat) {
        cardCenter = CGPoint(x: cx, y: cy)
        cardSize = CGSize(width: cs, height: cs)
        cardCornerRadius = 28
        contentBlend = 1.0

        DispatchQueue.main.async {
            withAnimation(.interpolatingSpring(mass: 1.0, stiffness: 220, damping: 22)) {
                cardCenter = CGPoint(x: cx, y: h / 2)
                cardSize = CGSize(width: w, height: h)
                cardCornerRadius = UIConstants.General.screenCornerRadius
                contentBlend = 0.0
            }
        }
    }

    // MARK: - Interactive Dragging

    private func handleDragChanged(_ value: DragGesture.Value, w: CGFloat, h: CGFloat) {
        let translation = value.translation
        let isHorizontal = abs(translation.width) > abs(translation.height) * 1.5 && contentBlend == 0

        if isHorizontal {
            pageDragOffset = translation.width
        } else {
            let progress = min(1.0, abs(translation.height) / maxDismissDistance)

            cardSize = CGSize(
                width: lerp(w, cs, progress),
                height: lerp(h, cs, progress)
            )
            cardCornerRadius = lerp(UIConstants.General.screenCornerRadius, 28, progress)
            contentBlend = progress

            cardCenter = CGPoint(
                x: w / 2 + translation.width,
                y: h / 2 + translation.height
            )
        }
    }

    // MARK: - Physics-driven Release

    private func handleDragEnded(_ value: DragGesture.Value, w: CGFloat, h: CGFloat) {
        let translation = value.translation
        let velocity = value.velocity
        let isHorizontal = abs(translation.width) > abs(translation.height) * 1.5 && contentBlend == 0

        if isHorizontal {
            let threshold = w * 0.3
            let goingNext = translation.width < -threshold || velocity.width < -300
            let goingPrev = translation.width > threshold || velocity.width > 300

            if goingNext {
                withAnimation(.interpolatingSpring(mass: 0.8, stiffness: 260, damping: 24)) {
                    pageDragOffset = -w
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    pageIndex += 1
                    pageDragOffset = 0
                }
            } else if goingPrev {
                withAnimation(.interpolatingSpring(mass: 0.8, stiffness: 260, damping: 24)) {
                    pageDragOffset = w
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    pageIndex -= 1
                    pageDragOffset = 0
                }
            } else {
                withAnimation(.interpolatingSpring(mass: 0.8, stiffness: 260, damping: 24)) {
                    pageDragOffset = 0
                }
            }
            return
        }

        let sourceCenter = CGPoint(x: cx, y: cy)
        let progress = min(1.0, abs(translation.height) / maxDismissDistance)
        let shouldDismiss = progress >= 0.45 || abs(velocity.height) >= 500

        if shouldDismiss {
            let distanceY = sourceCenter.y - cardCenter.y
            let initialVelocityY = safeNormalizedVelocity(velocity: velocity.height, distance: distanceY)
            let distanceX = sourceCenter.x - cardCenter.x
            let initialVelocityX = safeNormalizedVelocity(velocity: velocity.width, distance: distanceX)
            let isHighVelocity = abs(velocity.height) > 300
            let posDamping: Double = isHighVelocity ? 22 : 34
            let sizeDamping: Double = isHighVelocity ? 24 : 34

            withAnimation(.interpolatingSpring(mass: 1.0, stiffness: 260, damping: posDamping, initialVelocity: initialVelocityY)) {
                cardCenter.y = sourceCenter.y
            }
            withAnimation(.interpolatingSpring(mass: 1.0, stiffness: 260, damping: posDamping, initialVelocity: initialVelocityX)) {
                cardCenter.x = sourceCenter.x
            }
            withAnimation(.interpolatingSpring(mass: 1.0, stiffness: 260, damping: sizeDamping)) {
                cardSize = CGSize(width: cs, height: cs)
                cardCornerRadius = 28
                contentBlend = 1.0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                onDismiss()
            }
        } else {
            let distanceY = (h / 2) - cardCenter.y
            let initialVelocityY = safeNormalizedVelocity(velocity: velocity.height, distance: distanceY)
            let distanceX = (w / 2) - cardCenter.x
            let initialVelocityX = safeNormalizedVelocity(velocity: velocity.width, distance: distanceX)
            let isHighVelocity = abs(velocity.height) > 250 || abs(velocity.width) > 250
            let posDamping: Double = isHighVelocity ? 22 : 32
            let sizeDamping: Double = isHighVelocity ? 22 : 32

            withAnimation(.interpolatingSpring(mass: 1.0, stiffness: 220, damping: posDamping, initialVelocity: initialVelocityY)) {
                cardCenter.y = h / 2
            }
            withAnimation(.interpolatingSpring(mass: 1.0, stiffness: 220, damping: posDamping, initialVelocity: initialVelocityX)) {
                cardCenter.x = w / 2
            }
            withAnimation(.interpolatingSpring(mass: 1.0, stiffness: 220, damping: sizeDamping)) {
                cardSize = CGSize(width: w, height: h)
                cardCornerRadius = UIConstants.General.screenCornerRadius
                contentBlend = 0.0
            }
        }
    }

    private func dismissCard() {
        let sourceCenter = CGPoint(x: cx, y: cy)

        withAnimation(.interpolatingSpring(mass: 1.0, stiffness: 240, damping: 33)) {
            cardCenter = sourceCenter
            cardSize = CGSize(width: cs, height: cs)
            cardCornerRadius = 28
            contentBlend = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            onDismiss()
        }
    }

    // MARK: - Physics Helpers

    private func safeNormalizedVelocity(velocity: CGFloat, distance: CGFloat) -> Double {
        guard abs(distance) > 10 else { return 0 }
        let v = Double(velocity / distance)
        return max(-32.0, min(32.0, v))
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }
}
