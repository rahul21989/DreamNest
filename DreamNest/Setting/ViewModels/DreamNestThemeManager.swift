import Foundation
import Combine

@MainActor
final class DreamNestThemeManager: ObservableObject {
    @Published var themeMode: DreamNestThemeMode {
        didSet { store.save(themeMode) }
    }

    private let store: ThemeStore

    init(store: ThemeStore = ThemeStore()) {
        self.store = store
        self.themeMode = store.load()
    }
}

