import SwiftUI

struct CulturalStoryPlayerView: View {
    @StateObject var viewModel: CulturalStoryPlayerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var artScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Hero art (top ~55%) ──────────────────────────────────────
                heroArt
                    .frame(height: heroHeight)

                // ── Detail panel (bottom) ────────────────────────────────────
                detailPanel
            }
        }
        .task { await viewModel.loadAndPlay() }
        .onDisappear { viewModel.stop() }
    }

    // MARK: - Hero art

    private var heroHeight: CGFloat {
        UIScreen.main.bounds.height * 0.54
    }

    private var heroArt: some View {
        artBackground
            .scaleEffect(artScale)
            .onAppear {
                withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                    artScale = 1.06
                }
            }
            // Bottom gradient
            .overlay {
                LinearGradient(
                    colors: [.clear, .clear, Color.black.opacity(0.35), Color.black.opacity(0.85)],
                    startPoint: .top, endPoint: .bottom
                )
            }
            // Back button — fixed top-left
            .overlay(alignment: .topLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Circle())
                }
                .padding(.leading, 20)
                .padding(.top, 56)
            }
            // Share button — fixed top-right
            .overlay(alignment: .topTrailing) {
                Button { } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Circle())
                }
                .padding(.trailing, 20)
                .padding(.top, 56)
            }
            // Title + play pill — fixed bottom, full width
            .overlay(alignment: .bottom) {
                HStack(alignment: .bottom) {
                    Text(viewModel.story.title)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    mainPlayButton
                        .padding(.leading, 12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .clipped()
    }

    private var artBackground: some View {
        viewModel.template.artworkView(fallbackIcon: true)
    }

    // MARK: - Detail panel

    private var detailPanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // About section
                VStack(alignment: .leading, spacing: 10) {

                    Text("About")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .underline()
                        .padding(.bottom, 2)

                    Text(viewModel.story.summary)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.78))
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)

                // Audio controls
                audioControls
                    .padding(.top, 28)
                    .padding(.horizontal, 20)

                // Status row
                statusRow
                    .padding(.horizontal, 20)
                    .padding(.top, 18)

                Spacer(minLength: 24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.black)
    }

    // MARK: - Main play button (in hero)

    private var mainPlayButton: some View {
        Group {
            switch viewModel.phase {
            case .loading:
                HStack(spacing: 8) {
                    ProgressView().tint(.black).scaleEffect(0.75)
                    Text("Loading…").font(.subheadline.bold())
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(Capsule())

            case .error:
                Button { Task { await viewModel.loadAndPlay() } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise").font(.caption.bold())
                        Text("Retry").font(.subheadline.bold())
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .clipShape(Capsule())
                }

            default:
                Button { viewModel.togglePlayPause() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.subheadline.bold())
                        Text(viewModel.isPlaying ? "Pause" : "Play")
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Audio controls (progress + transport)

    private var audioControls: some View {
        VStack(spacing: 10) {
            // Progress bar
            Slider(
                value: Binding(
                    get: { viewModel.progress },
                    set: { viewModel.seek(to: $0) }
                ),
                in: 0...1
            )
            .tint(.white)
            .opacity(viewModel.phase == .playing || viewModel.phase == .idle ? 1 : 0.4)
            .disabled(viewModel.phase != .playing && viewModel.phase != .idle)

            HStack {
                Text(formatTime(viewModel.currentTime))
                Spacer()
                Text(formatTime(viewModel.duration))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.white.opacity(0.45))
        }
    }

    // MARK: - Status row

    private var statusRow: some View {
        HStack(spacing: 6) {
            switch viewModel.phase {
            case .loading:
                Image(systemName: "arrow.down.circle")
                    .font(.caption2)
                Text(viewModel.loadingMessage)
                    .font(.caption2)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.loadingMessage)
            case .error(let msg):
                Image(systemName: "exclamationmark.circle")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Text(msg).font(.caption2).foregroundStyle(.orange).lineLimit(2)
            default:
                if CulturalStoryCache.shared.isAudioCached(for: viewModel.story.id) {
                    Image(systemName: "checkmark.circle.fill").font(.caption2).foregroundStyle(.green.opacity(0.8))
                    Text("Saved for offline").font(.caption2)
                }
            }
        }
        .foregroundStyle(.white.opacity(0.5))
    }

    // MARK: - Helpers

    private func formatTime(_ t: TimeInterval) -> String {
        guard t.isFinite && t >= 0 else { return "0:00" }
        return String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}
