import Foundation
import Combine

@MainActor
final class CulturalStoryListViewModel: ObservableObject {
    @Published var stories: [CulturalStory] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    let template: CulturalTemplate
    private let service = CulturalStoryService()

    init(template: CulturalTemplate) {
        self.template = template
    }

    func loadStories() async {
        guard stories.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            stories = try await service.fetchStories(for: template)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func retry() async {
        stories = []
        await loadStories()
    }
}
