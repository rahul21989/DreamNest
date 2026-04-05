import Foundation

public final class ParentsSettingsStore: @unchecked Sendable {
    private enum Keys {
        static let settings = "dn_parents_settings_v1"
    }

    static let allowedQuickSleepMinutes: [Int] = [1, 2, 5, 10, 15]

    private let defaults: UserDefaults

    public private(set) var settings: ParentsSettings

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.settings = (Self.load(from: defaults) ?? ParentsSettings()).clampedQuickSleepMinutes()
    }

    public func update(_ newSettings: ParentsSettings) {
        settings = newSettings.clampedQuickSleepMinutes()
        save()
    }

    public func resetToDefaults() {
        settings = ParentsSettings()
        defaults.removeObject(forKey: Keys.settings)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Keys.settings)
    }

    private static func load(from defaults: UserDefaults) -> ParentsSettings? {
        guard let data = defaults.data(forKey: Keys.settings) else { return nil }
        return try? JSONDecoder().decode(ParentsSettings.self, from: data)
    }
}

private extension ParentsSettings {
    func clampedQuickSleepMinutes() -> ParentsSettings {
        let allowed = ParentsSettingsStore.allowedQuickSleepMinutes
        guard !allowed.isEmpty else { return self }

        if allowed.contains(defaultSleepTimerMinutes) {
            return self
        }

        // Pick the closest allowed value (absolute difference).
        let closest = allowed.min(by: { abs($0 - defaultSleepTimerMinutes) < abs($1 - defaultSleepTimerMinutes) }) ?? self.defaultSleepTimerMinutes
        return ParentsSettings(defaultSleepTimerMinutes: closest, fadeOutSeconds: fadeOutSeconds)
    }
}

