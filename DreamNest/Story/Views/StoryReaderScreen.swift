import SwiftUI
import AVFoundation
import Combine

@MainActor
private final class StorySpeechController: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    
    @Published private(set) var isSpeaking = false
    @Published private(set) var isPaused = false

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func toggle(text: String) {
        if isSpeaking {
            if isPaused {
                synthesizer.continueSpeaking()
                isPaused = false
            } else {
                synthesizer.pauseSpeaking(at: .word)
                isPaused = true
            }
            return
        }

        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }

        let utterance = AVSpeechUtterance(string: cleanText)
        utterance.rate = 0.25 // slower bedtime pacing
        utterance.pitchMultiplier = 1 // slightly softer/feminine tone
        utterance.voice = preferredSoftFemaleVoice()
        utterance.preUtteranceDelay = 0.03
        utterance.postUtteranceDelay = 0.22

        synthesizer.speak(utterance)
        isSpeaking = true
        isPaused = false
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        isPaused = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
        isPaused = false
    }

    private func preferredSoftFemaleVoice() -> AVSpeechSynthesisVoice? {
        // Prefer common feminine English voices if available on device.
        let all = AVSpeechSynthesisVoice.speechVoices()
        let preferredNames = ["Karen", "Moira", "Ava", "Serena"]

        if let named = all.first(where: { voice in
            preferredNames.contains(where: { name in voice.name.localizedCaseInsensitiveContains(name) }) &&
            voice.language.hasPrefix("en")
        }) {
            return named
        }

        // Fallback to any English voice, then default language voice.
        if let anyEnglish = all.first(where: { $0.language.hasPrefix("en") }) {
            return anyEnglish
        }
        return AVSpeechSynthesisVoice(language: "en-US")
    }
}

/// Full-screen story reader with soft SF Symbol “illustrations” (no image assets).
struct StoryReaderScreen: View {
    let title: String
    let theme: String?
    let preferences: [StoryPreference]
    let bodyText: String
    var showSaveButton: Bool
    var onSave: (() -> Void)?

    @State private var didSave = false
    @StateObject private var speech = StorySpeechController()

    init(story: Story) {
        self.title = story.title
        self.theme = story.theme
        self.preferences = story.preferences
        self.bodyText = story.generatedText
        self.showSaveButton = false
        self.onSave = nil
    }

    init(
        viewModel: CreateStoryViewModel,
        showSaveButton: Bool = true,
        onSave: (() -> Void)? = nil
    ) {
        self.title = viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTheme = viewModel.theme.trimmingCharacters(in: .whitespacesAndNewlines)
        self.theme = trimmedTheme.isEmpty ? nil : trimmedTheme
        self.preferences = Array(viewModel.selectedPreferences)
        self.bodyText = viewModel.generatedStory
        self.showSaveButton = showSaveButton
        self.onSave = onSave
    }

    private var visual: StoryVisualTheme {
        StoryVisualTheme(preferences: preferences, theme: theme ?? title)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                paragraphBlocks
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .navigationTitle("Story")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    speech.toggle(text: bodyText)
                } label: {
                    Label(
                        speech.isSpeaking && !speech.isPaused ? "Pause" : (speech.isPaused ? "Resume" : "Play"),
                        systemImage: speech.isSpeaking && !speech.isPaused ? "pause.circle.fill" : "play.circle.fill"
                    )
                }
                .disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if showSaveButton {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSave?()
                        didSave = true
                    } label: {
                        Label(
                            didSave ? "Saved" : "Save offline",
                            systemImage: didSave ? "checkmark.circle.fill" : "arrow.down.circle"
                        )
                    }
                    .disabled(didSave)
                }
            }
        }
        .onDisappear {
            speech.stop()
        }
        .dreamNestNightMode()
    }

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(visual.headerGradient.opacity(0.38))
                    .frame(height: 118)
                Image(systemName: visual.systemName)
                    .font(.system(size: 46))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.primary.opacity(0.92))
            }

            Text(title)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            if let theme, !theme.isEmpty {
                Text(theme)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var paragraphBlocks: some View {
        let parts = storyParagraphs(bodyText)
        let icons = visual.symbolsForParagraphs(parts.count)

        return VStack(alignment: .leading, spacing: 14) {
            if parts.isEmpty {
                Text("No story text yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(parts.enumerated()), id: \.offset) { index, paragraph in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: icons[index])
                            .font(.title3)
                            .foregroundStyle(Color.accentColor.opacity(0.75))
                            .frame(width: 30, alignment: .center)
                        Text(paragraph)
                            .font(.body)
                            .lineSpacing(5)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
                }
            }
        }
    }
}
