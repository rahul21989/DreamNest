import SwiftUI

// MARK: - Routes

private enum StoryRoute: Hashable {
    case generated
    case saved(Story)
    case downloaded
}

// MARK: - Preference metadata (icons + colours for the tile grid)

private struct PrefStyle {
    let icon: String
    let color: Color
    let emoji: String
}

private let prefStyles: [StoryPreference: PrefStyle] = [
    .superheroes: PrefStyle(icon: "bolt.fill",            color: .orange,  emoji: "⚡️"),
    .adventures:  PrefStyle(icon: "map.fill",             color: .brown,   emoji: "🗺️"),
    .castle:      PrefStyle(icon: "building.columns.fill",color: .pink,    emoji: "🏰"),
    .animals:     PrefStyle(icon: "hare.fill",            color: .mint,    emoji: "🐾"),
    .space:       PrefStyle(icon: "moon.stars.fill",      color: .indigo,  emoji: "🚀"),
    .ocean:       PrefStyle(icon: "water.waves",          color: .cyan,    emoji: "🌊"),
    .custom:      PrefStyle(icon: "wand.and.stars",       color: .purple,  emoji: "✨"),
]

// MARK: - Main Tab View

struct CreateStoryTabView: View {
    @StateObject private var viewModel = CreateStoryViewModel()
    @State private var path: [StoryRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 0) {
                    storyHero
                    formContent
                }
                .padding(.bottom, 32)
            }
            .ignoresSafeArea(edges: .top)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(value: StoryRoute.downloaded) {
                        Image(systemName: "books.vertical.fill")
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Saved stories")
                }
            }
            .navigationDestination(for: StoryRoute.self) { route in
                switch route {
                case .generated:
                    StoryReaderScreen(
                        viewModel: viewModel,
                        showSaveButton: true,
                        onSave: { viewModel.saveCurrentStory() }
                    )
                case .saved(let story):
                    StoryReaderScreen(story: story)
                case .downloaded:
                    DownloadedStoriesScreen(viewModel: viewModel)
                }
            }
        }
        .dreamNestNightMode()
    }

    // MARK: Hero header

    private var storyHero: some View {
        ZStack {
            LinearGradient(
                colors: [Color.indigo.opacity(0.85), Color.purple.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 10) {
                Image(systemName: "book.pages.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)

                Text("Create a Story")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("Craft a magical bedtime tale, just for your child")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 60)
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Form content

    private var formContent: some View {
        VStack(spacing: 20) {
            titleSection
            worldSection
            promptSection
            generateSection
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
    }

    // MARK: Title section

    private var titleSection: some View {
        SectionCard(icon: "pencil.and.scribble", title: "Story Title") {
            HStack(spacing: 12) {
                Image(systemName: "book.closed.fill")
                    .foregroundStyle(Color.indigo.opacity(0.8))
                TextField("e.g. Luna and the Magic Moon", text: $viewModel.title)
                    .font(.body)
            }
            .padding(14)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: World / preferences section

    private var worldSection: some View {
        SectionCard(icon: "sparkles", title: "Pick a World") {
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                ForEach(StoryPreference.allCases) { pref in
                    let isOn = viewModel.selectedPreferences.contains(pref)
                    let style = prefStyles[pref]!
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            if isOn {
                                viewModel.selectedPreferences.remove(pref)
                            } else {
                                viewModel.selectedPreferences.insert(pref)
                            }
                        }
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(isOn ? style.color : style.color.opacity(0.18))
                                    .frame(width: 46, height: 46)
                                Image(systemName: style.icon)
                                    .font(.system(size: 20))
                                    .foregroundStyle(isOn ? .white : style.color)
                            }
                            Text(pref.displayName)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(isOn ? style.color : .secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(isOn ? style.color.opacity(0.15) : Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(isOn ? style.color.opacity(0.6) : Color.clear, lineWidth: 1.5)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(isOn ? 1.04 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isOn)
                }
            }
        }
    }

    // MARK: Prompt section

    private var promptSection: some View {
        SectionCard(icon: "bubble.left.and.text.bubble.right.fill", title: "Your Idea") {
            ZStack(alignment: .topLeading) {
                if viewModel.prompt.isEmpty {
                    Text("e.g. A tiny dragon who is scared of fire learns to be brave…")
                        .font(.body)
                        .foregroundStyle(.secondary.opacity(0.6))
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $viewModel.prompt)
                    .font(.body)
                    .frame(minHeight: 110)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: Generate button

    private var generateSection: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    await viewModel.generate()
                    if case .success = viewModel.state {
                        path.append(.generated)
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    if viewModel.state == .generating {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Image(systemName: "wand.and.stars")
                            .font(.headline)
                    }
                    Text(viewModel.state == .generating ? "Weaving your story…" : "Create My Story ✨")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Group {
                        if viewModel.canGenerate && viewModel.state != .generating {
                            LinearGradient(
                                colors: [Color.purple, Color.indigo],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            LinearGradient(
                                colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(
                    color: viewModel.canGenerate ? Color.purple.opacity(0.4) : .clear,
                    radius: 10, y: 4
                )
            }
            .disabled(!viewModel.canGenerate || viewModel.state == .generating)

            if !viewModel.canGenerate && viewModel.state == .idle {
                Label("Add a title and your idea to begin", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if case .failed(let message) = viewModel.state {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

// MARK: - Reusable Section Card

private struct SectionCard<Content: View>: View {
    let icon: String
    let title: String
    let content: Content

    init(icon: String, title: String, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.indigo.opacity(0.8))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            content
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Downloaded Stories Screen

private struct DownloadedStoriesScreen: View {
    @ObservedObject var viewModel: CreateStoryViewModel

    var body: some View {
        Group {
            if viewModel.savedStories.isEmpty {
                ContentUnavailableView(
                    "No saved stories yet",
                    systemImage: "books.vertical.fill",
                    description: Text("Generate a story and save it to read anytime — even offline.")
                )
            } else {
                List {
                    ForEach(viewModel.savedStories) { story in
                        NavigationLink(value: StoryRoute.saved(story)) {
                            SavedStoryRow(story: story)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                    .onDelete(perform: viewModel.deleteSavedStories)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Saved Stories")
        .navigationBarTitleDisplayMode(.large)
        .dreamNestNightMode()
    }
}

// MARK: - Saved Story Row

private struct SavedStoryRow: View {
    let story: Story

    private var style: PrefStyle {
        let pref = story.preferences.first
        return prefStyles[pref ?? .adventures]!
    }

    private var visual: StoryVisualTheme {
        StoryVisualTheme(preferences: story.preferences, theme: story.theme ?? story.title)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(style.color.opacity(0.2))
                    .frame(width: 48, height: 48)
                Image(systemName: visual.systemName)
                    .font(.title3)
                    .foregroundStyle(style.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(story.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let theme = story.theme, !theme.isEmpty {
                    Text(theme)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(story.generatedText)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(style.color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}
