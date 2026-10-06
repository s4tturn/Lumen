import SwiftUI

struct RoomTab: View {
    @Binding var selection: RoomScene

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

            .debugSurfaceBorder()
        }
    }
}

private struct RoomTabButton: View {
    let scene: RoomScene
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: scene.symbol)
                .symbolVariant(isSelected ? .fill : .none)
                .font(.system(size: RoomTabMetrics.fontSize, weight: .medium))
                .foregroundStyle(.primary)
                .frame(minWidth: RoomTabMetrics.minimumHeight, minHeight: RoomTabMetrics.minimumHeight)
        }

        .buttonStyle(.glass(isSelected ? .regular.tint(scene.tabTint).interactive() : .regular.interactive()))

        .accessibilityLabel(Text(scene.title))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .debugSurfaceBorder()
    }
}

enum RoomTabMetrics {

    static let containerSpacing: CGFloat = 0

    static let gap: CGFloat = 6

    static let minimumHeight: CGFloat = 44

    static let fontSize: CGFloat = 17

    static let topFraction: CGFloat = 0.075
}
import SwiftUI

struct RoomTurnHandle: View {

    private static let accessibilityStep: Float = .pi / 12

    let diameter: CGFloat
    let stage: RoomStage

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isTurning = false

    @State private var isPinching = false

    var body: some View {
        Color.clear
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())

            .debugSurfaceBorder(Circle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in

                        guard !isPinching else { return }
                        if !isTurning {
                            isTurning = true
                            stage.beginTurn()
                        }
                        stage.turn(byPoints: value.translation.width)
                    }
                    .onEnded { value in

                        guard isTurning else { return }
                        isTurning = false
                        stage.endTurn(
                            pointsPerSecond: value.velocity.width,
                            reduceMotion: reduceMotion
                        )
                    }
            )

            .simultaneousGesture(
                MagnifyGesture(minimumScaleDelta: 0.002)
                    .onChanged { value in
                        if !isPinching {
                            isPinching = true

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
