import AVFoundation
import Observation

@Observable
final class AmbientEngine {
    var isPlaying = false
    var currentSource: AmbientSource?

    var volume: Float = 0.25 {
        didSet { player?.volume = pow(volume, 3) }
    }

    private var player: AVAudioPlayer?
    private var observationTask: Task<Void, Never>?
    private var interruptedWhilePlaying = false

    init() {
        configureSession()
        currentSource = AmbientSource.all.first
        observationTask = observeAudioSession()
    }

    deinit {
        observationTask?.cancel()
    }

    func load(_ source: AmbientSource) {
        stop()
        currentSource = source
        guard let url = source.url else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        guard let player else { return }
        player.numberOfLoops = -1
        player.volume = pow(volume, 3)
        player.prepareToPlay()
    }

    func play() {
        if player == nil {
            if let source = currentSource ?? AmbientSource.all.first {
                load(source)
            }
        }
        guard let player else { return }
        let started = player.play()
        isPlaying = started
    }

    func pause() {
        guard let player else { return }
        player.pause()
        isPlaying = false
    }

    func stop() {
        player?.stop()
        player?.currentTime = 0
        player = nil
        isPlaying = false
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
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
            print("AmbientEngine: audio session setup failed - \(error)")
        }
    }

    /// Observes interruption and route-change notifications using modern
    /// `NotificationCenter` async sequences. Cancelled via `deinit`.
    private func observeAudioSession() -> Task<Void, Never> {
        Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask { [weak self] in
                    for await notification in NotificationCenter.default.notifications(
                        named: AVAudioSession.interruptionNotification,
                        object: AVAudioSession.sharedInstance()
                    ) {
                        guard let self else { return }
                        await MainActor.run { self.handleInterruption(notification) }
                    }
                }
                group.addTask { [weak self] in
                    for await notification in NotificationCenter.default.notifications(
                        named: AVAudioSession.routeChangeNotification,
                        object: AVAudioSession.sharedInstance()
                    ) {
                        guard let self else { return }
                        await MainActor.run { self.handleRouteChange(notification) }
                    }
                }
            }
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

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

    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        // HIG "Playing audio": when an output (e.g. headphones) disconnects,
        // people expect playback to pause immediately.
        if reason == .oldDeviceUnavailable, isPlaying {
            pause()
        }
    }
}
