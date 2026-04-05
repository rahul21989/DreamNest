import SwiftUI

struct HomeTabView: View {
    @ObservedObject var rootViewModel: DreamNestRootViewModel

    var body: some View {
        NavigationStack {
            CategoryListView(
                categories: rootViewModel.categories,
                rootViewModel: rootViewModel
            )
            .safeAreaInset(edge: .bottom) {
                NowPlayingView(
                    rootViewModel: rootViewModel,
                    nowPlayingViewModel: rootViewModel.nowPlayingViewModel
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
        }
        .dreamNestNightMode()
    }
}

