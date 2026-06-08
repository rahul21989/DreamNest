import Foundation
import AVFoundation

@MainActor
public final class RoutineEngine {
    public enum State: Equatable, Sendable {
        case idle
        case running(routineID: UUID, stepIndex: Int)
    }

    private struct ResolvedStep: Sendable {
        let track: AudioTrack
        let plannedDurationSeconds: TimeInterval
    }

    private let audioPlayerService: AudioPlayerService

    private var stateInternal: State = .idle
    public var state: State { stateInternal }

    private var routineID: UUID?
    private var steps: [ResolvedStep] = []
    private var currentStepIndex = 0

    private var stepTimer: DispatchSourceTimer?
    private var endTime: DispatchTime?
    private var remainingWhenPaused: TimeInterval = 0
    private var stepTimerCompleted = false

    private var userPaused = false
    private var interruptionPaused = false
    private var routePaused = false

    public var onStepChanged: ((Int) -> Void)?
    public var onFinished: (() -> Void)?

    // nonisolated(unsafe) lets deinit (which runs off the main actor) safely
    // read the token to unregister the finish observer without a concurrency warning.
    nonisolated(unsafe) private var finishObserverToken: UUID?
    private var playbackVolume: Float = 1

    public init(audioPlayerService: AudioPlayerService) {
        self.audioPlayerService = audioPlayerService

        finishObserverToken = audioPlayerService.addFinishObserver { [weak self] reason in
            guard let self else { return }
            guard reason == .natural else { return }
            Task { @MainActor in
                self.handleAudioFinishedNaturally()
            }
        }

        registerForAudioNotifications()
    }

    deinit {
        if let finishObserverToken {
            audioPlayerService.removeFinishObserver(finishObserverToken)
        }
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public API

    public func start(
        routine: Routine,
        trackResolver: (String) -> AudioTrack?,
        volume: Float
    ) {
        stop()

        let resolved: [ResolvedStep] = routine.steps.compactMap { step in
            guard let track = trackResolver(step.trackFilename) else { return nil }
            let requested = max(0, step.durationSeconds)
            if requested <= 0 {
                // If user didn't provide a step duration, default to track duration.
                let inferred = track.durationSeconds > 0 ? track.durationSeconds : 0
                return inferred > 0 ? ResolvedStep(track: track, plannedDurationSeconds: inferred) : nil
            }

            let effective: TimeInterval
            if track.durationSeconds > 0 {
                effective = min(requested, track.durationSeconds)
            } else {
                effective = requested
            }

            return effective > 0 ? ResolvedStep(track: track, plannedDurationSeconds: effective) : nil
        }

        guard !resolved.isEmpty else { return }

        self.routineID = routine.id
        self.steps = resolved
        self.currentStepIndex = 0
        self.playbackVolume = min(max(volume, 0), 1)
        self.stepTimerCompleted = false
        self.userPaused = false
        self.interruptionPaused = false
        self.routePaused = false

        stateInternal = .running(routineID: routine.id, stepIndex: 0)
        playCurrentStep()
    }

    public func stop() {
        timerCancel()
        steps = []
        routineID = nil
        currentStepIndex = 0
        stepTimerCompleted = false

        stateInternal = .idle
        // Best effort: stop playback.
        audioPlayerService.stop(reason: .userStopped)
    }

    public func pause() {
        guard case .running = stateInternal else { return }
        guard !userPaused else { return }
        userPaused = true
        pauseStepTimer()
    }

    public func resume() {
        guard case .running = stateInternal else { return }
        guard userPaused else { return }
        userPaused = false
        if !interruptionPaused && !routePaused {
            resumeStepTimer()
        }
    }

    public func setPlaybackVolume(_ volume: Float) {
        playbackVolume = min(max(volume, 0), 1)
        if case .running = stateInternal, !audioPlayerService.isPlaying {
            // Audio is currently paused, but keep the volume for the next resume.
        } else if case .running = stateInternal {
            audioPlayerService.setVolume(playbackVolume)
        }
    }

    // MARK: - Audio notifications integration

    private func registerForAudioNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    @objc
    private func handleInterruption(_ notification: Notification) {
        guard case .running = stateInternal else { return }
        guard let userInfo = notification.userInfo else { return }

        let type = (userInfo[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap { AVAudioSession.InterruptionType(rawValue: $0) }
        switch type {
        case .some(.began):
            guard !userPaused else { return }
            interruptionPaused = true
            pauseStepTimer()
        case .some(.ended):
            let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt
            let option = optionsValue.flatMap { AVAudioSession.InterruptionOptions(rawValue: $0) }
            let shouldResume = option?.contains(.shouldResume) ?? false
            if shouldResume, interruptionPaused, !userPaused {
                interruptionPaused = false
                resumeStepTimer()
            }
        default:
            break
        }
    }

    @objc
    private func handleRouteChange(_ notification: Notification) {
        guard case .running = stateInternal else { return }
        guard let userInfo = notification.userInfo else { return }

        let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt
        let reason = reasonValue.flatMap { AVAudioSession.RouteChangeReason(rawValue: $0) }

        switch reason {
        case .some(.oldDeviceUnavailable):
            guard !userPaused else { return }
            routePaused = true
            pauseStepTimer()
        case .some(.newDeviceAvailable):
            guard routePaused, !userPaused else { return }
            routePaused = false
            resumeStepTimer()
        default:
            break
        }
    }

    // MARK: - Step scheduling

    private func playCurrentStep() {
        guard currentStepIndex >= 0, currentStepIndex < steps.count else {
            finish()
            return
        }

        stepTimerCompleted = false
        let step = steps[currentStepIndex]
        do {
            if let url = step.track.fileURL() {
                try audioPlayerService.loadTrackURL(url)
                audioPlayerService.setVolume(playbackVolume)
                audioPlayerService.play()
            } else {
                // Missing asset; skip forward.
                advanceStep()
            }
        } catch {
            advanceStep()
        }

        onStepChanged?(currentStepIndex)

        scheduleStepTimer(seconds: step.plannedDurationSeconds)
    }

    private func scheduleStepTimer(seconds: TimeInterval) {
        timerCancel()
        endTime = .now() + seconds

        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: .milliseconds(200))
        t.setEventHandler { [weak self] in
            guard let self else { return }
            self.tick()
        }
        stepTimer = t
        t.resume()
    }

    private func tick() {
        guard case .running = stateInternal else { return }
        guard let endTime else { return }
        let remaining = Self.seconds(from: endTime)
        if remaining <= 0 {
            completeCurrentStep(triggeredByTimer: true)
        }
    }

    private func completeCurrentStep(triggeredByTimer: Bool) {
        guard case .running = stateInternal else { return }
        guard !stepTimerCompleted else { return }
        stepTimerCompleted = true
        timerCancel()

        if triggeredByTimer {
            // Stop the current track to force the step transition.
            audioPlayerService.stop(reason: .routineStepCompleted)
        }

        advanceStep()
    }

    private func handleAudioFinishedNaturally() {
        guard case .running = stateInternal else { return }
        guard !stepTimerCompleted else { return }
        // Audio ended early; transition immediately.
        completeCurrentStep(triggeredByTimer: false)
    }

    private func advanceStep() {
        guard case .running = stateInternal else { return }
        let next = currentStepIndex + 1
        if next < steps.count {
            currentStepIndex = next
            stateInternal = .running(routineID: routineID ?? UUID(), stepIndex: currentStepIndex)
            playCurrentStep()
        } else {
            finish()
        }
    }

    private func finish() {
        timerCancel()
        steps = []
        routineID = nil
        currentStepIndex = 0
        stepTimerCompleted = false
        stateInternal = .idle
        onFinished?()
    }

    private func pauseStepTimer() {
        guard case .running = stateInternal else { return }
        timerCancel()
        if let endTime {
            remainingWhenPaused = max(0, Self.seconds(from: endTime))
        }
        endTime = nil
    }

    private func resumeStepTimer() {
        guard case .running = stateInternal else { return }
        guard remainingWhenPaused > 0 else {
            completeCurrentStep(triggeredByTimer: true)
            return
        }
        scheduleStepTimer(seconds: remainingWhenPaused)
    }

    private func timerCancel() {
        stepTimer?.cancel()
        stepTimer = nil
        endTime = nil
    }

    private static func seconds(from dispatchTime: DispatchTime) -> TimeInterval {
        let now = DispatchTime.now().uptimeNanoseconds
        let target = dispatchTime.uptimeNanoseconds
        // `uptimeNanoseconds` is UInt64. If `target` is already in the past,
        // `target - now` would underflow and crash. Clamp safely to 0.
        guard target > now else { return 0 }
        return TimeInterval(target - now) / 1_000_000_000
    }
}

