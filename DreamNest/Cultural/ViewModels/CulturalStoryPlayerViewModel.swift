import Foundation
import Combine
import AVFoundation

@MainActor
final class CulturalStoryPlayerViewModel: ObservableObject {
    @Published var phase: PlayerPhase = .idle
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var loadingMessage = "Gathering stars for your story…"

    enum PlayerPhase: Equatable {
        case idle
        case loading
        case playing
        case error(String)
    }

    let story: CulturalStory
    let template: CulturalTemplate

    private let service = CulturalStoryService()
    private var audioPlayer: AVAudioPlayer?
    private var backgroundPlayer: AVAudioPlayer?          // soft lullaby behind narration
    nonisolated(unsafe) private var progressTimer: Timer?

    init(story: CulturalStory, template: CulturalTemplate) {
        self.story = story
        self.template = template
    }

    // MARK: - Load & play

    func loadAndPlay() async {
        // Allow starting from idle or after an error; block if already loading/playing
        switch phase {
        case .loading, .playing: return
        default: break
        }
        phase = .loading

        // Cycle loading messages while we wait
        let messageTask = Task { [weak self] in
            let messages = [
                "Gathering stars for your story…",
                "Waking up the storyteller…",
                "Sprinkling some magic dust…",
                "Almost ready to begin…"
            ]
            for msg in messages {
                guard !Task.isCancelled else { return }
                await MainActor.run { self?.loadingMessage = msg }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }

        do {
            let url = try await service.audioURL(for: story, template: template)
            messageTask.cancel()

            try configureAudioSession()
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            audioPlayer = player
            duration = player.duration
            isPlaying = true
            phase = .playing
            startTimer()
            startBackgroundMusic()      // 🎵 soft lullaby begins
        } catch {
            messageTask.cancel()
            phase = .error(error.localizedDescription)
        }
    }

    // MARK: - Controls

    func togglePlayPause() {
        guard let player = audioPlayer else { return }
        if player.isPlaying {
            player.pause()
            backgroundPlayer?.pause()
            isPlaying = false
            progressTimer?.invalidate()
        } else {
            player.play()
            backgroundPlayer?.play()
            isPlaying = true
            startTimer()
        }
    }

    func seek(to fraction: Double) {
        guard let player = audioPlayer else { return }
        player.currentTime = fraction * player.duration
        currentTime = player.currentTime
        progress = fraction
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        stopBackgroundMusic()
        progressTimer?.invalidate()
        isPlaying = false
        progress = 0
        currentTime = 0
    }

    // MARK: - Background music

    private func startBackgroundMusic() {
        // Pick a random lullaby from the app bundle as ambient background
        let track = Int.random(in: 1...17)
        guard let url = Bundle.main.url(forResource: "Lullabies__\(track)", withExtension: "mp3") else {
            return
        }
        do {
            let bg = try AVAudioPlayer(contentsOf: url)
            bg.numberOfLoops = -1       // loop indefinitely
            bg.volume = 0.10            // whisper-quiet behind the narrator
            bg.prepareToPlay()
            bg.play()
            backgroundPlayer = bg
        } catch { }
    }

    private func stopBackgroundMusic() {
        backgroundPlayer?.stop()
        backgroundPlayer = nil
    }

    // MARK: - Private

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.allowBluetoothA2DP])
        try session.setActive(true)
    }

    private func startTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    private func tick() {
        guard let player = audioPlayer else { return }
        currentTime = player.currentTime
        duration    = player.duration
        progress    = duration > 0 ? currentTime / duration : 0

        if !player.isPlaying && progress >= 0.98 {
            isPlaying = false
            progressTimer?.invalidate()
            stopBackgroundMusic()
            progress    = 0
            currentTime = 0
            phase       = .idle
        }
    }

    deinit {
        progressTimer?.invalidate()
    }
}
