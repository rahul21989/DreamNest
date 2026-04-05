import Foundation

public struct RoutineStepPlan: Equatable, Sendable {
    public let trackID: String
    public let durationSeconds: TimeInterval

    public init(trackID: String, durationSeconds: TimeInterval) {
        self.trackID = trackID
        self.durationSeconds = max(0, durationSeconds)
    }
}

/// Pure sequencing logic: given step durations, map elapsed time to the active step.
public struct RoutineSequencer: Sendable {
    public let steps: [RoutineStepPlan]

    public init(steps: [RoutineStepPlan]) {
        self.steps = steps
    }

    public enum State: Equatable {
        case step(index: Int)
        case finished
    }

    public func state(atElapsed elapsedSeconds: TimeInterval) -> State {
        guard !steps.isEmpty else { return .finished }
        var remaining = max(0, elapsedSeconds)

        for (idx, step) in steps.enumerated() {
            // Steps with non-positive durations should not block sequencing.
            if step.durationSeconds <= 0 {
                continue
            }

            if remaining < step.durationSeconds {
                return .step(index: idx)
            }
            remaining -= step.durationSeconds
        }

        return .finished
    }
}

