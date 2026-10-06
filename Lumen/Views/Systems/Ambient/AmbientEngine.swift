import SwiftUI
import AVFoundation
import Observation
import OSLog

private let ambientLog = Logger(subsystem: "s4tturn.Lumen", category: "Ambient")

/// Decoded loops ready to schedule.
///
/// `AVAudioPCMBuffer` isn't `Sendable`, and this hands one from the decoder to
/// the main actor. That's sound: a buffer here is allocated, filled once by
/// `AVAudioFile.read`, and thereafter only read — `scheduleBuffer` copies from
/// it and never writes — so there is no shared mutable state to race on.
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
    /// No view reads the cache, so it isn't tracked — a decoded loop landing
    /// here should never invalidate anything.
    @ObservationIgnored private var bufferCache: [AmbientSource.ID: AVAudioPCMBuffer] = [:]
    /// Observation lives as long as these do. `NotificationCenter` ends an
    /// observation when its token is discarded, so holding them here is the
    /// whole lifetime story — there is nothing to tear down in `deinit`.
    @ObservationIgnored private var observations: [NotificationCenter.ObservationToken] = []
    @ObservationIgnored private var interruptedWhilePlaying = false

    /// The source files, resolved once. Done up front so the detached decode
    /// below never has to reach for the bundle.
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

    // MARK: - Buffer Management

    /// The decoded loop for a source, read synchronously so playback can start
    /// the moment it is asked for. The prewarm fills this first; decoding here
    /// only covers a source that arrived before its turn came round.
    private func buffer(for source: AmbientSource) -> AVAudioPCMBuffer? {
        if let cached = bufferCache[source.id] { return cached }
        guard let decoded = Self.decode(source.id) else { return nil }
        bufferCache[source.id] = decoded
        return decoded
    }

    /// Decodes one source into a single PCM buffer — the whole file, since a
    /// loop has to be resident to repeat seamlessly.
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

    /// Decodes every source off the main actor.
    ///
    /// The two loops are ~40 seconds of stereo AAC each, which unpacks to about
    /// 30 MB of PCM — tens of milliseconds of decompression that would
    /// otherwise land on the main thread while the first view is still being
    /// set up. Nothing observes the result until playback asks for it, so the
    /// cache can fill in behind the first frame.
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
            // Keep anything already decoded on demand rather than replacing it.
            bufferCache.merge(decoded.buffers) { cached, _ in cached }
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
            try session.setActive(true)
        } catch {
            ambientLog.error("Audio session setup failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Session Life Cycle (iOS 27 activation model)

    /// iOS 27 models an interruption as the session being deactivated and then
    /// recommended for resumption, rather than as a begin/end pair — so it can
    /// never leave this engine stuck mid-interruption. Both are read through
    /// the typed message API, which carries the payload as a property instead
    /// of a `userInfo` cast, and delivers on the main actor by construction.
    private func observeSession() {
        let session = AVAudioSession.sharedInstance()
        observations = [
            NotificationCenter.default.addObserver(of: session, for: .didBecomeInactive) {
                [weak self] (message: AVAudioSession.DidBecomeInactiveMessage) in
                guard let self else { return }
                if case .systemInterruption(let context) = message.deactivationResult {
                    ambientLog.debug("Session interrupted: \(context.reason.rawValue)")
                }
                self.interruptedWhilePlaying = self.isPlaying
                if self.isPlaying { self.pause() }
            },
            NotificationCenter.default.addObserver(of: session, for: .resumptionRecommendation) {
                [weak self] (message: AVAudioSession.ResumptionRecommendationMessage) in
                guard let self, self.interruptedWhilePlaying else { return }
                self.interruptedWhilePlaying = false
                guard message.recommendation == .shouldResume else { return }
                // Apple documents re-activating the session as part of resuming,
                // and `activate(options:)` is the asynchronous form of activation
                // — so playback waits on it rather than racing it. Activation
                // reports whether it actually took, so a session that stays
                // inactive leaves the engine paused rather than playing into
                // nothing.
                Task { @MainActor in
                    guard (try? await session.activate(options: [])) == true else {
                        ambientLog.error("Audio session declined to reactivate; staying paused")
                        return
                    }
                    self.play()
                }
            }
        ]
    }

    // MARK: - Route Change Handling

    /// The route-change notification has no typed message, so this one stays on
    /// the async sequence — which also hands the main actor back for free.
    /// Nothing holds the loop: the weak capture ends it when the engine does.
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

        // HIG "Playing audio": when an output (e.g. headphones) disconnects,
        // people expect playback to pause immediately. Other reasons — a dock
        // appearing, AirPods arriving — are not a loss of output and so are
        // deliberately not acted on.
        if reason == .oldDeviceUnavailable, isPlaying {
            pause()
        }
    }
}