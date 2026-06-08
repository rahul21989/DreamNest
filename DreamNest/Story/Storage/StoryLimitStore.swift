import Foundation

/// Tracks how many stories a user has generated today.
/// Resets automatically at midnight. Stored in UserDefaults.
struct StoryLimitStore {

    static let dailyLimit = 3

    private static let countKey = "dn_story_daily_count"
    private static let dateKey  = "dn_story_daily_date"

    // MARK: - Public API

    /// Stories generated today (0 … dailyLimit).
    static var todayCount: Int {
        ensureFreshDay()
        return UserDefaults.standard.integer(forKey: countKey)
    }

    /// True when the user has hit today's limit.
    static var hasReachedLimit: Bool {
        todayCount >= dailyLimit
    }

    /// Remaining stories for today.
    static var remaining: Int {
        max(0, dailyLimit - todayCount)
    }

    /// Call this after a story is successfully generated.
    static func increment() {
        ensureFreshDay()
        let next = UserDefaults.standard.integer(forKey: countKey) + 1
        UserDefaults.standard.set(next, forKey: countKey)
    }

    // MARK: - Private

    /// Resets the counter if the stored date is not today.
    private static func ensureFreshDay() {
        let today = todayString()
        let stored = UserDefaults.standard.string(forKey: dateKey) ?? ""
        if stored != today {
            UserDefaults.standard.set(0,     forKey: countKey)
            UserDefaults.standard.set(today, forKey: dateKey)
        }
    }

    private static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }
}
