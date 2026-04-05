import Foundation

public final class FavoritesStore: @unchecked Sendable {
    private enum Keys {
        static let favoriteTracks = "dn_favorite_tracks_v1"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadFavoriteTracks() -> Set<String> {
        guard let arr = defaults.array(forKey: Keys.favoriteTracks) as? [String] else {
            return []
        }
        return Set(arr)
    }

    public func setFavoriteTracks(_ favorites: Set<String>) {
        defaults.set(Array(favorites), forKey: Keys.favoriteTracks)
    }

    public func clear() {
        defaults.removeObject(forKey: Keys.favoriteTracks)
    }
}

