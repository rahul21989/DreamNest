import SwiftUI

struct CategoryListView: View {
    let categories: [AudioCategory]
    @ObservedObject var rootViewModel: DreamNestRootViewModel

    var body: some View {
        List {
            Section {
                if rootViewModel.audioLibrary.tracks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add offline audio to:")
                            .font(.headline)
                        Text("`Resources/Audio/`")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(categories) { category in
                        NavigationLink {
                            CategoryTracksView(category: category, tracks: rootViewModel.tracks(in: category), rootViewModel: rootViewModel)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(category.displayName)
                                        .font(.headline)
                                    Text("\(rootViewModel.tracks(in: category).count) tracks")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("DreamNest")
    }
}

