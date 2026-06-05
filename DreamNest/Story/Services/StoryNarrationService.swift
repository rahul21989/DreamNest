import Foundation

/// Calls Gemini 2.0 Flash TTS to generate human-quality speech.
/// Uses the same GEMINI_API_KEY already in Info.plist — no extra key needed.
///
/// Voice: "Aoede" — warm, bright female, ideal for bedtime storytelling.
/// The API returns raw L16 PCM audio; we wrap it in a WAV header so AVAudioPlayer can play it.
enum StoryNarrationService {

    enum NarrationError: LocalizedError {
        case missingAPIKey
        case serverError(Int, String)
        case noAudioInResponse
        case base64DecodingFailed

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Gemini API key not found. Check GEMINI_API_KEY in Info.plist."
            case .serverError(let code, let msg):
                return "Narration server error (\(code)): \(msg)"
            case .noAudioInResponse:
                return "Gemini returned no audio. The TTS model may not be available on this API key."
            case .base64DecodingFailed:
                return "Could not decode audio data from Gemini."
            }
        }
    }

    // Gemini 2.0 Flash — supports responseModalities: AUDIO
    private static let model = "gemini-2.0-flash-exp"

    // MARK: - Public

    /// Returns a WAV `Data` object ready for `AVAudioPlayer`.
    static func speak(text: String) async throws -> Data {
        guard
            let apiKey = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String,
            !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { throw NarrationError.missingAPIKey }

        let urlStr = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlStr) else { throw NarrationError.missingAPIKey }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Gemini TTS request body
        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": text]]]
            ],
            "generationConfig": [
                "responseModalities": ["AUDIO"],
                "speechConfig": [
                    "voiceConfig": [
                        "prebuiltVoiceConfig": [
                            "voiceName": "Aoede"   // Warm female voice, great for storytelling
                        ]
                    ]
                ]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NarrationError.serverError(http.statusCode, msg)
        }

        return try extractWAV(from: data)
    }

    // MARK: - Parse response → WAV

    private static func extractWAV(from responseData: Data) throws -> Data {
        guard
            let json       = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let first      = candidates.first,
            let content    = first["content"] as? [String: Any],
            let parts      = content["parts"] as? [[String: Any]],
            let part       = parts.first,
            let inline     = part["inlineData"] as? [String: Any],
            let b64        = inline["data"] as? String
        else { throw NarrationError.noAudioInResponse }

        guard let pcm = Data(base64Encoded: b64)
        else { throw NarrationError.base64DecodingFailed }

        // Gemini returns L16 PCM at 24 000 Hz, mono, 16-bit signed little-endian
        return buildWAV(from: pcm, sampleRate: 24_000, channels: 1, bitsPerSample: 16)
    }

    // MARK: - PCM → WAV

    /// Wraps raw signed-16-bit PCM in a standard RIFF/WAV container
    /// so AVAudioPlayer can handle it without any extra dependencies.
    private static func buildWAV(from pcm: Data,
                                  sampleRate: Int,
                                  channels: Int,
                                  bitsPerSample: Int) -> Data {
        let byteRate   = sampleRate * channels * bitsPerSample / 8
        let blockAlign = channels * bitsPerSample / 8
        let dataSize   = UInt32(pcm.count)

        var wav = Data()
        wav.reserveCapacity(44 + pcm.count)

        // Helper closures
        func str(_ s: String)    { wav.append(contentsOf: s.utf8) }
        func u32(_ v: UInt32)    { var x = v.littleEndian;  wav.append(contentsOf: withUnsafeBytes(of: &x, Array.init)) }
        func u16(_ v: UInt16)    { var x = v.littleEndian;  wav.append(contentsOf: withUnsafeBytes(of: &x, Array.init)) }

        // RIFF chunk
        str("RIFF")
        u32(dataSize + 36)       // total file size − 8 bytes
        str("WAVE")

        // fmt sub-chunk
        str("fmt ")
        u32(16)                                  // PCM sub-chunk size
        u16(1)                                   // AudioFormat = PCM
        u16(UInt16(channels))
        u32(UInt32(sampleRate))
        u32(UInt32(byteRate))
        u16(UInt16(blockAlign))
        u16(UInt16(bitsPerSample))

        // data sub-chunk
        str("data")
        u32(dataSize)
        wav.append(pcm)

        return wav
    }
}
