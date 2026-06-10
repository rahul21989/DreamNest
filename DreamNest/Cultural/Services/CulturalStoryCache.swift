import Foundation

final class CulturalStoryCache: @unchecked Sendable {

    static let shared = CulturalStoryCache()

    private let fileManager = FileManager.default

    // MARK: - Directory URLs

    private var cacheDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("cultural_stories", isDirectory: true)
    }

    private var audioDirectory: URL {
        cacheDirectory.appendingPathComponent("audio", isDirectory: true)
    }

    private init() {
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Story list

    func saveStories(_ stories: [CulturalStory], for templateId: String) {
        let url = cacheDirectory.appendingPathComponent("\(templateId)_stories.json")
        guard let data = try? JSONEncoder().encode(stories) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func loadStories(for templateId: String) -> [CulturalStory]? {
        let url = cacheDirectory.appendingPathComponent("\(templateId)_stories.json")
        guard
            let data = try? Data(contentsOf: url),
            let stories = try? JSONDecoder().decode([CulturalStory].self, from: data)
        else { return nil }
        return stories
    }

    /// Persist a single story update (e.g. after audio is cached).
    func updateStory(_ story: CulturalStory, for templateId: String) {
        guard var stories = loadStories(for: templateId) else { return }
        if let idx = stories.firstIndex(where: { $0.id == story.id }) {
            stories[idx] = story
            saveStories(stories, for: templateId)
        }
    }

    // MARK: - Audio files

    func audioURL(for storyId: UUID) -> URL {
        audioDirectory.appendingPathComponent("\(storyId.uuidString).wav")
    }

    func saveAudio(_ data: Data, for storyId: UUID) throws {
        try data.write(to: audioURL(for: storyId), options: .atomic)
    }

    func isAudioCached(for storyId: UUID) -> Bool {
        fileManager.fileExists(atPath: audioURL(for: storyId).path)
    }
}
