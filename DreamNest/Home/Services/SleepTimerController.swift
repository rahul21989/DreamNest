import Foundation
import AVFoundation

/// Coordinates countdown + fade out for the currently playing track.
/// - Uses bundled playback only (no streaming).
/// - Fade out is handled on the audio player's volume.
@MainActor
public final class SleepTimerController {
    public struct State: Equatable, Sendable {
        public var isRunning: Bool
        public var remainingSeconds: TimeInterval
        public var totalSeconds: TimeInterval
        public var fadeOutSeconds: TimeInterval
    }

    private let audioPlayerService: AudioPlayerService

    private var timer: DispatchSourceTimer?

    private var endTime: DispatchTime?
    private var remainingWhenPaused: TimeInterval = 0

    private var userPaused = false
    private var interruptionPaused = false
    private var routePaused = false

    private var logic: SleepTimerLogic?
    private var totalSeconds: TimeInterval = 0
    private var fadeOutSeconds: TimeInterval = 0

    private var originalVolume: Float = 1

    public private(set) var state: State = .init(isRunning: false, remainingSeconds: 0, totalSeconds: 0, fadeOutSeconds: 0)

    public var onStateChanged: ((State) -> Void)?
    public var onFinished: (() -> Void)?

    public init(audioPlayerService: AudioPlayerService) {
        self.audioPlayerService = audioPlayerService
        registerForAudioNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Control

    public func start(totalMinutes: Int, fadeOutSeconds: Int, currentVolume: Float) {
        cancel()

        let total = TimeInterval(max(0, totalMinutes)) * 60
        let fade = TimeInterval(max(0, fadeOutSeconds))

        guard total > 0 else { return }

        self.totalSeconds = total
        self.fadeOutSeconds = fade
        self.logic = SleepTimerLogic(totalSeconds: total, fadeOutSeconds: fade)
        self.originalVolume = min(max(currentVolume, 0), 1)
        self.userPaused = false
        self.interruptionPaused = false
        self.routePaused = false

        endTime = .now() + total
        state = .init(isRunning: true, remainingSeconds: total, totalSeconds: total, fadeOutSeconds: fade)
        onStateChanged?(state)

        setVolumeMultiplier(1)

        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: .milliseconds(200))
        t.setEventHandler { [weak self] in
            self?.tick()
        }
        timer = t
        t.resume()
    }

    public func cancel() {
        timer?.cancel()
        timer = nil
        endTime = nil
        logic = nil
        if state.isRunning {
            setVolumeMultiplier(1) // restore
        }
        state = .init(isRunning: false, remainingSeconds: 0, totalSeconds: 0, fadeOutSeconds: 0)
        onStateChanged?(state)
    }

    public func setUserVolume(_ volume: Float) {
        guard state.isRunning else {
            audioPlayerService.setVolume(min(max(volume, 0), 1))
            return
        }
        originalVolume = min(max(volume, 0), 1)
        // Re-apply fade multiplier at the current remaining time.
        let elapsed = totalSeconds - state.remainingSeconds
        let multiplier = logic?.volumeMultiplier(atElapsed: elapsed) ?? 1
        setVolumeMultiplier(multiplier)
    }

    public func pause() {
        guard state.isRunning else { return }
        userPaused = true

        if let endTime {
            let remaining = Self.seconds(from: endTime)
            remainingWhenPaused = max(0, remaining)
        }

        timer?.cancel()
        timer = nil
        endTime = nil
        state.remainingSeconds = remainingWhenPaused
        onStateChanged?(state)
    }

    public func resume() {
        guard state.isRunning else { return }
        guard userPaused else { return }
        userPaused = false

        endTime = .now() + remainingWhenPaused
        timer = DispatchSource.makeTimerSource(queue: .main)
        timer?.schedule(deadline: .now(), repeating: .milliseconds(200))
        timer?.setEventHandler { [weak self] in self?.tick() }
        timer?.resume()
    }

    // MARK: - Audio notification integration

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
        guard let userInfo = notification.userInfo else { return }
        let sessionInterruptionType = (userInfo[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap { AVAudioSession.InterruptionType(rawValue: $0) }

        switch sessionInterruptionType {
        case .some(.began):
            guard state.isRunning else { return }
            if !userPaused {
                interruptionPaused = true
                pauseInternal()
            }
        case .some(.ended):
            let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt
            let option = optionsValue.flatMap { AVAudioSession.InterruptionOptions(rawValue: $0) }
            let shouldResume = option?.contains(.shouldResume) ?? false

            if shouldResume, interruptionPaused, !userPaused {
                interruptionPaused = false
                resumeInternal()
            } else if !shouldResume {
                // Keep paused; user can resume manually.
            }
        default:
            break
        }
    }

    @objc
    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt
        let reason = reasonValue.flatMap { AVAudioSession.RouteChangeReason(rawValue: $0) }

        switch reason {
        case .some(.oldDeviceUnavailable):
            guard state.isRunning else { return }
            if !userPaused {
                routePaused = true
                pauseInternal()
            }
        case .some(.newDeviceAvailable):
            guard state.isRunning else { return }
            if routePaused, !userPaused {
                routePaused = false
                resumeInternal()
            }
        default:
            break
        }
    }

    // MARK: - Tick + volume fading

    private func tick() {
        guard state.isRunning, let endTime else { return }
        let remaining = Self.seconds(from: endTime)

        if remaining <= 0 {
            stopExpired()
            return
        }

        state.remainingSeconds = remaining
        onStateChanged?(state)

        let elapsed = totalSeconds - remaining
        guard let logic else { return }
        let multiplier = logic.volumeMultiplier(atElapsed: elapsed)
        setVolumeMultiplier(multiplier)
    }

    private func stopExpired() {
        timer?.cancel()
        timer = nil
        endTime = nil
        logic = nil

        // Restore volume after fade completes (best effort).
        setVolumeMultiplier(1)

        audioPlayerService.stop(reason: .sleepTimerExpired)
        state = .init(isRunning: false, remainingSeconds: 0, totalSeconds: totalSeconds, fadeOutSeconds: fadeOutSeconds)
        onStateChanged?(state)
        onFinished?()
    }

    private func pauseInternal() {
        guard state.isRunning else { return }
        if let endTime {
            remainingWhenPaused = max(0, Self.seconds(from: endTime))
        }
        timer?.cancel()
        timer = nil
        endTime = nil
        state.remainingSeconds = remainingWhenPaused
        onStateChanged?(state)
    }

    private func resumeInternal() {
        guard state.isRunning else { return }
        endTime = .now() + remainingWhenPaused
        timer = DispatchSource.makeTimerSource(queue: .main)
        timer?.schedule(deadline: .now(), repeating: .milliseconds(200))
        timer?.setEventHandler { [weak self] in self?.tick() }
        timer?.resume()
    }

    private func setVolumeMultiplier(_ multiplier: Double) {
        let vol = originalVolume * Float(min(max(multiplier, 0), 1))
        audioPlayerService.setVolume(vol)
    }

    private static func seconds(from dispatchTime: DispatchTime) -> TimeInterval {
        switch dispatchTime {
        case .now():
            return 0
        default:
            let nanos = dispatchTime.uptimeNanoseconds
            let nowNanos = DispatchTime.now().uptimeNanoseconds
            // `uptimeNanoseconds` is UInt64. If `nanos` is already in the past,
            // `nanos - nowNanos` would underflow and crash. Clamp safely to 0.
            guard nanos > nowNanos else { return 0 }
            return TimeInterval(nanos - nowNanos) / 1_000_000_000
        }
    }
}

