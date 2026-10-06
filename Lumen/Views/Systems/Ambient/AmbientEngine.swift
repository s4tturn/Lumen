import SwiftUI
import AVFoundation
import Observation

nonisolated private struct DecodedBuffers: @unchecked Sendable {
    var buffers: [AmbientSource.ID: AVAudioPCMBuffer]
}

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

    @ObservationIgnored private var bufferCache: [AmbientSource.ID: AVAudioPCMBuffer] = [:]

    @ObservationIgnored private var observations: [NotificationCenter.ObservationToken] = []
    @ObservationIgnored private var interruptedWhilePlaying = false

    nonisolated private static let sourceURLs: [AmbientSource.ID: URL] = Dictionary(
        uniqueKeysWithValues: AmbientSource.all.compactMap { source in
            source.url.map { (source.id, $0) }
        }
    )

    init() {
        configureSession()
        configureEngine()
        currentSource = AmbientSource.all.first
        prewarmBuffers()
        observeSession()
        observeRouteChanges()
    }

    private func buffer(for source: AmbientSource) -> AVAudioPCMBuffer? {
        if let cached = bufferCache[source.id] { return cached }
        guard let decoded = Self.decode(source.id) else { return nil }
        bufferCache[source.id] = decoded
        return decoded
    }

    private nonisolated static func decode(_ id: AmbientSource.ID) -> AVAudioPCMBuffer? {
        guard let url = sourceURLs[id] else { return nil }
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else { return nil }
        try? file.read(into: buffer)
        return buffer
    }

    private func prewarmBuffers() {
        Task(priority: .userInitiated) {
            let decoded = await Task.detached(priority: .userInitiated) {
                DecodedBuffers(
                    buffers: Dictionary(
                        uniqueKeysWithValues: AmbientSource.all.compactMap { source in
                            Self.decode(source.id).map { (source.id, $0) }
                        }
                    )
                )
            }.value

            bufferCache.merge(decoded.buffers) { cached, _ in cached }
        }
    }

    private func configureEngine() {
        engine.attach(mixer)
        engine.attach(playerNode)
        do {
            try engine.connectNode(playerNode, to: mixer, format: nil)
            try engine.connectNode(mixer, to: engine.mainMixerNode, format: nil)
        } catch {
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

    func select(_ source: AmbientSource) {
        let wasPlaying = isPlaying
        load(source)
        if wasPlaying { play() }
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
        }
    }

    private func observeSession() {
        let session = AVAudioSession.sharedInstance()
        observations = [
            NotificationCenter.default.addObserver(of: session, for: .didBecomeInactive) {
                [weak self] _ in
                guard let self else { return }
                self.interruptedWhilePlaying = self.isPlaying
                if self.isPlaying { self.pause() }
            },
            NotificationCenter.default.addObserver(of: session, for: .resumptionRecommendation) {
                [weak self] (message: AVAudioSession.ResumptionRecommendationMessage) in
                guard let self, self.interruptedWhilePlaying else { return }
                self.interruptedWhilePlaying = false
                guard message.recommendation == .shouldResume else { return }
                Task { @MainActor in
                    if (try? await session.activate(options: [])) == true {
                        self.play()
                    }
                }
            }
        ]
    }

    private func observeRouteChanges() {
        let session = AVAudioSession.sharedInstance()
        Task { @MainActor [weak self] in
            for await notification in NotificationCenter.default.notifications(
                named: AVAudioSession.routeChangeNotification,
                object: session
            ) {
                guard let self else { return }
                self.handleRouteChange(notification)
            }
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        else { return }

        if reason == .oldDeviceUnavailable, isPlaying {
            pause()
        }
    }
}
