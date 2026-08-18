import SwiftUI

struct AmbientSource: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let resourceName: String
    let fileExtension: String

    var url: URL? {
        Bundle.main.url(forResource: resourceName, withExtension: fileExtension)
    }

    static let all: [AmbientSource] = [
        AmbientSource(name: "Rain", icon: "cloud.rain.fill", color: .cyan, resourceName: "RainRecorded", fileExtension: "m4a"),
        AmbientSource(name: "Wind", icon: "wind", color: .gray, resourceName: "WindRecorded", fileExtension: "m4a"),
    ]
}
