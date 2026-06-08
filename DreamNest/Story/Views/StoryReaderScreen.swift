import SwiftUI
import AVFoundation
import Combine

// MARK: - Speech Controller

@MainActor
private final class StorySpeechController: NSObject, ObservableObject {

    enum State: Equatable {
        case idle
        case loading           // fetching audio from OpenAI
        case playing
        case paused
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    // AVAudioPlayer for OpenAI TTS audio
    private var audioPlayer: AVAudioPlayer?
    // Cached audio URL so re-play doesn't re-fetch
    private var cachedAudioURL: URL?

    // AVSpeechSynthesizer — fallback when no OpenAI key
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Public interface

    func toggle(text: String) {
        switch state {
        case .playing:
            pausePlayback()
        case .paused:
            resumePlayback()
        case .idle, .failed:
            Task { await startPlayback(text: text) }
        case .loading:
            break // tap ignored while loading
        }
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        synthesizer.stopSpeaking(at: .immediate)
        state = .idle
    }

    // MARK: - Playback control

    private func pausePlayback() {
        if audioPlayer != nil {
            audioPlayer?.pause()
        } else {
            synthesizer.pauseSpeaking(at: .word)
        }
        state = .paused
    }

    private func resumePlayback() {
        if audioPlayer != nil {
            audioPlayer?.play()
        } else {
            synthesizer.continueSpeaking()
        }
        state = .playing
    }

    // MARK: - Start: try OpenAI, fall back to AVSpeechSynthesizer

    private func startPlayback(text: String) async {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }

        // --- Try OpenAI TTS first ---
        let hasGeminiKey: Bool = {
            guard let key = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String
            else { return false }
            return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }()

        if hasGeminiKey {
            await playWithOpenAI(text: cleanText)   // function reused — now calls Gemini internally
        } else {
            playWithSynthesizer(text: cleanText)
        }
    }

    // MARK: - OpenAI path

    private func playWithOpenAI(text: String) async {
        // Serve from cache if available
        if let url = cachedAudioURL, FileManager.default.fileExists(atPath: url.path) {
            startAudioPlayer(from: url)
            return
        }

        state = .loading

        do {
            let data = try await StoryNarrationService.speak(text: text)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("dn_narration_\(UUID().uuidString).mp3")
            try data.write(to: url)

            // Clean up previous cache file
            if let old = cachedAudioURL { try? FileManager.default.removeItem(at: old) }
            cachedAudioURL = url

            startAudioPlayer(from: url)
        } catch {
            // On any OpenAI failure, fall back to synthesizer silently
            playWithSynthesizer(text: text)
        }
    }

    private func startAudioPlayer(from url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback, mode: .default,
                options: [.allowBluetoothA2DP, .allowAirPlay]
            )
            try AVAudioSession.sharedInstance().setActive(true)

            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            player.play()
            audioPlayer = player
            state = .playing
        } catch {
            playWithSynthesizer(text: try! String(contentsOf: url, encoding: .utf8))
        }
    }

    // MARK: - AVSpeechSynthesizer fallback

    private func playWithSynthesizer(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate            = 0.42
        utterance.pitchMultiplier = 1.12
        utterance.volume          = 0.95
        utterance.voice           = bestFemaleVoice()
        utterance.preUtteranceDelay  = 0.05
        utterance.postUtteranceDelay = 0.3
        synthesizer.speak(utterance)
        state = .playing
    }

    private func bestFemaleVoice() -> AVSpeechSynthesisVoice? {
        let english     = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
        let femaleNames = ["Ava", "Zoe", "Samantha", "Nova", "Serena", "Karen", "Moira"]

        for quality in [AVSpeechSynthesisVoiceQuality.premium, .enhanced] {
            for name in femaleNames {
                if let v = english.first(where: { $0.quality == quality &&
                    $0.name.localizedCaseInsensitiveContains(name) }) { return v }
            }
            if let v = english.first(where: { $0.quality == quality }) { return v }
        }
        for name in femaleNames {
            if let v = english.first(where: { $0.name.localizedCaseInsensitiveContains(name) }) { return v }
        }
        return english.first ?? AVSpeechSynthesisVoice(language: "en-US")
    }
}

// MARK: - AVAudioPlayerDelegate

extension StorySpeechController: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully _: Bool) {
        Task { @MainActor in self.state = .idle }
    }
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in self.state = .idle }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension StorySpeechController: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish _: AVSpeechUtterance) {
        Task { @MainActor in self.state = .idle }
    }
}

// MARK: - Story Reader Screen

struct StoryReaderScreen: View {
    let title: String
    let theme: String?
    let preferences: [StoryPreference]
    let bodyText: String
    var showSaveButton: Bool
    var onSave: (() -> Void)?

    @State  private var didSave = false
    @StateObject private var speech = StorySpeechController()

    init(story: Story) {
        self.title       = story.title
        self.theme       = story.theme
        self.preferences = story.preferences
        self.bodyText    = story.generatedText
        self.showSaveButton = false
        self.onSave      = nil
    }

    init(viewModel: CreateStoryViewModel, showSaveButton: Bool = true, onSave: (() -> Void)? = nil) {
        self.title       = viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let t            = viewModel.theme.trimmingCharacters(in: .whitespacesAndNewlines)
        self.theme       = t.isEmpty ? nil : t
        self.preferences = Array(viewModel.selectedPreferences)
        self.bodyText    = viewModel.generatedStory
        self.showSaveButton = showSaveButton
        self.onSave      = onSave
    }

    private var visual: StoryVisualTheme {
        StoryVisualTheme(preferences: preferences, theme: theme ?? title)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                storyHero
                VStack(spacing: 16) {
                    narrationCard
                    paragraphSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarItems }
        .onDisappear { speech.stop() }
        .dreamNestNightMode()
    }

    // MARK: - Toolbar (back + save)

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        if showSaveButton {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    onSave?()
                    didSave = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: didSave ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                        Text(didSave ? "Saved" : "Save")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(didSave ? Color.green : Color.white)
                }
                .disabled(didSave)
            }
        }
    }

    // MARK: - Hero header (matches Create Story design)

    private var storyHero: some View {
        ZStack(alignment: .bottom) {
            // Themed gradient — uses the story's visual colours
            LinearGradient(
                colors: visual.colors + [Color.indigo.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Decorative large background icon
            Image(systemName: visual.systemName)
                .font(.system(size: 120))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white.opacity(0.08))
                .offset(x: 80, y: -10)

            // Content
            VStack(spacing: 12) {
                // Icon badge
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 72, height: 72)
                    Image(systemName: visual.systemName)
                        .font(.system(size: 34))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)
                }

                // Title
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Theme + preference chips
                if !preferenceChips.isEmpty || (theme != nil && !theme!.isEmpty) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if let theme, !theme.isEmpty {
                                chip(theme, icon: "sparkles")
                            }
                            ForEach(preferences, id: \.id) { pref in
                                chip(pref.displayName, icon: nil)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                // Play / Pause / Loading button
                listenButton
                    .padding(.bottom, 24)
            }
            .padding(.top, 80)   // clear navigation bar area
        }
        .frame(maxWidth: .infinity)
    }

    // Small chip label
    private func chip(_ text: String, icon: String?) -> some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.caption2) }
            Text(text).font(.caption.weight(.medium))
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.white.opacity(0.18))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
    }

    private var preferenceChips: [StoryPreference] { preferences }

    // MARK: - Listen button (in hero)

    private var listenButton: some View {
        Button {
            speech.toggle(text: bodyText)
        } label: {
            HStack(spacing: 10) {
                switch speech.state {
                case .loading:
                    ProgressView().progressViewStyle(.circular).tint(.white).scaleEffect(0.85)
                    Text("Preparing narration…")
                        .font(.subheadline.weight(.semibold))
                case .playing:
                    Image(systemName: "pause.fill")
                        .font(.subheadline.weight(.bold))
                    Text("Pause Story")
                        .font(.subheadline.weight(.semibold))
                case .paused:
                    Image(systemName: "play.fill")
                        .font(.subheadline.weight(.bold))
                    Text("Resume Story")
                        .font(.subheadline.weight(.semibold))
                default:
                    Image(systemName: "play.fill")
                        .font(.subheadline.weight(.bold))
                    Text("Listen to Story")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 13)
            .background(.white.opacity(0.22))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  || speech.state == .loading)
    }

    // MARK: - Narration status card

    @ViewBuilder
    private var narrationCard: some View {
        switch speech.state {
        case .loading:
            HStack(spacing: 12) {
                ProgressView().progressViewStyle(.circular).tint(Color.indigo)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Preparing narration…")
                        .font(.subheadline.weight(.semibold))
                    Text("Generating a human voice — this takes a few seconds")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.indigo.opacity(0.3), lineWidth: 1))

        case .playing:
            HStack(spacing: 12) {
                Image(systemName: "waveform")
                    .symbolEffect(.variableColor.iterative, options: .repeating)
                    .font(.title3)
                    .foregroundStyle(Color.indigo)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Now narrating")
                        .font(.subheadline.weight(.semibold))
                    Text("Follow along below as the story plays")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { speech.stop() } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.indigo.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.indigo.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.indigo.opacity(0.25), lineWidth: 1))

        case .failed(let msg):
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.25), lineWidth: 1))

        default:
            EmptyView()
        }
    }

    // MARK: - Paragraph section

    private var paragraphSection: some View {
        let parts = storyParagraphs(bodyText)
        let icons  = visual.symbolsForParagraphs(parts.count)

        return VStack(alignment: .leading, spacing: 12) {
            // Section label — matches CreateStory SectionCard header style
            HStack(spacing: 8) {
                Image(systemName: "text.book.closed.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.indigo.opacity(0.8))
                Text("Your Story")
                    .font(.subheadline.weight(.semibold))
            }

            if parts.isEmpty {
                Text("No story text yet.")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(parts.enumerated()), id: \.offset) { index, paragraph in
                        HStack(alignment: .top, spacing: 12) {
                            // Paragraph icon — themed colour
                            Image(systemName: icons[index])
                                .font(.system(size: 16))
                                .foregroundStyle(Color(visual.colors.first ?? .indigo).opacity(0.8))
                                .frame(width: 28, alignment: .top)
                                .padding(.top, 2)

                            Text(paragraph)
                                .font(.body)
                                .lineSpacing(6)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }
}
