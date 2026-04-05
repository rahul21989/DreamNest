import Foundation

public struct RoutineStep: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var trackFilename: String // mp3 filename in the app bundle (e.g. "Lullabies__Twinkle.mp3")
    public var durationSeconds: TimeInterval

    public init(id: UUID = UUID(), trackFilename: String, durationSeconds: TimeInterval) {
        self.id = id
        self.trackFilename = trackFilename
        self.durationSeconds = max(0, durationSeconds)
    }
}

public struct Routine: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var steps: [RoutineStep]
    public var updatedAt: Date

    public init(id: UUID = UUID(), name: String, steps: [RoutineStep], updatedAt: Date = .now) {
        self.id = id
        self.name = name
        self.steps = steps
        self.updatedAt = updatedAt
    }
}

public struct ParentsSettings: Codable, Hashable, Sendable {
    public var defaultSleepTimerMinutes: Int
    public var fadeOutSeconds: Int

    public init(defaultSleepTimerMinutes: Int = 10, fadeOutSeconds: Int = 20) {
        self.defaultSleepTimerMinutes = defaultSleepTimerMinutes
        self.fadeOutSeconds = fadeOutSeconds
    }
}

