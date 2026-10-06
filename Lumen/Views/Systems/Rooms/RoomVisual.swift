import SwiftUI

// MARK: - Tab

/// The room switcher: one tab per room, in a row of glass above the room.
///
/// The tabs are hand-built rather than a `Picker` in a segmented style, because
/// a segmented control's segments divide the width between themselves, and three
/// equal slices of a phone's width are narrow enough that the only label that
/// fits in all of them is no label at all. These are laid out at the size their
/// contents need and centred, so each room can be named — and a symbol on its own
/// is not a control anybody can name.
///
/// The glass is one surface per tab inside one `GlassEffectContainer`, which is
/// what makes them agree with each other over the room behind them: separate
/// sampling regions would each refract a different piece of a scene that is
/// moving under them, and neighbouring glass that disagrees is the thing
/// containers exist to prevent. The container's `spacing` is zero on purpose, so
/// the tabs share a sampling region without ever fusing into one continuous
/// shape — the row reads as three buttons, not as one bar with three bulges.
///
/// Selection is carried twice over. The chosen tab's symbol is filled, and its
/// glass carries that room's own tint; every other tab keeps the outline symbol
/// and untinted glass. Both signals are kept because neither survives alone: a
/// filled symbol reads as "on" without colour, and a tint alone is a hue that a
/// person who cannot separate it from the room behind it has no way to act on.
///
/// The tint rides *inside* the tab's one glass surface, carried on the `Glass`
/// value handed to the button style, rather than on a second shape behind it.
/// Glass cannot sample glass, so a shape behind a glass button composites to mud
/// — and because it is the outer layer it covers the tint it was added to show,
/// which is what made this read as an untinted tab with a coloured fringe.
///
/// It is a pure projection of the stage. It holds no state, writes nothing of its
/// own, and the binding's setter is a request rather than an assignment: the stage
/// decides whether a tap is worth a switch. Adding a room is a case in
/// `RoomScene.all` and nothing here.
struct RoomTab: View {
    @Binding var selection: RoomScene
    /// Mirrors the credits sheet's presentation, so the credits button can look
    /// like the control that is up. Read rather than owned here because the sheet
    /// is presented by `RoomView`, which is also where the tap is handled.
    let isCreditsActive: Bool
    let onCreditsTapped: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: RoomTabMetrics.containerSpacing) {
            HStack(spacing: RoomTabMetrics.gap) {
                RoomCreditsButton(isActive: isCreditsActive, action: onCreditsTapped)

                ForEach(RoomScene.all) { scene in
                    RoomTabButton(scene: scene, isSelected: scene == selection) {
                        selection = scene
                    }
                }
            }
        }
    }
}

/// One room's tab: a symbol that fills when it is on, swapping
/// to its fill spelling layer by layer when the selection moves.
/// The tab is compressed to just the symbol for space efficiency.
private struct RoomTabButton: View {
    let scene: RoomScene
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            // A tap commits a selection, so it rides the commit
            // spring. That transaction is also what carries the
            // symbol's swap below: a content transition only
            // animates inside an animation context. The room's
            // own switch runs on the stage's task, outside this
            // transaction, so the spring never reaches it.
            withAnimation(UIConstants.Animation.commit) { action() }
        } label: {
            // The symbol swaps by NAME, not by variant, so the
            // swap is a content change — and the replace effect
            // then morphs the outline symbol's layers into the
            // fill symbol's, each layer separately, on every
            // switch. Selected draws the fill; unselected the
            // outline.
            Image(systemName: isSelected ? scene.filledSymbol : scene.symbol)
                .contentTransition(.symbolEffect(.replace.byLayer))
                // First appearance, like every symbol in Lumen:
                // each layer its own beat.
                .symbolEffect(.appear.byLayer, isActive: true)
                .font(.system(size: RoomTabMetrics.fontSize, weight: .medium))
                .foregroundStyle(.primary)
                .frame(minWidth: RoomTabMetrics.minimumHeight, minHeight: RoomTabMetrics.minimumHeight)
        }
        // One glass surface, and the tint is part of it. Handing the button style
        // a configured `Glass` value is what carries the colour in the material;
        // the unselected branch makes no `tint` call at all, so a tab that is not
        // showing is the same untinted glass as its neighbours. `.interactive()`
        // rides on both branches because that is where the press reaction lives
        // now that the button style is the only layer — Apple's own words for
        // `interactive()` are that it gives a custom surface "the same responsive
        // and fluid reactions that `glass` provides to standard buttons".
        .buttonStyle(.glass(isSelected ? .regular.tint(scene.tabTint).interactive() : .regular.interactive()))
        // The tab's own name, not the drawn one: "Living" on screen, "Living
        // Room" spoken, which is the whole of the reason the two strings exist.
        .accessibilityLabel(Text(scene.title))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .debugSurfaceBorder()
    }
}

// MARK: - Turn Handle

/// The circular drag target that turns the room.
///
/// Occupies a square `diameter` points across and is entirely transparent: it
/// exists to catch the drag, not to be seen. `RoomView` sizes it to the page's
/// width, which makes its hit area the circle the room is drawn in — so drags on
/// the room turn it, and anything outside it stays with the pager.
///
/// The gesture here is a courier and nothing more: every decision about what a
/// drag means — where it started, how far a point of travel is worth, how hard a
/// flick carries on release — belongs to `RoomStage`. That is what keeps a drag
/// from compounding across samples, and what lets a switch reset the room
/// without leaving this view holding a base angle the next drag would jump from.
///
/// It also carries a pinch-to-zoom on the same circle, which reports to the stage
/// in the same courier fashion and settles back to the preset when let go. See
/// `isPinching`.
struct RoomTurnHandle: View {
    /// VoiceOver's swipe-up/swipe-down step, in radians — about 15°, roughly a
    /// sixteenth of a turn per swipe.
    private static let accessibilityStep: Float = .pi / 12

    let diameter: CGFloat
    let stage: RoomStage

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Whether this drag has already claimed its base angle from the stage. The
    /// gesture reports every sample of a drag together, so the first one has to
    /// tell itself apart to open the turn.
    @State private var isTurning = false

    /// Whether a pinch is in progress, which takes the circle away from the turn.
    /// See the magnify gesture below.
    @State private var isPinching = false

    var body: some View {
        Color.clear
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
            // The hit area is invisible by design; in a debug
            // build a bright circle marks where it actually is.
            .debugSurfaceBorder(Circle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        // A two-finger pinch reaches this drag too, and the two
                        // gestures race for the touch — whichever recognises first
                        // holds it, so it is not knowable in advance which will win.
                        // Once a pinch has claimed the circle the turn stands down
                        // entirely, and the stage undoes any sample it had already
                        // taken, so the room never turns while it is being zoomed.
                        guard !isPinching else { return }
                        if !isTurning {
                            isTurning = true
                            stage.beginTurn()
                        }
                        stage.turn(byPoints: value.translation.width)
                    }
                    .onEnded { value in
                        // False when a pinch took the circle over, in which case
                        // the turn ended with the gesture rather than with a flick
                        // and there is nothing to hand off.
                        guard isTurning else { return }
                        isTurning = false
                        stage.endTurn(
                            pointsPerSecond: value.velocity.width,
                            reduceMotion: reduceMotion
                        )
                    }
            )
            // Pinch to zoom, on the same circle as the turn. Attached
            // simultaneously rather than exclusively so a two-finger pinch is
            // always recognised; the exclusivity is enforced above by the gate,
            // which the winner's timing cannot defeat.
            //
            // `MagnifyGesture` rather than the older `MagnificationGesture`: it is
            // the current API, it reports the raw magnification, and it carries
            // a velocity — which is what lets the stage hand the release to its
            // spring instead of faking a curve that starts by moving the right way.
            //
            // `minimumScaleDelta` cut from the default `0.01`, because that default
            // is a promise the gesture makes in the other direction: it holds back
            // until the fingers have moved that far, so the first sample a pinch
            // ever delivers is already a whole per cent of room. On a gesture this
            // direct that reads as a jump on touchdown. A fifth of that is still
            // below anything the eye resolves on a room filling the screen.
            .simultaneousGesture(
                MagnifyGesture(minimumScaleDelta: 0.002)
                    .onChanged { value in
                        if !isPinching {
                            isPinching = true
                            // The stage reverses the turn the losing gesture may
                            // have taken; this only closes the turn's own book, so
                            // its release does not fire a flick.
                            isTurning = false
                            stage.beginPinch()
                        }
                        stage.updatePinch(scale: Float(value.magnification))
                    }
                    .onEnded { value in
                        isPinching = false
                        stage.endPinch(
                            velocity: Float(value.velocity),
                            reduceMotion: reduceMotion
                        )
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Rotate room")
            .accessibilityValue("\(stage.turnDegrees) degrees")
            .accessibilityAdjustableAction { direction in
                let radians: Float = switch direction {
                case .increment: Self.accessibilityStep
                case .decrement: -Self.accessibilityStep
                @unknown default: 0
                }
                stage.turn(byRadians: radians)
            }
    }
}

// MARK: - Metrics

/// The tab row's dimensions, in one place. Read by `RoomView` as well as here,
/// because the row's clearance from the top of the page is the page's business
/// and this is where the number it uses lives.
enum RoomTabMetrics {
    /// Zero, so the tabs share one sampling region and never merge. Any value at
    /// or above the gap between them fuses them into a single shape.
    static let containerSpacing: CGFloat = 0

    /// Gap between tabs. Wider than a hairline so three glass capsules stay three
    /// capsules, narrow enough that the row reads as one control.
    static let gap: CGFloat = 6

    /// At least a fingertip tall.
    static let minimumHeight: CGFloat = 44

    static let fontSize: CGFloat = 17

    /// Clearance between the top of the page and the top of the row, as a
    /// fraction of the page's height. Proportional because the page ignores the
    /// safe area, so nothing in this tree can ask how tall the island is — the
    /// same reasoning `MemoryView` uses for its own top chrome, and for the same
    /// reason: a fraction of the screen moves with the screen.
    static let topFraction: CGFloat = 0.075
}