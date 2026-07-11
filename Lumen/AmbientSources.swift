import SwiftUI

struct AmbientSource: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let resourceName: String
    let fileExtension: String

    var url: URL? {
        let filename = "\(resourceName).\(fileExtension)"
        let all = Bundle.main.urls(forResourcesWithExtension: fileExtension, subdirectory: nil) ?? []
        return all.first { $0.lastPathComponent == filename }
    }

    static let all: [AmbientSource] = [
        AmbientSource(name: "Rain", icon: "cloud.rain.fill", color: .cyan, resourceName: "RainRecorded", fileExtension: "m4a"),
        AmbientSource(name: "Wind", icon: "wind", color: .gray, resourceName: "WindRecorded", fileExtension: "m4a"),
    ]
}
