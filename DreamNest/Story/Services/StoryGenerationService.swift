import Foundation

private struct GeminiGenerateContentRequest: Encodable {
    struct Content: Encodable {
        struct Part: Encodable {
            let text: String
        }
        let parts: [Part]
    }
    let contents: [Content]
}

private struct GeminiGenerateContentResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String?
            }
            let parts: [Part]?
        }
        let content: Content?
    }
    let candidates: [Candidate]?
}

protocol StoryGenerationServing {
    func generateStory(
        title: String,
        theme: String?,
        preferences: [StoryPreference],
        prompt: String
    ) async throws -> String
}

/// Gemini API client.
/// Reads the API key from `Info.plist` key `GEMINI_API_KEY` (recommended to inject via build settings).
final class StoryGenerationService: StoryGenerationServing {
    private static let endpointURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent")!

    init() {}

    func generateStory(
        title: String,
        theme: String?,
        preferences: [StoryPreference],
        prompt: String
    ) async throws -> String {
        guard let apiKey = Self.geminiAPIKey() else {
            throw NSError(
                domain: "DreamNest.StoryGenerationService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing GEMINI_API_KEY. Add it to Info.plist (inject via build settings) before generating stories."]
            )
        }

        var request = URLRequest(url: Self.endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let composedText = Self.composePrompt(
            title: title,
            theme: theme,
            preferences: preferences,
            prompt: prompt
        )

        let body = GeminiGenerateContentRequest(
            contents: [
                .init(parts: [.init(text: composedText)])
            ]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(GeminiGenerateContentResponse.self, from: data)
        let text = decoded.candidates?.first?.content?.parts?.compactMap(\.text).joined(separator: "\n")
        if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        throw URLError(.cannotDecodeContentData)
    }

    private static func geminiAPIKey(bundle: Bundle = .main) -> String? {
        return "AIzaSyAexYdu8KLTeaY_V8OQLxMuJsq6VY4iOAE"
//        let raw = bundle.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String
//        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
//        guard let trimmed, !trimmed.isEmpty else { return nil }
//        return trimmed
    }

    private static func composePrompt(
        title: String,
        theme: String?,
        preferences: [StoryPreference],
        prompt: String
    ) -> String {
        let prefs = preferences.map(\.displayName)
        let prefsLine = prefs.isEmpty ? "None" : prefs.joined(separator: ", ")
        let themeLine = (theme?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "None"

        return """
        Write a simple, calming bedtime story for young kids (roughly ages 3–8).

        Title: \(title)
        Theme: \(themeLine)
        Preferences: \(prefsLine)
        Parent prompt: \(prompt)

        Style:
        - Very gentle, cozy, happy and positive
        - Short sentences, easy words
        - About 300–400 words total
        - Use vivid but soft imagery (nature, friends, cozy places)
        - Format: several short paragraphs separated by a blank line (double newline). No title line or headings in the output—just the story paragraphs.
        """
    }
}

