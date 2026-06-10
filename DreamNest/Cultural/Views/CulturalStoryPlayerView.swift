import SwiftUI

struct CulturalStoryPlayerView: View {
    @StateObject var viewModel: CulturalStoryPlayerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var artScale: CGFloat = 1.0
    
    // Global horizontal constant padding safely enforced on all layout tiers
    private let horizontalPadding: CGFloat = 24

    var body: some View {
        ZStack {
            // Base black layer filling the device screen completely
            Color.black.ignoresSafeArea()

            // Main scroll container layout
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    
                    // ── Hero Art Layer (Controls are overlaid directly inside it) ──
                    heroArt
                        .frame(height: UIScreen.main.bounds.height * 0.52)
                        .overlay(alignment: .top) {
                            navigationHeader
                        }
                    
                    // ── Story Content Layer ──────────────────────────────────
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Title and Action Row (Ensures proper spacing metrics)
                        HStack(alignment: .top, spacing: 16) {
                            Text(viewModel.story.title)
                                .font(.title.bold())
                                .foregroundStyle(.white)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            mainPlayButton
                                .layoutPriority(1) // Prevents title compression from squeezing the CTA frame
                        }
                        
                        // Status Indicators (Offline sync alerts / Error descriptions)
                        statusRow
                        
                        // Interactive Audio Progress Timeline Control
                        audioControls
                        
                        Divider()
                            .background(Color.white.opacity(0.15))
                        
                        // Narrative "About" block context panel
                        VStack(alignment: .leading, spacing: 10) {
                            Text("About")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            
                            Text(viewModel.story.summary)
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.8))
                                .lineSpacing(6)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, horizontalPadding) // Secure padding block layout rule
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .ignoresSafeArea(.container, edges: .top)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.loadAndPlay() }
        .onDisappear { viewModel.stop() }
    }

    // MARK: - Safe Navigation Header Layout Component
    private var navigationHeader: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Button(action: { /* Share handling */ }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
            }
        }
        // Forces padding calculations to stay flush with the underlying text layouts
        .padding(.horizontal, horizontalPadding)
        // Native padding adjustment ensuring elements stay beneath the Dynamic Island notch region
        .padding(.top, safeAreaTopInset > 0 ? safeAreaTopInset : 16)
    }

    // MARK: - Hero Art Graphic Layer
    private var heroArt: some View {
        artBackground
            .scaleEffect(artScale)
            .onAppear {
                withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                    artScale = 1.04
                }
            }
            .overlay {
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.2), Color.black],
                    startPoint: .top, endPoint: .bottom
                )
            }
            .clipped()
    }

    private var artBackground: some View {
        viewModel.template.artworkView(fallbackIcon: true)
            .frame(maxWidth: UIScreen.main.bounds.width, maxHeight: .infinity)
            .aspectRatio(contentMode: .fill)
    }

    // MARK: - Action Buttons Component State Matrix
    private var mainPlayButton: some View {
        Group {
            switch viewModel.phase {
            case .loading:
                HStack(spacing: 8) {
                    ProgressView().tint(.black).scaleEffect(0.8)
                    Text("Loading").font(.subheadline.bold())
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white)
                .clipShape(Capsule())

            case .error:
                Button { Task { await viewModel.loadAndPlay() } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise").font(.caption.bold())
                        Text("Retry").font(.subheadline.bold())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .clipShape(Capsule())
                }

            default:
                Button { viewModel.togglePlayPause() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.body.bold())
                        Text(viewModel.isPlaying ? "Pause" : "Play")
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Audio controls
    private var audioControls: some View {
        VStack(spacing: 8) {
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
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: - Status row
    private var statusRow: some View {
        HStack(spacing: 6) {
            switch viewModel.phase {
            case .loading:
                Image(systemName: "arrow.down.circle")
                Text(viewModel.loadingMessage)
            case .error(let msg):
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
                Text(msg)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            default:
                if CulturalStoryCache.shared.isAudioCached(for: viewModel.story.id) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("Saved offline").foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .font(.footnote)
    }

    // MARK: - Dynamic Window Safety Boundary Computations
    private var safeAreaTopInset: CGFloat {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene?.windows.first?.safeAreaInsets.top ?? 0
    }

    // MARK: - Helpers
    private func formatTime(_ t: TimeInterval) -> String {
        guard t.isFinite && t >= 0 else { return "0:00" }
        return String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}
