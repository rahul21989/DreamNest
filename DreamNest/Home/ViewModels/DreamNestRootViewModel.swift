import Foundation
import Combine

@MainActor
public final class DreamNestRootViewModel: ObservableObject {
    @Published public private(set) var audioLibrary: AudioLibrary

    @Published public private(set) var routines: [Routine]
    @Published public private(set) var parentsSettings: ParentsSettings

    @Published public private(set) var nowPlayingViewModel: NowPlayingViewModel

    @Published public private(set) var favoriteTrackFilenames: Set<String> = []

    private let routineStore: RoutineStore
    private let settingsStore: ParentsSettingsStore
    private let favoritesStore: FavoritesStore

    public init(
        audioLibraryService: AudioLibraryService = AudioLibraryService(),
        routineStore: RoutineStore = RoutineStore(),
        settingsStore: ParentsSettingsStore = ParentsSettingsStore(),
        favoritesStore: FavoritesStore = FavoritesStore()
    ) {
        self.routineStore = routineStore
        self.settingsStore = settingsStore
        self.favoritesStore = favoritesStore

        let library = audioLibraryService.scanAllAudio()
        self.audioLibrary = library
        self.nowPlayingViewModel = NowPlayingViewModel(library: library)

        self.routines = routineStore.routines.sorted { $0.updatedAt > $1.updatedAt }
        self.parentsSettings = settingsStore.settings

        self.favoriteTrackFilenames = favoritesStore.loadFavoriteTracks()
    }

    /// Re-scan bundled + user audio and update the UI/player.
    /// Call this after importing or recording new lullabies.
    public func refreshAudioLibrary() {
        let library = AudioLibraryService().scanAllAudio()
        audioLibrary = library
        nowPlayingViewModel.updateLibrary(library)
    }

    public var categories: [AudioCategory] {
        audioLibrary.categories.sorted { $0.displayName < $1.displayName }
    }

    public func tracks(in category: AudioCategory) -> [AudioTrack] {
        audioLibrary.tracksByCategory[category.id] ?? []
    }

    public func upsertRoutine(_ routine: Routine) {
        routineStore.addOrUpdate(routine)
        routines = routineStore.routines.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func deleteRoutine(id: UUID) {
        routineStore.delete(id)
        routines = routineStore.routines.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func updateParentsSettings(_ newSettings: ParentsSettings) {
        settingsStore.update(newSettings)
        parentsSettings = newSettings
    }

    public func logoutLocalDataAndStopPlayback() {
        nowPlayingViewModel.stopAllPlaybackAndTimers()

        routineStore.clear()
        settingsStore.resetToDefaults()
        favoritesStore.clear()

        routines = routineStore.routines.sorted { $0.updatedAt > $1.updatedAt }
        parentsSettings = settingsStore.settings
        favoriteTrackFilenames = favoritesStore.loadFavoriteTracks()
    }

    public func isFavorite(_ trackFilename: String) -> Bool {
        favoriteTrackFilenames.contains(trackFilename)
    }

    public func toggleFavorite(_ trackFilename: String) {
        var next = favoriteTrackFilenames
        if next.contains(trackFilename) {
            next.remove(trackFilename)
        } else {
            next.insert(trackFilename)
        }
        favoriteTrackFilenames = next
        favoritesStore.setFavoriteTracks(next)
    }
}

