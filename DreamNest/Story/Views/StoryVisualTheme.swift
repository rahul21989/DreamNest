import SwiftUI

/// Lightweight, kid-friendly visuals using SF Symbols + soft colors (no bundled image assets).
struct StoryVisualTheme {
    let systemName: String
    let colors: [Color]

    init(preferences: [StoryPreference], theme: String?) {
        let themeLower = theme?.lowercased() ?? ""
        if preferences.contains(.space) || themeLower.contains("space") || themeLower.contains("star") {
            self.init("moon.stars.fill", [.indigo.opacity(0.7), .purple.opacity(0.5)])
        } else if preferences.contains(.ocean) || themeLower.contains("ocean") || themeLower.contains("sea") {
            self.init("water.waves", [.cyan.opacity(0.6), .blue.opacity(0.5)])
        } else if preferences.contains(.castle) || themeLower.contains("castle") || themeLower.contains("princess") {
            self.init("building.columns.fill", [.pink.opacity(0.5), .purple.opacity(0.45)])
        } else if preferences.contains(.animals) || themeLower.contains("animal") || themeLower.contains("bunny") {
            self.init("hare.fill", [.mint.opacity(0.55), .green.opacity(0.4)])
        } else if preferences.contains(.superheroes) || themeLower.contains("hero") {
            self.init("sparkles", [.orange.opacity(0.55), .yellow.opacity(0.4)])
        } else if preferences.contains(.adventures) || themeLower.contains("adventure") {
            self.init("map.fill", [.brown.opacity(0.5), .orange.opacity(0.35)])
        } else {
            self.init("book.closed.fill", [.blue.opacity(0.45), .indigo.opacity(0.4)])
        }
    }

    private init(_ name: String, _ colors: [Color]) {
        self.systemName = name
        self.colors = colors
    }

    var headerGradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Rotating SF Symbols for paragraph “illustrations” (lightweight, no assets).
    func symbolsForParagraphs(_ count: Int) -> [String] {
        let extras = ["sparkles", "cloud.fill", "heart.fill", "moon.fill", "leaf.fill", "star.fill"]
        let cycle = [systemName] + extras
        return (0..<count).map { cycle[$0 % cycle.count] }
    }
}

/// Split long story into short paragraphs for gentle “page” feel.
func storyParagraphs(_ text: String) -> [String] {
    let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
    let chunks = normalized.components(separatedBy: "\n\n")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    if chunks.count > 1 { return chunks }
    let lines = normalized.components(separatedBy: "\n")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    return lines.isEmpty ? [text] : lines
}
