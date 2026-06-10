import Foundation

struct CulturalStory: Identifiable, Codable, Equatable {
    let id: UUID
    let templateId: String
    let title: String
    let summary: String
    var isAudioCached: Bool
    var audioFileName: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        templateId: String,
        title: String,
        summary: String,
        isAudioCached: Bool = false,
        audioFileName: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.templateId = templateId
        self.title = title
        self.summary = summary
        self.isAudioCached = isAudioCached
        self.audioFileName = audioFileName
        self.createdAt = createdAt
    }
}
