import SwiftUI

// MARK: - Debug chrome

/// The things a debug build needs to be *seen* to work: bright borders
/// around surfaces, and a live frame-rate counter.
///
/// Everything here compiles into every build, but only draws under the
/// `DEBUG` compilation condition — release builds carry the call sites
/// as no-ops, and the FPS counter's display link never starts because
/// the view that owns it is never constructed.

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

// MARK: - FPS counter

/// Counts display refreshes over one-second windows.
///
/// The display link retains its target, so it is started and stopped
/// by the view's own appearance rather than left running: a link that
/// is never invalidated keeps its target alive for as long as the
/// run loop holds the link.
@Observable
final class FPSMonitor: NSObject {
    private(set) var framesPerSecond = 0
    private var displayLink: CADisplayLink?
    private var frameCount = 0
    private var sampleStart = CACurrentMediaTime()

    func start() {
        guard displayLink == nil else { return }
        frameCount = 0
        sampleStart = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(displayLinkDidFire))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func displayLinkDidFire() {
        frameCount += 1
        let now = CACurrentMediaTime()
        let elapsed = now - sampleStart
        guard elapsed >= 1 else { return }
        framesPerSecond = Int(Double(frameCount) / elapsed)
        frameCount = 0
        sampleStart = now
    }
}

/// A small frame-rate readout in a rounded rectangle.
struct DebugFPSCounter: View {
    @State private var monitor = FPSMonitor()

    var body: some View {
        // SF Pro with monospaced digits: the counter stays a number the
        // eye can track, without leaving the app's font vocabulary.
        Text("\(monitor.framesPerSecond) fps")
            .font(.system(size: 12, weight: .semibold).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                .black.opacity(0.55),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.25), lineWidth: 1)
            )
            .accessibilityHidden(true)
            .allowsHitTesting(false)
            .onAppear { monitor.start() }
            .onDisappear { monitor.stop() }
    }
}

/// The app's debug chrome: an FPS counter in a small rounded rectangle,
/// top-left, displaced 100pt from the top edge.
///
/// Empty in release builds — and because the counter view is only
/// constructed in the debug branch, its display link never runs there.
struct DebugChromeOverlay: View {
    var body: some View {
        #if DEBUG
        DebugFPSCounter()
            .padding(.top, 100)
            .padding(.leading, 12)
        #else
        EmptyView()
        #endif
    }
}
