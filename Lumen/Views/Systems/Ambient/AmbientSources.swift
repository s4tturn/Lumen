import SwiftUI

/// A loopable sound. A plain value: nothing here touches the actor, so the
/// type opts out of the project's default isolation and can be read from the
/// background decode that warms these files.
nonisolated struct AmbientSource: Identifiable, Sendable {
    /// Stable across rebuilds — never a fresh UUID per render (morph/id rule).
    var id: String { resourceName }
    let name: String
    let icon: String
    let color: Color
    let resourceName: String
    let fileExtension: String

    var url: URL? {
        Bundle.main.url(forResource: resourceName, withExtension: fileExtension)
    }

    static let all: [AmbientSource] = [
        AmbientSource(name: "Rain", icon: "cloud.rain", color: .cyan, resourceName: "RainRecorded", fileExtension: "m4a"),
        AmbientSource(name: "Forest", icon: "tree", color: .green, resourceName: "ForestRecorded", fileExtension: "m4a"),
        AmbientSource(name: "Wind", icon: "wind", color: .gray, resourceName: "WindRecorded", fileExtension: "m4a"),
    ]
}
