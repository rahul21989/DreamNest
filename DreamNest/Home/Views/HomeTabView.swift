import SwiftUI

// MARK: - Onboarding step model (unchanged)

private struct OnboardingStep {
    let icon: String
    let iconColor: Color
    let title: String
    let body: String
    let arrow: String
}

private let onboardingSteps: [OnboardingStep] = [
    OnboardingStep(icon: "moon.stars.fill", iconColor: .yellow,
                   title: "Welcome to DreamNest 🌙",
                   body: "A cosy bedtime companion for your little one. Soothing lullabies and personalised stories — all in one place.",
                   arrow: "Swipe to see what's inside →"),
    OnboardingStep(icon: "music.note.list", iconColor: .indigo,
                   title: "Browse Lullabies",
                   body: "Scroll down to explore calming lullabies and soothing sounds organised by category.",
                   arrow: "↓ Those cards below"),
    OnboardingStep(icon: "books.vertical.fill", iconColor: .orange,
                   title: "Cultural Stories",
                   body: "Tap Library to discover Indian mythological stories — Bal Krishna, Ganesha, Panchatantra and more.",
                   arrow: "↓ Library tab at the bottom"),
    OnboardingStep(icon: "play.circle.fill", iconColor: .cyan,
                   title: "Now Playing Bar",
                   body: "The player bar at the bottom lets you play, pause, skip and set a sleep timer.",
                   arrow: "↓ The dark bar at the very bottom"),
]

// MARK: - HomeTabView

struct HomeTabView: View {
    @ObservedObject var rootViewModel: DreamNestRootViewModel
    var onSeeAll: (() -> Void)? = nil
    @AppStorage("dn_onboarding_complete") private var onboardingComplete = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.04, green: 0.03, blue: 0.14).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        topBar
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 24)

                        featuredSection

                        lullabiesSection
                            .padding(.top, 30)
                    }
                    .padding(.bottom, 220)
                }
                .toolbar(.hidden, for: .navigationBar)
            }
            .safeAreaInset(edge: .bottom) {
                NowPlayingView(
                    rootViewModel: rootViewModel,
                    nowPlayingViewModel: rootViewModel.nowPlayingViewModel
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 90)   // clears floating tab bar
            }
        }
        .overlay {
            if !onboardingComplete {
                OnboardingOverlay(isComplete: $onboardingComplete).ignoresSafeArea()
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("DreamNest")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("Namaste! Sweet dreams await 🌙")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !rootViewModel.audioLibrary.tracks.isEmpty {
                Button(action: quickSleep) {
                    HStack(spacing: 5) {
                        Image(systemName: "powersleep")
                        Text("\(rootViewModel.parentsSettings.defaultSleepTimerMinutes)m")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.indigo.opacity(0.55))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                }
            }
        }
    }

    // MARK: - Featured stories

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("✨ Featured Stories")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    onSeeAll?()
                } label: {
                    Text("See all →")
                        .font(.caption.bold())
                        .foregroundStyle(Color.orange)
                }
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(CulturalTemplate.all) { template in
                        NavigationLink(
                            destination: CulturalStoryListView(template: template)
                        ) {
                            FeaturedStoryCard(template: template)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 4)
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
        }
    }

    // MARK: - Lullabies

    private var lullabiesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text("🌙")
                    .font(.title3)
                Text("Introducing Lullabies")
                    .font(.headline.italic().bold())
                    .foregroundStyle(.white)
                Spacer()
                starsDecoration
            }
            .padding(.horizontal, 20)

            CategoryListView(
                categories: rootViewModel.categories,
                rootViewModel: rootViewModel
            )
        }
    }

    private var starsDecoration: some View {
        HStack(spacing: 5) {
            ForEach(Array([7, 5, 9, 5].enumerated()), id: \.offset) { _, size in
                Image(systemName: "star.fill")
                    .font(.system(size: CGFloat(size)))
                    .foregroundStyle(Color.yellow.opacity(0.65))
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

// MARK: - Featured story card

private struct FeaturedStoryCard: View {
    let template: CulturalTemplate

    var body: some View {
        ZStack {
            // Artwork
            template.artworkView(fallbackIcon: true)

            // Bottom scrim
            LinearGradient(
                colors: [.clear, .clear, Color.black.opacity(0.55), Color.black.opacity(0.92)],
                startPoint: .top, endPoint: .bottom
            )
        }
        .frame(width: 272, height: 355)
        // "Free" badge — fixed 14pt from top-left
        .overlay(alignment: .topLeading) {
            Text("Free")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green)
                .clipShape(Capsule())
                .padding(.top, 14)
                .padding(.leading, 14)
        }
        // Play pill + title — fixed 18pt from bottom-left
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill").font(.caption2.bold())
                    Text("Play").font(.subheadline.bold())
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color.white)
                .clipShape(Capsule())

                Text(template.name)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(template.subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(2)
            }
            .padding(.leading, 18)
            .padding(.bottom, 18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.45), radius: 14, y: 7)
    }
}

// MARK: - Onboarding Overlay (unchanged)

private struct OnboardingOverlay: View {
    @Binding var isComplete: Bool
    @State private var step = 0

    var body: some View {
        ZStack {
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
                    .id(step)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: step)
    }

    private var stepCard: some View {
        let s = onboardingSteps[step]
        let isLast = step == onboardingSteps.count - 1
        return VStack(spacing: 20) {
            ZStack {
                Circle().fill(s.iconColor.opacity(0.2)).frame(width: 80, height: 80)
                Image(systemName: s.icon).font(.system(size: 36)).foregroundStyle(s.iconColor)
            }
            VStack(spacing: 8) {
                Text(s.title).font(.title3.bold()).foregroundStyle(.white).multilineTextAlignment(.center)
                Text(s.body).font(.subheadline).foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center).lineSpacing(4)
                Text(s.arrow).font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.5)).padding(.top, 2)
            }
            HStack(spacing: 6) {
                ForEach(onboardingSteps.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == step ? Color.white : Color.white.opacity(0.3))
                        .frame(width: i == step ? 20 : 6, height: 6)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: step)
            Button {
                if isLast { isComplete = true } else { step += 1 }
            } label: {
                Text(isLast ? "Let's Go! 🌙" : "Next →")
                    .font(.headline).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            if !isLast {
                Button("Skip") { isComplete = true }
                    .font(.caption).foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(red: 0.10, green: 0.08, blue: 0.25).opacity(0.97))
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.1), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
    }
}
