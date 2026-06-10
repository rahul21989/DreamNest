import Foundation

@MainActor
final class CulturalStoryService {

    private let groqURL = URL(string: "https://api.groq.com/openai/v1/chat/completions")!

    private var groqKey: String {
        Bundle.main.object(forInfoDictionaryKey: "GROQ_API_KEY") as? String ?? ""
    }

    // MARK: - Public API

    /// Returns story list for a template; uses cache if available.
    func fetchStories(for template: CulturalTemplate) async throws -> [CulturalStory] {
        if let cached = CulturalStoryCache.shared.loadStories(for: template.id) {
            return cached
        }
        let stories = try await fetchStoryListFromAPI(template: template)
        CulturalStoryCache.shared.saveStories(stories, for: template.id)
        return stories
    }

    /// Returns local audio URL; generates + caches everything on first call.
    func audioURL(for story: CulturalStory, template: CulturalTemplate) async throws -> URL {
        let cache = CulturalStoryCache.shared

        if cache.isAudioCached(for: story.id) {
            return cache.audioURL(for: story.id)
        }

        let storyText = try await generateStoryText(story: story, template: template)
        let wavData    = try await generateTTSAudio(text: storyText)
        try cache.saveAudio(wavData, for: story.id)

        // Persist the download flag
        var updated = story
        updated = CulturalStory(
            id: story.id, templateId: story.templateId,
            title: story.title, summary: story.summary,
            isAudioCached: true,
            audioFileName: "\(story.id.uuidString).wav",
            createdAt: story.createdAt
        )
        cache.updateStory(updated, for: template.id)

        return cache.audioURL(for: story.id)
    }

    // MARK: - Story list

    private func fetchStoryListFromAPI(template: CulturalTemplate) async throws -> [CulturalStory] {
        let prompt = """
        You are a storytelling assistant for Indian children aged 2–8.
        Generate exactly 6 bedtime story titles and one-sentence summaries for the theme: \(template.name).
        Cultural context: \(template.promptContext)

        Rules:
        - Stories must be gentle, wonder-filled, and perfect for drifting off to sleep
        - No violence, no scary elements
        - Each summary is one warm, inviting sentence

        Respond ONLY with a valid JSON array, no markdown, no extra text:
        [
          {"title": "...", "summary": "..."},
          ...
        ]
        """

        let content = try await callGroq(
            systemPrompt: "You are a children's story assistant. Always respond with valid JSON only.",
            userPrompt: prompt,
            maxTokens: 900
        )

        return try parseStoryList(content, templateId: template.id)
    }

    private func parseStoryList(_ text: String, templateId: String) throws -> [CulturalStory] {
        // Extract the JSON array even if the model adds surrounding text
        guard
            let start = text.range(of: "["),
            let end   = text.range(of: "]", options: .backwards)
        else { throw CulturalStoryError.parseError }

        let jsonString = String(text[start.lowerBound...end.lowerBound])
        guard
            let data  = jsonString.data(using: .utf8),
            let items = try? JSONSerialization.jsonObject(with: data) as? [[String: String]]
        else { throw CulturalStoryError.parseError }

        return items.compactMap { item in
            guard let title = item["title"], let summary = item["summary"] else { return nil }
            return CulturalStory(templateId: templateId, title: title, summary: summary)
        }
    }

    // MARK: - Story text

    private func generateStoryText(story: CulturalStory, template: CulturalTemplate) async throws -> String {
        let prompt = """
        You are a warm Indian grandmother telling bedtime stories to children aged 2–8.
        Tell a complete bedtime story titled "\(story.title)".
        One-line description: \(story.summary)
        Theme: \(template.name). \(template.promptContext)

        Rules:
        - 300–400 words — perfect for 2–3 minutes of soft narration
        - Begin with a sense of gentle wonder; gradually slow the pace as the story approaches the end
        - Use simple, warm language a 3-year-old can follow
        - Weave in authentic Indian cultural details naturally (food, nature, festivals)
        - End peacefully: the main character (and the listening child) drifts into a sweet dream
        - No violence, no fear, nothing scary
        - Speak warmly as if sitting beside the child at bedtime

        Tell the story now:
        """

        return try await callGroq(
            systemPrompt: "You are a warm bedtime storyteller for young children.",
            userPrompt: prompt,
            maxTokens: 600
        )
    }

    // MARK: - Gemini TTS — delegate to the proven StoryNarrationService

    private func generateTTSAudio(text: String) async throws -> Data {
        do {
            return try await StoryNarrationService.speak(text: text)
        } catch {
            throw CulturalStoryError.apiError(error.localizedDescription)
        }
    }

    // MARK: - Groq helper

    private func callGroq(systemPrompt: String, userPrompt: String, maxTokens: Int) async throws -> String {
        guard !groqKey.isEmpty else { throw CulturalStoryError.missingKey }

        var request = URLRequest(url: groqURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(groqKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user",   "content": userPrompt]
            ],
            "temperature": 0.75,
            "max_tokens": maxTokens
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            if let errBody = String(data: data, encoding: .utf8) {
                throw CulturalStoryError.apiError(errBody)
            }
            throw CulturalStoryError.apiError("Groq request failed")
        }

        guard
            let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let text    = message["content"] as? String,
            !text.isEmpty
        else { throw CulturalStoryError.emptyResponse }

        return text
    }

}

// MARK: - Error

enum CulturalStoryError: LocalizedError {
    case missingKey
    case apiError(String)
    case parseError
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingKey:        return "API key not found in Info.plist"
        case .apiError(let m):  return m
        case .parseError:       return "Could not read story data"
        case .emptyResponse:    return "No story was returned"
        }
    }
}
