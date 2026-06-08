import Foundation

final class ThemeStore: @unchecked Sendable {
    private enum Keys {
        static let themeMode = "dn_theme_mode_v1"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults.standard) {
        self.defaults = defaults
    }

    func load() -> DreamNestThemeMode {
        guard let raw = defaults.string(forKey: Keys.themeMode),
              let mode = DreamNestThemeMode(rawValue: raw) else {
            return .night
        }
        return mode
    }

    func save(_ mode: DreamNestThemeMode) {
        defaults.set(mode.rawValue, forKey: Keys.themeMode)
    }
}

