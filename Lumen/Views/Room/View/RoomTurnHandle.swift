import SwiftUI

/// The circular drag target that turns the room.
///
/// Occupies a square `diameter` points across and is entirely transparent: it
/// exists to catch the drag, not to be seen. `RoomView` sizes it to the page
/// width, which makes its hit area the circle the room is drawn in — so drags
/// on the room turn it, and anything outside it stays with the pager.
struct RoomTurnHandle: View {
    /// Radians of rotation per point of horizontal travel. Tuned so a drag
    /// across half the circle sweeps the room about 90°, which is the wrist
    /// movement that feels like turning something rather than flicking it.
    private static let radiansPerPoint: CGFloat = 0.01

    /// VoiceOver's swipe-up/swipe-down step, in radians — about 15°, roughly a
    /// sixteenth of a turn per swipe.
    private static let accessibilityStep: Float = .pi / 12

    let diameter: CGFloat
    let stage: RoomStage

    @State private var dragBaseYaw: Float = 0

    var body: some View {
        Color.clear
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        let yaw = dragBaseYaw + Float(value.translation.width * Self.radiansPerPoint)
                        stage.setYaw(yaw)
                    }
                    .onEnded { value in
                        let yaw = dragBaseYaw + Float(value.translation.width * Self.radiansPerPoint)
                        dragBaseYaw = yaw
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Rotate room")
            .accessibilityValue("\(stage.turnDegrees) degrees")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: stage.turn(byRadians: Self.accessibilityStep)
                case .decrement: stage.turn(byRadians: -Self.accessibilityStep)
                @unknown default: break
                }
            }
    }
}
