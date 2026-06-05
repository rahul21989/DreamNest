import SwiftUI

// MARK: - Onboarding step model

private struct OnboardingStep {
    let icon: String
    let iconColor: Color
    let title: String
    let body: String
    let arrow: String   // direction hint text
}

private let onboardingSteps: [OnboardingStep] = [
    OnboardingStep(
        icon: "moon.stars.fill",
        iconColor: .yellow,
        title: "Welcome to DreamNest 🌙",
        body: "A cosy bedtime companion for your little one. Soothing lullabies and personalised stories — all in one place.",
        arrow: "Swipe to see what's inside →"
    ),
    OnboardingStep(
        icon: "music.note.list",
        iconColor: .indigo,
        title: "Browse Lullabies",
        body: "Tap any category card below to explore our collection of calming lullabies and soothing sounds.",
        arrow: "↓ Those colourful cards below"
    ),
    OnboardingStep(
        icon: "powersleep",
        iconColor: .purple,
        title: "Quick Sleep Button",
        body: "Tap \"Quick Sleep\" to instantly start a lullaby with a sleep timer. Perfect for those sleepy moments!",
        arrow: "↑ The capsule button in the header"
    ),
    OnboardingStep(
        icon: "play.circle.fill",
        iconColor: .cyan,
        title: "Your Music Player",
        body: "The player bar at the bottom lets you play, pause, skip tracks and set a sleep timer — all without leaving the screen.",
        arrow: "↓ The dark bar at the very bottom"
    ),
]

// MARK: - HomeTabView

struct HomeTabView: View {
    @ObservedObject var rootViewModel: DreamNestRootViewModel

    @AppStorage("dn_onboarding_complete") private var onboardingComplete = false

    var body: some View {
        GeometryReader { geo in
            NavigationStack {
                ScrollView {
                    VStack(spacing: 0) {
                        heroHeader(safeTop: geo.safeAreaInsets.top)
                        CategoryListView(
                            categories: rootViewModel.categories,
                            rootViewModel: rootViewModel
                        )
                        .padding(.top, 8)
                    }
                    .padding(.bottom, 220)
                }
                // Extend scroll content behind status bar while keeping hero content below Dynamic Island
                .ignoresSafeArea(edges: .top)
                .navigationBarHidden(true)
                .safeAreaInset(edge: .bottom) {
                    NowPlayingView(
                        rootViewModel: rootViewModel,
                        nowPlayingViewModel: rootViewModel.nowPlayingViewModel
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                }
            }
            // First-launch onboarding overlay
            .overlay {
                if !onboardingComplete {
                    OnboardingOverlay(isComplete: $onboardingComplete)
                        .ignoresSafeArea()
                }
            }
        }
        .dreamNestNightMode()
    }

    // MARK: - Hero header

    private func heroHeader(safeTop: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Night-sky gradient fills the whole hero box (extends behind status bar)
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.05, blue: 0.20),
                    Color(red: 0.11, green: 0.09, blue: 0.32),
                    Color.indigo.opacity(0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            starsLayer

            // Content pushed BELOW Dynamic Island / status bar by safeTop
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Color.yellow.opacity(0.9))
                        .shadow(color: .yellow.opacity(0.5), radius: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("DreamNest")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text("Soothing sounds for little ones")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                if !rootViewModel.audioLibrary.tracks.isEmpty {
                    Button { quickSleep() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "powersleep")
                            Text("Quick Sleep · \(rootViewModel.parentsSettings.defaultSleepTimerMinutes)m")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 22)
            // ← This is the key fix: push content below Dynamic Island / notch
            .padding(.top, safeTop + 10)
        }
        .frame(maxWidth: .infinity)
    }

    // Decorative star dots
    private var starsLayer: some View {
        GeometryReader { geo in
            let stars: [(CGFloat, CGFloat, CGFloat)] = [
                (0.15, 0.15, 3), (0.55, 0.08, 2), (0.80, 0.20, 4),
                (0.30, 0.32, 2), (0.72, 0.38, 3), (0.90, 0.10, 2),
                (0.45, 0.25, 2), (0.10, 0.45, 3), (0.65, 0.50, 2)
            ]
            ForEach(stars.indices, id: \.self) { i in
                let (x, y, size) = stars[i]
                Circle()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: size, height: size)
                    .position(x: geo.size.width * x, y: geo.size.height * y)
            }
        }
    }

    // MARK: - Quick sleep

    private func quickSleep() {
        let minutes = rootViewModel.parentsSettings.defaultSleepTimerMinutes
        let fade    = rootViewModel.parentsSettings.fadeOutSeconds
        let vm      = rootViewModel.nowPlayingViewModel

        let lullabyCat = rootViewModel.categories.first {
            $0.id.caseInsensitiveCompare("Lullabies") == .orderedSame
        }
        let lullabies = lullabyCat.map { rootViewModel.tracks(in: $0) } ?? []

        if !lullabies.isEmpty {
            let favs = lullabies.filter { rootViewModel.favoriteTrackFilenames.contains($0.filename) }
            let rest = lullabies.filter { !rootViewModel.favoriteTrackFilenames.contains($0.filename) }
            let playlist = favs + rest
            vm.playTrack(playlist[0], playlist: playlist, index: 0)
        }
        vm.startSleepTimer(minutes: minutes, fadeOutSeconds: fade)
    }
}

// MARK: - Onboarding Overlay

private struct OnboardingOverlay: View {
    @Binding var isComplete: Bool
    @State private var step = 0

    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.72)

            VStack {
                Spacer()
                stepCard
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    ))
                    .id(step)   // forces transition when step changes
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: step)
    }

    private var stepCard: some View {
        let s = onboardingSteps[step]
        let isLast = step == onboardingSteps.count - 1

        return VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(s.iconColor.opacity(0.2))
                    .frame(width: 80, height: 80)
                Image(systemName: s.icon)
                    .font(.system(size: 36))
                    .foregroundStyle(s.iconColor)
            }

            // Text
            VStack(spacing: 8) {
                Text(s.title)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(s.body)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text(s.arrow)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 2)
            }

            // Page dots
            HStack(spacing: 6) {
                ForEach(onboardingSteps.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == step ? Color.white : Color.white.opacity(0.3))
                        .frame(width: i == step ? 20 : 6, height: 6)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: step)

            // Button
            Button {
                if isLast {
                    isComplete = true
                } else {
                    step += 1
                }
            } label: {
                Text(isLast ? "Let's Go! 🌙" : "Next →")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(
                            colors: [Color.indigo, Color.purple],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)

            if !isLast {
                Button("Skip") { isComplete = true }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(red: 0.10, green: 0.08, blue: 0.25).opacity(0.97))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
    }
}
