import Foundation

final class StoryStore: @unchecked Sendable {
    private enum Keys {
        static let stories = "dn_stories_v1"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults.standard) {
        self.defaults = defaults
    }

    func load() -> [Story] {
        guard let data = defaults.data(forKey: Keys.stories) else { return [] }
        return (try? JSONDecoder().decode([Story].self, from: data)) ?? []
    }

    func save(_ stories: [Story]) {
        guard let data = try? JSONEncoder().encode(stories) else { return }
        defaults.set(data, forKey: Keys.stories)
    }
}

