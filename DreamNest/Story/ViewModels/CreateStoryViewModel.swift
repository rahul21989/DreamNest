import Foundation
import Combine
import SwiftUI

@MainActor
final class CreateStoryViewModel: ObservableObject {
    enum GenerationState: Equatable {
        case idle
        case generating
        case success
        case failed(String)
    }

    @Published var title: String = ""
    @Published var theme: String = ""
    @Published var selectedPreferences: Set<StoryPreference> = []
    @Published var prompt: String = ""

    @Published private(set) var generatedStory: String = ""
    @Published private(set) var state: GenerationState = .idle

    @Published private(set) var savedStories: [Story] = []

    /// Fires when the user tries to generate but has hit the daily cap.
    @Published var showLimitAlert: Bool = false

    private let generator: StoryGenerationServing
    private let store: StoryStore

    init(
        generator: StoryGenerationServing = StoryGenerationService(),
        store: StoryStore = StoryStore()
    ) {
        self.generator = generator
        self.store = store
        self.savedStories = store.load()
    }

    var canGenerate: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func generate() async {
        guard canGenerate else { return }

        // Check daily limit before calling the API
        if StoryLimitStore.hasReachedLimit {
            showLimitAlert = true
            return
        }

        state = .generating

        do {
            let prefs = Array(selectedPreferences)
            let storyText = try await generator.generateStory(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                theme: theme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : theme,
                preferences: prefs,
                prompt: prompt
            )
            generatedStory = storyText
            state = .success
            // Only increment AFTER a successful generation
            StoryLimitStore.increment()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func saveCurrentStory() {
        guard !generatedStory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let story = Story(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            theme: theme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : theme,
            preferences: Array(selectedPreferences),
            prompt: prompt,
            generatedText: generatedStory
        )

        var all = savedStories
        all.insert(story, at: 0)
        savedStories = all
        store.save(all)
    }
    
    func deleteSavedStories(at offsets: IndexSet) {
        for offset in offsets.sorted(by: >) {
            savedStories.remove(at: offset)
        }
        store.save(savedStories)
    }
}

