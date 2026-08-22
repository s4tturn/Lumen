import SwiftUI
import AVFoundation
import Observation

@Observable
final class AmbientEngine: @unchecked Sendable {
    var isPlaying = false
    var currentSource: AmbientSource?

    var volume: Float = 0.25 {
        didSet { mixer.outputVolume = volume }
    }

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let mixer = AVAudioMixerNode()
    private var bufferCache: [AmbientSource.ID: AVAudioPCMBuffer] = [:]
    private var interruptionTask: Task<Void, Never>?
    private var routeChangeTask: Task<Void, Never>?
    private var interruptedWhilePlaying = false

    init() {
        configureSession()
        configureEngine()
        currentSource = AmbientSource.all.first
        prewarmBuffers()
        observeInterruptions()
        observeRouteChanges()
    }

    deinit {
        interruptionTask?.cancel()
        routeChangeTask?.cancel()
        engine.stop()
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
        engine.connect(playerNode, to: mixer, format: nil)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)
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
        playerNode.play()
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
            print("AmbientEngine: audio session setup failed - \(error)")
        }
    }

    // MARK: - Interruption Handling

    private func observeInterruptions() {
        interruptionTask = Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(
                named: AVAudioSession.interruptionNotification,
                object: AVAudioSession.sharedInstance()
            ) {
                guard let self else { return }
                self.handleInterruption(notification)
            }
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        switch type {
        case .began:
            interruptedWhilePlaying = isPlaying
            if isPlaying { pause() }
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume), interruptedWhilePlaying {
                interruptedWhilePlaying = false
                play()
            }
        default:
            break
        }
    }

    // MARK: - Route Change Handling

    private func observeRouteChanges() {
        routeChangeTask = Task { [weak self] in
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
