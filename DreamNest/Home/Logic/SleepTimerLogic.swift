import Foundation

/// Pure logic for the sleep timer.
/// - Fade out is linear during the last `fadeOutSeconds`.
public struct SleepTimerLogic: Sendable {
    public let totalSeconds: TimeInterval
    public let fadeOutSeconds: TimeInterval

    public init(totalSeconds: TimeInterval, fadeOutSeconds: TimeInterval) {
        self.totalSeconds = max(0, totalSeconds)
        self.fadeOutSeconds = max(0, fadeOutSeconds)
    }

    public enum Phase: Equatable {
        case playing
        case fading(progress: Double) // 0...1
        case finished
    }

    public func phase(atElapsed elapsedSeconds: TimeInterval) -> Phase {
        guard elapsedSeconds < totalSeconds else { return .finished }
        guard fadeOutSeconds > 0 else { return .playing }

        let fadeStart = max(totalSeconds - fadeOutSeconds, 0)
        guard elapsedSeconds >= fadeStart else { return .playing }

        // Duration may shrink if fadeOutSeconds > totalSeconds.
        let effectiveFadeDuration = max(totalSeconds - fadeStart, 0.000_001)
        let fadeElapsed = elapsedSeconds - fadeStart
        let progress = min(max(fadeElapsed / effectiveFadeDuration, 0), 1)
        return .fading(progress: progress)
    }

    /// 1.0 during normal playback, then linearly down to 0 during fade.
    public func volumeMultiplier(atElapsed elapsedSeconds: TimeInterval) -> Double {
        switch phase(atElapsed: elapsedSeconds) {
        case .playing:
            return 1
        case .fading(let progress):
            return max(0, 1 - progress)
        case .finished:
            return 0
        }
    }

    public func isFinished(atElapsed elapsedSeconds: TimeInterval) -> Bool {
        elapsedSeconds >= totalSeconds
    }
}

