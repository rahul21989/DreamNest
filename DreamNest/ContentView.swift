//
//  ContentView.swift
//  DreamNest
//
//  Created by Rahul Goyal on 30/03/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var rootViewModel = DreamNestRootViewModel()

    var body: some View {
        TabView {
            HomeTabView(rootViewModel: rootViewModel)
                .tabItem {
                    Label("HOME", systemImage: "house.fill")
                }

            CreateStoryTabView()
                .tabItem {
                    Label("CREATE STORY", systemImage: "book.fill")
                }

            SettingsTabView(rootViewModel: rootViewModel)
                .tabItem {
                    Label("SETTING", systemImage: "gearshape.fill")
                }
        }
    }
}

#Preview {
    ContentView()
}
