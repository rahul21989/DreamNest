import SwiftUI

struct CulturalTemplate: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let systemImage: String
    let gradientStartHex: String
    let gradientEndHex: String
    let promptContext: String

    /// Asset catalog image name — created by running `python3 download_artwork.py` once.
    var artworkAssetName: String { "template_\(id)" }

    // MARK: - Static library

    static let all: [CulturalTemplate] = [
        CulturalTemplate(
            id: "bal_krishna",
            name: "Bal Krishna",
            subtitle: "The divine butter thief",
            systemImage: "music.note",
            gradientStartHex: "#1a237e",
            gradientEndHex: "#4fc3f7",
            promptContext: """
            Young Krishna growing up in Vrindavan. Playful, innocent stories: sneaking into the butter pot, \
            lifting the Govardhan hill with one finger, playing his magical flute under the stars, \
            his deep love for mother Yashoda, and his warm friendship with the gopas. \
            Focus on wonder, playfulness, and unconditional love.
            """
        ),
        CulturalTemplate(
            id: "bal_ganesha",
            name: "Bal Ganesha",
            subtitle: "The wise little elephant god",
            systemImage: "star.fill",
            gradientStartHex: "#e65100",
            gradientEndHex: "#ffb300",
            promptContext: """
            Young Ganesha, the elephant-headed son of Shiva and Parvati. Stories about his endless love for \
            modaks (sweet dumplings), his clever little mouse friend Mushak, his wisdom in solving tricky problems, \
            and the famous story of walking around his parents instead of the whole world. \
            Focus on cleverness, sweetness, and love for family.
            """
        ),
        CulturalTemplate(
            id: "bal_hanuman",
            name: "Bal Hanuman",
            subtitle: "The mighty little devotee",
            systemImage: "sun.max.fill",
            gradientStartHex: "#b71c1c",
            gradientEndHex: "#ff8f00",
            promptContext: """
            Young Hanuman, full of boundless energy and innocent mischief. Stories about mistaking the sun for \
            a big ripe mango, his incredible strength used only for good, his pure-hearted devotion to Lord Ram, \
            and his adventures in the forest. Focus on courage, devotion, and childlike wonder.
            """
        ),
        CulturalTemplate(
            id: "panchatantra",
            name: "Panchatantra",
            subtitle: "Wise tales from the forest",
            systemImage: "hare.fill",
            gradientStartHex: "#1b5e20",
            gradientEndHex: "#66bb6a",
            promptContext: """
            Classic Indian Panchatantra animal fables teaching wisdom and kindness. Talking animals — lions, \
            monkeys, crocodiles, crows, deer, and mice — face everyday problems and find clever solutions. \
            Soften any conflict; emphasise friendship and learning over harm. \
            Each story ends with a gentle moral lesson a 4-year-old can understand.
            """
        ),
        CulturalTemplate(
            id: "jataka",
            name: "Jataka Tales",
            subtitle: "Stories of kindness & compassion",
            systemImage: "leaf.fill",
            gradientStartHex: "#4a148c",
            gradientEndHex: "#e040fb",
            promptContext: """
            Buddhist Jataka Tales — the Buddha's previous lives as animals and kind-hearted humans. \
            Each story teaches compassion, generosity, patience, and wisdom. Animals speak and show \
            beautiful human virtues. Focus on sharing, caring for all living beings, and gentle wisdom \
            that children can carry into their dreams.
            """
        ),
        CulturalTemplate(
            id: "festivals",
            name: "Festival Stories",
            subtitle: "Celebrate with bedtime tales",
            systemImage: "sparkles",
            gradientStartHex: "#f57f17",
            gradientEndHex: "#ffd54f",
            promptContext: """
            Gentle stories that explain Indian festivals to young children. Diwali: Ram and Sita's joyful \
            homecoming, lighting beautiful diyas, the warmth of family. Holi: the colors of love and Prahlad's \
            devotion. Raksha Bandhan: siblings protecting each other forever. Navratri: the goddess dancing \
            with joy. Focus on warmth, togetherness, light, and celebration.
            """
        ),
        CulturalTemplate(
            id: "folklore",
            name: "Folk Tales",
            subtitle: "Stories from across India",
            systemImage: "map.fill",
            gradientStartHex: "#006064",
            gradientEndHex: "#26c6da",
            promptContext: """
            Regional folk tales celebrating India's diversity. Kerala stories of King Mahabali and Onam. \
            Rajasthan desert tales of clever animals and brave children. Bengali stories from Thakurmar Jhuli. \
            Mountain tales from Himachal Pradesh. Each story weaves in regional food, nature, and traditions. \
            Focus on curiosity, the beauty of India's land, and the magic in everyday life.
            """
        )
    ]
}

// MARK: - Artwork view helper

extension CulturalTemplate {
    /// Renders the artwork if bundled, otherwise falls back to the gradient background.
    /// Use inside a ZStack — this fills the parent frame.
    @ViewBuilder
    func artworkView(fallbackIcon: Bool = false) -> some View {
        if UIImage(named: artworkAssetName) != nil {
            Image(artworkAssetName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            // Gradient + optional faint icon while art hasn't been downloaded yet
            ZStack {
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                if fallbackIcon {
                    Image(systemName: systemImage)
                        .font(.system(size: 100))
                        .foregroundStyle(.white.opacity(0.15))
                        .rotationEffect(.degrees(-8))
                        .offset(x: 40, y: -20)
                }
            }
        }
    }
}

// MARK: - Color helper

extension CulturalTemplate {
    var gradientColors: [Color] {
        [color(from: gradientStartHex), color(from: gradientEndHex)]
    }

    private func color(from hex: String) -> Color {
        let hexStr = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard hexStr.count == 6 else { return .indigo }
        var rgb: UInt64 = 0
        Scanner(string: hexStr).scanHexInt64(&rgb)
        return Color(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8)  & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }
}
