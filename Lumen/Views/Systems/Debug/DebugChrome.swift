//
//  DebugChrome.swift
//  Lumen
//
//  Created by Satyajit Rajadhyaksha on 06/10/26.
//


import SwiftUI

// MARK: - Debug chrome

/// What a debug build needs to be *seen* to work: bright borders
/// around surfaces. The frame-rate counter is the other half, and
/// lives in `DebugFPS.swift`.
///
/// Everything here compiles into every build, but only draws under the
/// `DEBUG` compilation condition — release builds carry the call sites
/// as no-ops.

/// Bright, fully-saturated colours — impossible to mistake for app
/// content, so a debug border can never be read as part of the design.
enum DebugChrome {
    /// The default border shape: a softly rounded rectangle.
    static let defaultBorderShape = RoundedRectangle(cornerRadius: 8, style: .continuous)

    static func randomBrightColor() -> Color {
        Color(hue: Double.random(in: 0...1), saturation: 0.95, brightness: 1)
    }
}

/// A bright, randomly-coloured outline around a surface.
///
/// The colour is drawn once per surface and held in `@State`, so a
/// re-render cannot flicker it. Pass the surface's own shape where it
/// has one — a circle for a circular hit area, a capsule for a pill —
/// and the border follows the edge the touch actually reaches.
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
    /// Outline this surface in a bright random colour, to make its hit
    /// area and edges visible. A no-op in release builds.
    func debugSurfaceBorder<S: Shape>(_ shape: S = DebugChrome.defaultBorderShape) -> some View {
        modifier(DebugSurfaceBorder(shape: shape))
    }
}
