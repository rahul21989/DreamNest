import SwiftUI

struct ContentView: View {
    @StateObject private var rootViewModel = DreamNestRootViewModel()
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // All tabs loaded simultaneously — opacity switch preserves each tab's state
            ZStack {
                HomeTabView(rootViewModel: rootViewModel, onSeeAll: { selectedTab = 1 })
                    .opacity(selectedTab == 0 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 0)

                CulturalTemplatesView()
                    .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 88) }
                    .opacity(selectedTab == 1 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 1)

                CreateStoryTabView()
                    .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 88) }
                    .opacity(selectedTab == 2 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 2)

                SettingsTabView(rootViewModel: rootViewModel)
                    .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 88) }
                    .opacity(selectedTab == 3 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 3)
            }
            .ignoresSafeArea()

            DreamNestTabBar(selectedTab: $selectedTab)
        }
        .dreamNestNightMode()
        .onChange(of: selectedTab) { _, newTab in
            if newTab != 0 && rootViewModel.nowPlayingViewModel.isPlaying {
                rootViewModel.nowPlayingViewModel.togglePlayPause()
            }
        }
    }
}

// MARK: - Floating tab bar

struct DreamNestTabBar: View {
    @Binding var selectedTab: Int

    private let pillBg = Color(red: 0.13, green: 0.10, blue: 0.28)

    var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: 30) {
                tabBtn(tag: 0, icon: "house.fill",          label: "Home")
                tabBtn(tag: 1, icon: "books.vertical.fill", label: "Library")
                tabBtn(tag: 2, icon: "wand.and.stars",      label: "Create")
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 13)
            .background(
                Capsule()
                    .fill(pillBg)
                    .shadow(color: .black.opacity(0.5), radius: 20, y: 6)
            )
            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))

            Spacer()

            Button { selectedTab = 3 } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(selectedTab == 3 ? Color.orange : Color.white.opacity(0.5))
                    .frame(width: 52, height: 52)
                    .background(
                        Circle()
                            .fill(pillBg)
                            .shadow(color: .black.opacity(0.5), radius: 16, y: 6)
                    )
                    .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 12)
    }

    private func tabBtn(tag: Int, icon: String, label: String) -> some View {
        Button { selectedTab = tag } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                Text(label)
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(selectedTab == tag ? Color.orange : Color.white.opacity(0.42))
            .animation(.easeInOut(duration: 0.15), value: selectedTab)
        }
    }
}

#Preview {
    ContentView()
}
