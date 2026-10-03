import RealityKit
import SwiftUI
import _RealityKit_SwiftUI

/// The RealityKit surface: loads the room once, then hands the graph to
/// `stage`.
///
/// Nothing here runs again after load. `RealityView`'s setup closure is called
/// once per view identity, and from then on the stage — not this view — owns
/// everything that changes, so a drag never re-enters SwiftUI.
struct RoomRealityStage: View {
    let stage: RoomStage

    var body: some View {
        RealityView { content in
            // A virtual (non-AR) camera, and the neutral environment: the room
            // is lit by the asset, not by the room it happens to be in.
            content.camera = .virtual
            content.environment = .default

            guard let model = try? await Entity(named: RoomSceneFactory.assetName) else { return }
            let graph = RoomSceneFactory.make(from: model)
            content.add(graph.pivot)
            content.add(graph.camera)
            stage.install(graph)
        }
    }
}
