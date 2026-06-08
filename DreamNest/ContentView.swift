//
//  ContentView.swift
//  DreamNest
//
//  Created by Rahul Goyal on 30/03/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var rootViewModel = DreamNestRootViewModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeTabView(rootViewModel: rootViewModel)
                .tabItem { Label("HOME", systemImage: "house.fill") }
                .tag(0)

            CreateStoryTabView()
                .tabItem { Label("CREATE STORY", systemImage: "book.fill") }
                .tag(1)

            SettingsTabView(rootViewModel: rootViewModel)
                .tabItem { Label("SETTING", systemImage: "gearshape.fill") }
                .tag(2)
        }
        .onChange(of: selectedTab) { _, newTab in
            // Pause music whenever the user leaves the Home tab
            if newTab != 0 && rootViewModel.nowPlayingViewModel.isPlaying {
                rootViewModel.nowPlayingViewModel.togglePlayPause()
            }
        }
    }
}

#Preview {
    ContentView()
}
