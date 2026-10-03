import SwiftUI

/// The top-leading menu that shows and hides individual objects in the room.
///
/// Reads `stage.objects`, the page's only observed property, so this is the one
/// view in the room that redraws when the room changes.
struct RoomObjectsMenu: View {
    let stage: RoomStage

    var body: some View {
        Menu {
            if stage.objects.isEmpty {
                Text("Loading objects…")
                    .disabled(true)
            } else {
                ForEach(stage.objects) { object in
                    Toggle(isOn: binding(for: object.id)) {
                        // Verbatim: these are the asset's own node names, not
                        // copy that should be looked up in a strings table.
                        Text(verbatim: object.id)
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.glass(.regular))
        .accessibilityLabel("Objects")
    }

    /// Routes a row's toggle through the stage, so the menu's idea of what is
    /// shown and RealityKit's can never drift apart.
    private func binding(for id: RoomObject.ID) -> Binding<Bool> {
        Binding(
            get: { stage.objects.first { $0.id == id }?.isVisible ?? true },
            set: { stage.setVisibility($0, for: id) }
        )
    }
}
