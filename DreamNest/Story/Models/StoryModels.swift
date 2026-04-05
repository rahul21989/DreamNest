import Foundation

public enum StoryPreference: String, CaseIterable, Codable, Identifiable, Sendable {
    case superheroes
    case adventures
    case castle
    case animals
    case space
    case ocean
    case custom

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .superheroes: return "Superheroes"
        case .adventures: return "Adventures"
        case .castle: return "Castle"
        case .animals: return "Animals"
        case .space: return "Space"
        case .ocean: return "Ocean"
        case .custom: return "Custom"
        }
    }
}

public struct Story: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var theme: String?
    public var preferences: [StoryPreference]
    public var prompt: String
    public var generatedText: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        theme: String? = nil,
        preferences: [StoryPreference],
        prompt: String,
        generatedText: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.theme = theme
        self.preferences = preferences
        self.prompt = prompt
        self.generatedText = generatedText
        self.createdAt = createdAt
    }
}

