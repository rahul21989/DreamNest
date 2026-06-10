import SwiftUI

struct CulturalStoryListView: View {
    let template: CulturalTemplate
    @StateObject private var viewModel: CulturalStoryListViewModel

    init(template: CulturalTemplate) {
        self.template = template
        _viewModel = StateObject(
            wrappedValue: CulturalStoryListViewModel(template: template)
        )
    }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.04, blue: 0.15).ignoresSafeArea()

            Group {
                if viewModel.isLoading && viewModel.stories.isEmpty {
                    loadingView
                } else if let err = viewModel.errorMessage, viewModel.stories.isEmpty {
                    errorView(err)
                } else {
                    storiesList
                }
            }
        }
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await viewModel.loadStories() }
    }

    // MARK: - Stories list

    private var storiesList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                // Sub-header
                HStack(spacing: 10) {
                    Image(systemName: template.systemImage)
                        .font(.body)
                        .foregroundStyle(.white)
                        .padding(9)
                        .background(
                            LinearGradient(
                                colors: template.gradientColors,
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(template.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Text("\(viewModel.stories.count) stories • tap to listen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 10)

                ForEach(viewModel.stories) { story in
                    NavigationLink(destination: CulturalStoryPlayerView(
                        viewModel: CulturalStoryPlayerViewModel(story: story, template: template)
                    )) {
                        StoryRowView(story: story)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        LoadingIconView(systemImage: template.systemImage, colors: template.gradientColors)
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)
            Text("Couldn't load stories")
                .font(.headline).foregroundStyle(.primary)
            Text(message)
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try Again") { Task { await viewModel.retry() } }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
        }
    }
}

// MARK: - Loading icon (safe animation, no symbolEffect)

private struct LoadingIconView: View {
    let systemImage: String
    let colors: [Color]
    @State private var scale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(
                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .scaleEffect(scale)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                        scale = 1.15
                    }
                }

            Text("Finding stories…")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ProgressView()
                .tint(.white)
        }
    }
}

// MARK: - Story row

private struct StoryRowView: View {
    let story: CulturalStory

    private var isCached: Bool {
        CulturalStoryCache.shared.isAudioCached(for: story.id)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.indigo.opacity(0.22))
                    .frame(width: 46, height: 46)
                Image(systemName: isCached ? "play.fill" : "wand.and.stars")
                    .font(.system(size: 17))
                    .foregroundStyle(Color.indigo)
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(story.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(story.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            // Cached badge / chevron
            if isCached {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.green.opacity(0.75))
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
}
