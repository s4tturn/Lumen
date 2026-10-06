//
//  FPSMonitor.swift
//  Lumen
//
//  Created by Satyajit Rajadhyaksha on 06/10/26.
//


import SwiftUI

// MARK: - Frame rate

/// What a debug build needs to be *seen* to work: a live frame-rate
/// counter, top-left.
///
/// Everything here compiles into every build, but only draws under the
/// `DEBUG` compilation condition — release builds carry the call sites
/// as no-ops, and the counter's display link never starts because the
/// view that owns it is never constructed.

/// Counts display refreshes over one-second windows.
///
/// `CADisplayLink` is the tool Apple recommends for riding the display
/// (WWDC21, "Optimize for variable refresh rate displays"): it wakes at
/// every vsync, and when the main run loop is too busy to service a
/// wake its callback is skipped — so the rate the callback runs at is
/// the rate the display is being driven at, and it falls exactly when
/// the app hitches. No public API reports that rate any more directly.
///
/// The accuracy is in three places. The window is bounded by the
/// link's own `timestamp` — the display's clock, and the same clock
/// every vsync is stamped with — rather than the wall clock, so a
/// window never spans a fraction of a frame more or less than a full
/// second. The count is the number of *intervals* the window holds,
/// not the number of callbacks: a window that opens on a callback and
/// closes on one holds one fewer interval than callbacks, so a steady
/// display reads exactly its refresh rate instead of one more. And the
/// result is rounded, so a display running a hair under 60 reads 60
/// rather than 59.
///
/// What this measures is the main thread's cadence — the frame rate of
/// a SwiftUI app, whose hitches are main-thread hitches. A hitch that
/// stalls only the render server drops no callback, and no public API
/// sees that from inside the process; Instruments' Core Animation
/// instrument is the tool for it.
///
/// The display link retains its target, so it is started and stopped
/// by the view's own appearance rather than left running: a link that
/// is never invalidated keeps its target alive for as long as the run
/// loop holds the link.
@Observable
final class FPSMonitor: NSObject {
    private(set) var framesPerSecond = 0
    private var displayLink: CADisplayLink?
    /// The vsync time of the first callback in the window, if one is
    /// open. `nil` until the first callback lands, so the first window
    /// is a full second rather than however much of one passed between
    /// `start()` and the next vsync.
    private var windowStart: Double?
    /// Callbacks since `windowStart` — one per presented interval.
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

    /// The action takes the link itself — the only way to read its
    /// `timestamp`, which is what bounds the window.
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
