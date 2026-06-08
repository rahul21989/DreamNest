import Foundation

// MARK: - Groq request / response models (OpenAI-compatible format)

private struct GroqRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }
    let model: String
    let messages: [Message]
    let max_tokens: Int
    let temperature: Double
}

private struct GroqResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }
        let message: Message?
    }
    struct GroqError: Decodable {
        struct Detail: Decodable { let message: String? }
        let error: Detail?
    }
    let choices: [Choice]?
}

// MARK: - Protocol

protocol StoryGenerationServing {
    func generateStory(
        title: String,
        theme: String?,
        preferences: [StoryPreference],
        prompt: String
    ) async throws -> String
}

// MARK: - Service
//
// Uses the Groq API — completely free tier, no credit card needed.
// Free limits: 14,400 requests/day, 30 requests/minute.
// Sign up at https://console.groq.com to get your API key.
//
// Add GROQ_API_KEY to Info.plist (same way GEMINI_API_KEY is stored).

final class StoryGenerationService: StoryGenerationServing {

    private static let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!

    // Best free model for kids' story quality + speed
    private static let model = "llama-3.3-70b-versatile"

    init() {}

    func generateStory(
        title: String,
        theme: String?,
        preferences: [StoryPreference],
        prompt: String
    ) async throws -> String {

        guard let apiKey = Self.apiKey() else {
            throw StoryError.missingKey
        }

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json",    forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)",    forHTTPHeaderField: "Authorization")

        let body = GroqRequest(
            model: Self.model,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user",   content: Self.userPrompt(
                    title: title, theme: theme,
                    preferences: preferences, prompt: prompt
                ))
            ],
            max_tokens: 900,
            temperature: 0.85
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            // Extract Groq's human-readable error message
            let detail = (try? JSONDecoder().decode(GroqResponse.GroqError.self, from: data))?.error?.message
            throw StoryError.apiError(http.statusCode, detail ?? "Unknown error")
        }

        let decoded = try JSONDecoder().decode(GroqResponse.self, from: data)
        let text = decoded.choices?.first?.message?.content?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let text, !text.isEmpty else {
            throw StoryError.emptyResponse
        }
        return text
    }

    // MARK: - Key lookup (Info.plist)

    private static func apiKey(bundle: Bundle = .main) -> String? {
        let raw = bundle.object(forInfoDictionaryKey: "GROQ_API_KEY") as? String
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }

    // MARK: - Prompts

    private let systemPrompt = """
    You are a beloved children's author who writes magical, cosy bedtime stories for kids aged 3–8. \
    Your stories are warm, funny, and gentle — the kind children beg to hear again. \
    Always write in short, simple sentences a 4-year-old can follow. \
    Never include violence, scary elements, or adult themes. \
    Output only the story paragraphs — no title line, no headings, no bullet points.
    """

    private static func userPrompt(
        title: String,
        theme: String?,
        preferences: [StoryPreference],
        prompt: String
    ) -> String {
        let prefs     = preferences.map(\.displayName)
        let prefsLine = prefs.isEmpty ? "None" : prefs.joined(separator: ", ")
        let themeLine = theme?.trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false ? theme! : "None"

        return """
        Write a bedtime story with these details:

        Title: \(title)
        Theme: \(themeLine)
        World / preferences: \(prefsLine)
        Parent's idea: \(prompt)

        Story rules:
        1. Give the hero a fun name (e.g. Luna the bunny, Captain Cosmo).
        2. Open with one exciting or funny sentence — no slow warm-ups.
        3. Include one magical or surprising moment kids will love.
        4. Add one or two gentle funny moments.
        5. Use a short repeated phrase once or twice (e.g. "And off they zoomed!").
        6. End with the hero drifting off to sleep, cosy and happy.
        7. 5–7 short paragraphs, ~350–450 words total.
        8. Separate paragraphs with a blank line. No title or headings in the output.

        Write the story now:
        """
    }
}

// MARK: - Errors

enum StoryError: LocalizedError {
    case missingKey
    case apiError(Int, String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "Story generation is not set up. Add your GROQ_API_KEY to Info.plist."
        case .apiError(let code, let msg):
            return "Story generation failed (\(code)): \(msg)"
        case .emptyResponse:
            return "No story was returned. Please try again."
        }
    }
}
