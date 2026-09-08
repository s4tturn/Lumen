import SwiftUI
import AVFoundation
import Observation
import OSLog

private let ambientLog = Logger(subsystem: "s4tturn.Lumen", category: "Ambient")

@MainActor
@Observable
final class AmbientEngine {
    var isPlaying = false
    var currentSource: AmbientSource?

    var volume: Float = 0.25 {
        didSet { mixer.outputVolume = volume }
    }

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let mixer = AVAudioMixerNode()
    private var bufferCache: [AmbientSource.ID: AVAudioPCMBuffer] = [:]
    // Task handles are Sendable; excluded from observation and nonisolated
    // so deinit can cancel them.
    @ObservationIgnored private nonisolated(unsafe) var interruptionTask: Task<Void, Never>?
    @ObservationIgnored private nonisolated(unsafe) var resumptionTask: Task<Void, Never>?
    @ObservationIgnored private nonisolated(unsafe) var routeChangeTask: Task<Void, Never>?
    private var interruptedWhilePlaying = false

    init() {
        configureSession()
        configureEngine()
        currentSource = AmbientSource.all.first
        prewarmBuffers()
        observeInterruptions()
        observeResumptionRecommendation()
        observeRouteChanges()
    }

    deinit {
        interruptionTask?.cancel()
        resumptionTask?.cancel()
        routeChangeTask?.cancel()
    }

    // MARK: - Buffer Management

    private func buffer(for source: AmbientSource) -> AVAudioPCMBuffer? {
        if let cached = bufferCache[source.id] { return cached }
        guard let url = source.url else { return nil }
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        try? file.read(into: buffer)
        bufferCache[source.id] = buffer
        return buffer
    }

    private func prewarmBuffers() {
        for source in AmbientSource.all {
            _ = buffer(for: source)
        }
    }

    // MARK: - Engine Configuration

    private func configureEngine() {
        engine.attach(mixer)
        engine.attach(playerNode)
        do {
            try engine.connectNode(playerNode, to: mixer, format: nil)
            try engine.connectNode(mixer, to: engine.mainMixerNode, format: nil)
        } catch {
            ambientLog.error("Engine connect failed: \(error.localizedDescription)")
            return
        }
        mixer.outputVolume = volume
        try? engine.start()
    }

    func load(_ source: AmbientSource) {
        stop()
        currentSource = source
    }

    func play() {
        guard let source = currentSource ?? AmbientSource.all.first else { return }
        if playerNode.isPlaying { playerNode.stop() }

        guard let buf = buffer(for: source) else { return }

        playerNode.scheduleBuffer(buf, at: nil, options: .loops)
        do {
            try playerNode.playAudio()
        } catch {
            ambientLog.error("Playback failed: \(error.localizedDescription)")
            return
        }
        isPlaying = true
    }

    func pause() {
        playerNode.pause()
        isPlaying = false
    }

    func stop() {
        playerNode.stop()
        isPlaying = false
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    /// Switches the active source. Preserves the current play/pause state — if
    /// ambient sound is playing, the new source fades in; if paused, the pill
    /// simply retargets to the new source without starting playback.
    func select(_ source: AmbientSource) {
        let wasPlaying = isPlaying
        load(source)
        if wasPlaying { play() }
    }

    // MARK: - Audio Session

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // HIG "Playing audio": ambient sound should mix with other apps'
            // audio rather than silencing it.
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            ambientLog.error("Audio session setup failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Interruption Handling (iOS 27 session model)

    private func observeInterruptions() {
        interruptionTask = Task { @MainActor [weak self] in
            for await notification in NotificationCenter.default.notifications(
                named: AVAudioSession.didBecomeInactiveNotification,
                object: AVAudioSession.sharedInstance()
            ) {
                guard let self else { return }
                self.handleDeactivation(notification)
            }
        }
    }

    private func handleDeactivation(_ notification: Notification) {
        interruptedWhilePlaying = isPlaying
        if isPlaying { pause() }
        if let context = notification.userInfo?[AVAudioSession.deactivationContextKey]
            as? AVAudioSession.DeactivationContext
        {
            ambientLog.debug("Session deactivated by \(context.source.rawValue)")
        }
    }

    private func handleResumptionRecommendation(_ notification: Notification) {
        guard let context = notification.userInfo?[AVAudioSession.resumptionContextKey]
            as? AVAudioSession.ResumptionContext
        else { return }

        if context.recommendation == .shouldResume, interruptedWhilePlaying {
            interruptedWhilePlaying = false
            play()
        } else {
            interruptedWhilePlaying = false
        }
    }

    // MARK: - Route Change Handling

    private func observeResumptionRecommendation() {
        resumptionTask = Task { @MainActor [weak self] in
            for await notification in NotificationCenter.default.notifications(
                named: AVAudioSession.resumptionRecommendationNotification,
                object: AVAudioSession.sharedInstance()
            ) {
                guard let self else { return }
                self.handleResumptionRecommendation(notification)
            }
        }
    }

    private func observeRouteChanges() {        routeChangeTask = Task { @MainActor [weak self] in
            for await notification in NotificationCenter.default.notifications(
                named: AVAudioSession.routeChangeNotification,
                object: AVAudioSession.sharedInstance()
            ) {
                guard let self else { return }
                self.handleRouteChange(notification)
            }
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        else { return }

        // HIG "Playing audio": when an output (e.g. headphones) disconnects,
        // people expect playback to pause immediately.
        if reason == .oldDeviceUnavailable, isPlaying {
            pause()
        }
    }
}
