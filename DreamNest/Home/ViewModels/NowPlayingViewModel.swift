import Foundation
import Combine
import AVFoundation

@MainActor
public final class NowPlayingViewModel: ObservableObject {
    @Published public private(set) var playlist: [AudioTrack] = []
    @Published public private(set) var currentTrackIndex: Int?

    @Published public private(set) var isPlaying: Bool = false

    @Published public private(set) var progress: Double = 0 // 0...1
    @Published public private(set) var currentTimeSeconds: TimeInterval = 0
    @Published public private(set) var durationSeconds: TimeInterval = 0
    @Published public private(set) var remainingSeconds: TimeInterval = 0

    @Published public var volume: Float = 0.8

    @Published public private(set) var sleepTimerState: SleepTimerController.State = .init(isRunning: false, remainingSeconds: 0, totalSeconds: 0, fadeOutSeconds: 0)
    @Published public private(set) var routineState: RoutineEngine.State = .idle

    private let audioPlayerService: AudioPlayerService
    private let sleepTimerController: SleepTimerController
    private let routineEngine: RoutineEngine

    private var progressTimer: Timer?

    private var trackByFilename: [String: AudioTrack]

    public init(library: AudioLibrary, audioPlayerService: AudioPlayerService? = nil) {
        self.audioPlayerService = audioPlayerService ?? AudioPlayerService()
        self.sleepTimerController = SleepTimerController(audioPlayerService: self.audioPlayerService)
        self.routineEngine = RoutineEngine(audioPlayerService: self.audioPlayerService)
        self.trackByFilename = Dictionary(uniqueKeysWithValues: library.tracks.map { ($0.filename, $0) })

        self.audioPlayerService.onPlaybackModeChanged = { [weak self] mode in
            guard let self else { return }
            self.isPlaying = (mode == .playing)
            if self.isPlaying {
                self.startProgressTimer()
            } else {
                self.stopProgressTimer()
                self.updateProgressFromAudio()
            }
        }

        self.sleepTimerController.onStateChanged = { [weak self] state in
            self?.sleepTimerState = state
        }

        self.sleepTimerController.onFinished = { [weak self] in
            guard let self else { return }
            // Sleep timer is an override: stop any active routine.
            if case .running = self.routineState {
                self.routineEngine.stop()
                self.routineState = .idle
            }
        }

        self.routineEngine.onStepChanged = { [weak self] _ in
            guard let self else { return }
            self.routineState = self.routineEngine.state
        }
        self.routineEngine.onFinished = { [weak self] in
            self?.routineState = .idle
        }
    }

    public func updateLibrary(_ library: AudioLibrary) {
        trackByFilename = Dictionary(uniqueKeysWithValues: library.tracks.map { ($0.filename, $0) })
    }

    // MARK: - Playback

    public func playTrack(_ track: AudioTrack, playlist: [AudioTrack], index: Int) {
        stopRoutineIfRunning()

        self.playlist = playlist
        self.currentTrackIndex = index

        guard let url = track.fileURL() else { return }
        do {
            try audioPlayerService.loadTrackURL(url)
            audioPlayerService.setVolume(volume)
            audioPlayerService.play()
            updateProgressFromAudio()
        } catch {
            // If loading fails, stay idle.
        }
    }

    public func togglePlayPause() {
        if isPlaying {
            audioPlayerService.pause()
            routineEngine.pause()
            if sleepTimerState.isRunning {
                sleepTimerController.pause()
            }
        } else {
            audioPlayerService.play()
            routineEngine.resume()
            if sleepTimerState.isRunning {
                sleepTimerController.resume()
            }
        }
    }

    public func next() {
        guard let currentTrackIndex else { return }
        guard !playlist.isEmpty else { return }
        stopRoutineIfRunning()

        let nextIndex = (currentTrackIndex + 1) % playlist.count
        playTrack(playlist[nextIndex], playlist: playlist, index: nextIndex)
    }

    public func previous() {
        guard let currentTrackIndex else { return }
        guard !playlist.isEmpty else { return }
        stopRoutineIfRunning()

        let prevIndex = (currentTrackIndex - 1 + playlist.count) % playlist.count
        playTrack(playlist[prevIndex], playlist: playlist, index: prevIndex)
    }

    public func seek(toProgress newProgress: Double) {
        guard durationSeconds > 0 else { return }
        let clamped = min(max(newProgress, 0), 1)
        let targetSeconds = durationSeconds * clamped
        audioPlayerService.setCurrentTime(targetSeconds)
        updateProgressFromAudio()
    }

    public func setVolume(_ newVolume: Float) {
        volume = min(max(newVolume, 0), 1)
        audioPlayerService.setVolume(volume)
        sleepTimerController.setUserVolume(volume)
        routineEngine.setPlaybackVolume(volume)
    }

    // MARK: - Sleep timer

    public func startSleepTimer(minutes: Int, fadeOutSeconds: Int) {
        sleepTimerController.start(totalMinutes: minutes, fadeOutSeconds: fadeOutSeconds, currentVolume: volume)
    }

    public func cancelSleepTimer() {
        // Quick Sleep UX: Cancel should stop music and reset the sleep timer.
        sleepTimerController.cancel()

        // Stop routine as well, since Quick Sleep may start a routine.
        routineEngine.stop()
        routineState = .idle

        audioPlayerService.stop(reason: .userStopped)

        playlist = []
        currentTrackIndex = nil
        progress = 0
        currentTimeSeconds = 0
        durationSeconds = 0
        remainingSeconds = 0
        isPlaying = false
    }

    public func stopAllPlaybackAndTimers() {
        cancelSleepTimer()
        routineEngine.stop()
        routineState = .idle

        audioPlayerService.stop(reason: .userStopped)

        playlist = []
        currentTrackIndex = nil
        progress = 0
        currentTimeSeconds = 0
        durationSeconds = 0
        remainingSeconds = 0
        isPlaying = false
    }

    // MARK: - Routines

    public func startRoutine(_ routine: Routine) {
        // Routines override the sleep timer to avoid conflicts.
        sleepTimerController.cancel()

        let resolver: (String) -> AudioTrack? = { [weak self] filename in
            self?.trackByFilename[filename]
        }
        routineEngine.start(routine: routine, trackResolver: resolver, volume: volume)
        routineState = routineEngine.state
    }

    public func stopRoutine() {
        routineEngine.stop()
        routineState = .idle
    }

    private func stopRoutineIfRunning() {
        if case .running = routineEngine.state {
            routineEngine.stop()
            routineState = .idle
        }
    }

    // MARK: - Progress updates

    private func startProgressTimer() {
        guard progressTimer == nil else { return }
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.updateProgressFromAudio()
        }
        RunLoop.main.add(progressTimer!, forMode: .common)
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func updateProgressFromAudio() {
        guard let current = audioPlayerService.currentTimeSeconds,
              let duration = audioPlayerService.durationSeconds else {
            progress = 0
            currentTimeSeconds = 0
            durationSeconds = 0
            remainingSeconds = 0
            return
        }

        currentTimeSeconds = max(0, current)
        durationSeconds = max(0, duration)

        if durationSeconds > 0 {
            progress = min(max(currentTimeSeconds / durationSeconds, 0), 1)
            remainingSeconds = max(0, durationSeconds - currentTimeSeconds)
        } else {
            progress = 0
            remainingSeconds = 0
        }
    }

    deinit {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}

