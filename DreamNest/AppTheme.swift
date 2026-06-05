import SwiftUI

public enum DreamNestThemeMode: String, CaseIterable, Identifiable {
    case night
    case system

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .night: return "Night"
        case .system: return "System"
        }
    }
}

private struct DreamNestThemeModeKey: EnvironmentKey {
    static let defaultValue: DreamNestThemeMode = .night
}

extension EnvironmentValues {
    var dreamNestThemeMode: DreamNestThemeMode {
        get { self[DreamNestThemeModeKey.self] }
        set { self[DreamNestThemeModeKey.self] = newValue }
    }
}

struct DreamNestNightMode: ViewModifier {
    func body(content: Content) -> some View {
        content.preferredColorScheme(.dark)
    }
}

extension View {
    func dreamNestNightMode() -> some View {
        modifier(DreamNestNightMode())
    }
}

