import AVFoundation
import Observation

@Observable
final class AmbientEngine {
    var isPlaying = false

    var volume: Float = 1 {
        didSet { player?.volume = pow(volume, 3) }
    }

    private var player: AVAudioPlayer?

    init() {
        configureSession()
    }

    func load(_ source: AmbientSource) {
        stop()
        guard let url = source.url else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        guard let player else { return }
        player.numberOfLoops = -1
        player.volume = pow(volume, 3)
        player.prepareToPlay()
    }

    func play() {
        guard let player else { return }
        player.play()
        isPlaying = true
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

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("AmbientEngine: audio session setup failed - \(error)")
        }
    }
}
