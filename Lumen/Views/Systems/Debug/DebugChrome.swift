import SwiftUI

enum DebugChrome {

    static let defaultBorderShape = RoundedRectangle(cornerRadius: 8, style: .continuous)

    static func randomBrightColor() -> Color {
        Color(hue: Double.random(in: 0...1), saturation: 0.95, brightness: 1)
    }
}

struct DebugSurfaceBorder<S: Shape>: ViewModifier {
    let shape: S
    @State private var borderColor: Color = DebugChrome.randomBrightColor()

    func body(content: Content) -> some View {
        content.overlay {
            #if DEBUG
            shape.stroke(borderColor, lineWidth: 2)
            #else
            EmptyView()
            #endif
        }
    }
}

extension View {

    func debugSurfaceBorder<S: Shape>(_ shape: S = DebugChrome.defaultBorderShape) -> some View {
        modifier(DebugSurfaceBorder(shape: shape))
    }
}
