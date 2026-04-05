import SwiftUI

private enum StoryRoute: Hashable {
    case generated
    case saved(Story)
    case downloaded
}

struct CreateStoryTabView: View {
    @StateObject private var viewModel = CreateStoryViewModel()
    @State private var path: [StoryRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Group {
                        Text("Create story")
                            .font(.title3)
                            .bold()

                        TextField("Story title", text: $viewModel.title)
                            .textFieldStyle(.roundedBorder)

                        TextField("Theme (optional)", text: $viewModel.theme)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preferences")
                            .font(.subheadline)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(StoryPreference.allCases) { pref in
                                    let isOn = viewModel.selectedPreferences.contains(pref)
                                    Button {
                                        if isOn {
                                            viewModel.selectedPreferences.remove(pref)
                                        } else {
                                            viewModel.selectedPreferences.insert(pref)
                                        }
                                    } label: {
                                        Text(pref.displayName)
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(isOn ? Color.accentColor.opacity(0.85) : Color.clear)
                                            .foregroundStyle(isOn ? Color.white : Color.accentColor)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.accentColor.opacity(0.7), lineWidth: 1)
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Story prompt")
                            .font(.subheadline)
                        ZStack(alignment: .topLeading) {
                            if viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Example: A brave bunny explores space and finds a cozy new friend.")
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.top, 10)
                            }
                            TextEditor(text: $viewModel.prompt)
                                .frame(minHeight: 140)
                                .padding(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.4))
                                )
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            Task {
                                await viewModel.generate()
                                if case .success = viewModel.state {
                                    path.append(.generated)
                                }
                            }
                        } label: {
                            HStack {
                                if viewModel.state == .generating {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                }
                                Text("Generate story")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.canGenerate || viewModel.state == .generating)

                        switch viewModel.state {
                        case .failed(let message):
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        default:
                            EmptyView()
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Story")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(value: StoryRoute.downloaded) {
                        Image(systemName: "tray.and.arrow.down")
                    }
                    .accessibilityLabel("Downloaded stories")
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
}

private struct DownloadedStoriesScreen: View {
    @ObservedObject var viewModel: CreateStoryViewModel

    var body: some View {
        List {
            if viewModel.savedStories.isEmpty {
                ContentUnavailableView(
                    "No downloaded stories",
                    systemImage: "tray.and.arrow.down",
                    description: Text("Generate a story, then save it for offline reading.")
                )
            } else {
                ForEach(viewModel.savedStories.indices, id: \.self) { index in
                    let story = viewModel.savedStories[index]
                    NavigationLink(value: StoryRoute.saved(story)) {
                        SavedStoryRow(story: story)
                    }
                }
                .onDelete(perform: viewModel.deleteSavedStories)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Downloaded")
        .dreamNestNightMode()
    }
}

private struct SavedStoryRow: View {
    let story: Story

    private var visual: StoryVisualTheme {
        StoryVisualTheme(preferences: story.preferences, theme: story.theme ?? story.title)
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: visual.systemName)
                .font(.title2)
                .foregroundStyle(Color.accentColor.opacity(0.85))
                .frame(width: 40, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text(story.title)
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.primary)
                if let theme = story.theme, !theme.isEmpty {
                    Text(theme)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(story.generatedText)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }
}
