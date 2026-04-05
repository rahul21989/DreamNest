import Foundation

public final class RoutineStore: @unchecked Sendable {
    private enum Keys {
        static let routines = "dn_routines_v1"
        static let routinesUpdatedAt = "dn_routines_updated_at_v1"
    }

    private let defaults: UserDefaults

    public private(set) var routines: [Routine]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.routines = Self.load(from: defaults) ?? []
    }

    public func reload() {
        routines = Self.load(from: defaults) ?? []
    }

    public func addOrUpdate(_ routine: Routine) {
        if let idx = routines.firstIndex(where: { $0.id == routine.id }) {
            routines[idx] = routine
        } else {
            routines.append(routine)
        }
        save()
    }

    public func delete(_ routineID: UUID) {
        routines.removeAll { $0.id == routineID }
        save()
    }

    public func clear() {
        routines = []
        defaults.removeObject(forKey: Keys.routines)
        defaults.removeObject(forKey: Keys.routinesUpdatedAt)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(routines) else { return }
        defaults.set(data, forKey: Keys.routines)
        defaults.set(Date(), forKey: Keys.routinesUpdatedAt)
    }

    private static func load(from defaults: UserDefaults) -> [Routine]? {
        guard let data = defaults.data(forKey: Keys.routines) else { return nil }
        return try? JSONDecoder().decode([Routine].self, from: data)
    }
}

