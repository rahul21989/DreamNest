import Foundation
import AVFoundation

import UIKit

/// Wraps local (bundled) audio playback and keeps it running in background.
/// Uses `AVAudioPlayer` so we can easily seek and track progress.
public final class AudioPlayerService: NSObject, AVAudioPlayerDelegate {
    public enum FinishReason: Equatable {
        case natural
        case userStopped
        case routineStepCompleted
        case sleepTimerExpired
    }

    public enum PlaybackMode {
        case idle
        case playing
        case paused
    }

    public typealias FinishObserver = (FinishReason) -> Void

    private var audioPlayer: AVAudioPlayer?
    private var nextFinishReason: FinishReason?

    private var finishObservers: [UUID: FinishObserver] = [:]
    private var isConfiguredSession = false

    private var shouldResumeAfterInterruption = false
    private var shouldResumeAfterRouteReturn = false

    public var onPlaybackModeChanged: ((PlaybackMode) -> Void)?

    public override init() {
        super.init()
        configureAudioSession()
        registerForAudioNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public API

    public func loadTrackURL(_ url: URL) throws {
        let player = try AVAudioPlayer(contentsOf: url)
        player.delegate = self
        player.prepareToPlay()
        self.audioPlayer = player
        emitPlaybackModeChanged()
    }

    public func play() {
        guard let audioPlayer else { return }
        audioPlayer.play()
        emitPlaybackModeChanged()
    }

    public func pause() {
        guard let audioPlayer, audioPlayer.isPlaying else { return }
        audioPlayer.pause()
        emitPlaybackModeChanged()
    }

    public func stop(reason: FinishReason) {
        guard let audioPlayer else { return }
        nextFinishReason = reason
        audioPlayer.stop()
        emitPlaybackModeChanged()
    }

    public func setVolume(_ volume: Float) {
        audioPlayer?.volume = min(max(volume, 0), 1)
    }

    public func setCurrentTime(_ seconds: TimeInterval) {
        guard let audioPlayer else { return }
        let clamped = min(max(0, seconds), audioPlayer.duration.isFinite ? audioPlayer.duration : seconds)
        audioPlayer.currentTime = clamped
        emitPlaybackModeChanged()
    }

    public var durationSeconds: TimeInterval? {
        audioPlayer?.duration
    }

    public var currentTimeSeconds: TimeInterval? {
        audioPlayer?.currentTime
    }

    public var isPlaying: Bool {
        audioPlayer?.isPlaying ?? false
    }

    public func addFinishObserver(_ observer: @escaping FinishObserver) -> UUID {
        let token = UUID()
        finishObservers[token] = observer
        return token
    }

    public func removeFinishObserver(_ token: UUID) {
        finishObservers.removeValue(forKey: token)
    }

    // MARK: - AVAudioPlayerDelegate

    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let reason = nextFinishReason ?? .natural
        nextFinishReason = nil
        for (_, observer) in finishObservers {
            observer(reason)
        }
        emitPlaybackModeChanged()
    }

    // MARK: - Audio session / interruptions / route changes

    private func configureAudioSession() {
        guard !isConfiguredSession else { return }
        isConfiguredSession = true

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.allowBluetooth, .allowAirPlay]
            )
            try session.setActive(true)
        } catch {
            // If configuration fails, app still functions in foreground; ignore here.
        }
    }

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

        let session = AVAudioSession.sharedInstance()
        let isCurrentlyPlaying = isPlaying
        if let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt {
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
            switch type {
            case .some(.began):
                shouldResumeAfterInterruption = isCurrentlyPlaying
                if isCurrentlyPlaying {
                    pause()
                }
            case .some(.ended):
                // The interruption ended; only resume if the system says we should.
                let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt
                let option = optionsValue.flatMap { AVAudioSession.InterruptionOptions(rawValue: $0) }
                let shouldResume = option?.contains(.shouldResume) ?? false
                if shouldResume, shouldResumeAfterInterruption {
                    play()
                }
                shouldResumeAfterInterruption = false
            default:
                break
            }
        }
    }

    @objc
    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt
        let reason = reasonValue.flatMap { AVAudioSession.RouteChangeReason(rawValue: $0) }

        switch reason {
        case .some(.oldDeviceUnavailable):
            shouldResumeAfterRouteReturn = isPlaying
            pause()
        case .some(.newDeviceAvailable):
            if shouldResumeAfterRouteReturn {
                play()
            }
            shouldResumeAfterRouteReturn = false
        default:
            break
        }
    }

    private func emitPlaybackModeChanged() {
        let mode: PlaybackMode
        if audioPlayer?.isPlaying == true {
            mode = .playing
        } else if let audioPlayer, audioPlayer.currentTime > 0 {
            mode = .paused
        } else {
            mode = .idle
        }
        onPlaybackModeChanged?(mode)
    }
}

