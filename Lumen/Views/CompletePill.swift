import SwiftUI

/// Liquid Glass completion pill. Idle: a single "Complete" capsule. Pending:
/// that anchor becomes a circle counter, plus a red undo progress bar that
/// drains over the 5s undo window. All state derives from `CompletionStore`,
/// so switching items morphs the pill to that item's state.
struct CompletePill: View {
    @Environment(CompletionStore.self) private var store

    @State private var squish = false
    @Namespace private var glassMorph

    /// Undo bar base — darker red.
    private static let baseRed = Color(red: 0.32, green: 0.05, blue: 0.09)
    /// Undo bar fill for the remaining undo time — lighter red.
    private static let remainingRed = Color(red: 0.88, green: 0.24, blue: 0.32)

    /// Spring keeps the shape identity stable; `.default` would add extra
    /// scale/offset effects when only the anchor's content changes.
    private static let morph = Animation.spring(duration: 0.5, bounce: 0.1)
    /// Fast press-in phase — no bounce, just squash.
    private static let pressIn = Animation.spring(duration: 0.2, bounce: 0)
    /// Bouncy release back to rest — the click bounce.
    private static let pressOut = Animation.spring(duration: 0.55, bounce: 0.45)

    private var isPending: Bool { store.activeUndo != nil }

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                anchor
                if isPending { undoButton }
            }
        }
        .scaleEffect(squish ? 0.92 : 1)
        .animation(Self.morph, value: store.focused)
        .animation(Self.morph, value: store.activeUndo)
    }

    // MARK: - Elements

    private var anchor: some View {
        Text(isPending ? "\(store.count)" : "Complete")
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .frame(width: isPending ? 44 : nil, height: isPending ? 44 : nil)
            .padding(.horizontal, isPending ? 0 : 28)
            .padding(.vertical, isPending ? 0 : 14)
            .contentShape(Capsule())
            .glassEffect(.regular.interactive(), in: Capsule())
            .glassEffectID("center", in: glassMorph)
            .onTapGesture { complete() }
    }

    /// Horizontal undo progress bar: darker red base, lighter red for the
    /// remaining undo time, which drains toward zero over the 5s window.
    private var undoButton: some View {
        TimelineView(.animation) { context in
            let remaining = store.activeUndo?.expiresAt.timeIntervalSince(context.date) ?? 0
            let progress = max(0, min(1, remaining / CompletionStore.undoWindow))
            Button {
                undo()
            } label: {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Self.baseRed)
                    Capsule()
                        .fill(Self.remainingRed)
                        .frame(width: 110 * progress)
                    Text("Undo")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                }
                .frame(width: 110, height: 44)
            }
            .buttonStyle(.plain)
            .transition(.opacity)
        }
    }

    // MARK: - Actions

    private func complete() {
        guard !isPending else { return }
        bounce()
        withAnimation(Self.morph) {
            store.complete()
        }
    }

    private func undo() {
        bounce()
        withAnimation(Self.morph) {
            store.undo()
        }
    }

    /// Squash the whole container down, then spring it back for a click bounce.
    private func bounce() {
        withAnimation(Self.pressIn) {
            squish = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(Self.pressOut) {
                squish = false
            }
        }
    }
}

#Preview {
    CompletePill()
        .environment(CompletionStore())
        .background(.black)
}
