import SwiftUI

// MARK: - Category visual style helper

private struct CatStyle {
    let icon: String
    let colors: [Color]
    let emoji: String
}

private func catStyle(for id: String) -> CatStyle {
    let lower = id.lowercased()
    if lower.contains("lullab") {
        return CatStyle(icon: "moon.zzz.fill",    colors: [.indigo, .purple],   emoji: "🌙")
    } else if lower.contains("white") || lower.contains("noise") {
        return CatStyle(icon: "waveform",          colors: [.teal, .cyan],       emoji: "〰️")
    } else if lower.contains("nature") || lower.contains("forest") {
        return CatStyle(icon: "leaf.fill",         colors: [.green, .mint],      emoji: "🌿")
    } else if lower.contains("rain") {
        return CatStyle(icon: "cloud.rain.fill",   colors: [.blue, .cyan],       emoji: "🌧️")
    } else if lower.contains("ocean") || lower.contains("sea") {
        return CatStyle(icon: "water.waves",       colors: [.cyan, .blue],       emoji: "🌊")
    } else if lower.contains("classic") {
        return CatStyle(icon: "music.note",        colors: [.orange, .yellow],   emoji: "🎼")
    } else if lower.contains("sleep") || lower.contains("bedtime") {
        return CatStyle(icon: "bed.double.fill",   colors: [.purple, .indigo],   emoji: "🛏️")
    } else if lower.contains("meditat") {
        return CatStyle(icon: "wind",              colors: [.mint, .teal],       emoji: "🧘")
    }
    return CatStyle(icon: "music.note.list",       colors: [.purple, .indigo],   emoji: "🎵")
}

// MARK: - CategoryListView

struct CategoryListView: View {
    let categories: [AudioCategory]
    @ObservedObject var rootViewModel: DreamNestRootViewModel

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Text("What would you like to hear?")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)

            if rootViewModel.audioLibrary.tracks.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(categories) { category in
                        NavigationLink {
                            CategoryTracksView(
                                category: category,
                                tracks: rootViewModel.tracks(in: category),
                                rootViewModel: rootViewModel
                            )
                        } label: {
                            CategoryCard(
                                category: category,
                                trackCount: rootViewModel.tracks(in: category).count,
                                style: catStyle(for: category.id)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.indigo.opacity(0.6))
            Text("No lullabies yet")
                .font(.headline)
            Text("Add audio files to Resources/Audio/ to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Category Card

private struct CategoryCard: View {
    let category: AudioCategory
    let trackCount: Int
    let style: CatStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Coloured icon area
            ZStack(alignment: .bottomTrailing) {
                LinearGradient(colors: style.colors.map { $0.opacity(0.75) },
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(height: 90)

                // Decorative large icon in corner
                Image(systemName: style.icon)
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.18))
                    .offset(x: 10, y: 10)

                // Emoji in top-left
                Text(style.emoji)
                    .font(.system(size: 28))
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                // Small icon badge
                Image(systemName: style.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(8)
            }
            .clipped()

            // Label area
            VStack(alignment: .leading, spacing: 3) {
                Text(category.displayName)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(trackCount) track\(trackCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
