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
        let raw = bundle.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
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
        You are a beloved children's author writing a bedtime story for kids aged 3–8. \
        Your stories are magical, funny, and warm — the kind kids beg to hear again.

        Story details:
        Title: \(title)
        Theme: \(themeLine)
        Preferences: \(prefsLine)
        Parent's idea: \(prompt)

        Rules for a great kids' bedtime story:
        1. CHARACTERS — Give the main character a fun, memorable name (e.g. Luna the bunny, Captain Cosmo, Pip the tiny dragon). Kids connect to named characters instantly.
        2. OPENING — Start with an exciting or funny sentence that pulls kids in straight away. No slow build-ups.
        3. SIMPLE WORDS — Use words a 4-year-old knows. Short sentences. Punchy rhythm.
        4. MAGIC & WONDER — Include one magical or surprising moment (a glowing door, a talking star, a secret map). Kids live for wonder.
        5. GENTLE HUMOR — One or two light funny moments (a silly mistake, a funny sound, an unexpected friend). Kids love to giggle.
        6. REPETITION — Use a short, fun repeated phrase once or twice (e.g. "And off they zoomed!", "Whoooosh!"). Kids adore patterns they can join in with.
        7. EMOTION — The main character should feel something real: excited, a little scared, proud, or loved. Emotional stakes keep kids engaged.
        8. SLEEPY ENDING — End with the character drifting off to sleep, cozy and happy. The ending should make the listening child feel warm, safe, and ready to sleep too.
        9. LENGTH — 5–7 short paragraphs, about 350–450 words total. Not too long — kids' attention spans are precious.
        10. FORMAT — Separate each paragraph with a blank line. No title, no headings, no bullet points — just the story paragraphs.

        Write the story now:
        """
    }
}

