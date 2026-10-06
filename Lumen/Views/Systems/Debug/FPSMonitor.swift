import SwiftUI

@Observable
final class FPSMonitor: NSObject {
    private(set) var framesPerSecond = 0
    private var displayLink: CADisplayLink?

    private var windowStart: Double?

    private var intervals = 0

    func start() {
        guard displayLink == nil else { return }
        windowStart = nil
        intervals = 0
        let link = CADisplayLink(target: self, selector: #selector(displayLinkDidFire(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func displayLinkDidFire(_ link: CADisplayLink) {
        guard let start = windowStart else {
            windowStart = link.timestamp
            return
        }
        intervals += 1
        let elapsed = link.timestamp - start
        guard elapsed >= 1 else { return }
        framesPerSecond = Int((Double(intervals) / elapsed).rounded())
        windowStart = link.timestamp
        intervals = 0
    }
}

struct DebugFPSCounter: View {
    @State private var monitor = FPSMonitor()

    var body: some View {

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
