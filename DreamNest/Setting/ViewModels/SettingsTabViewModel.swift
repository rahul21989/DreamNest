import Foundation
import Combine

@MainActor
final class SettingsTabViewModel: ObservableObject {
    @Published private(set) var appVersionString: String = "—"

    init() {
        appVersionString = Self.readAppVersion()
    }

    private static func readAppVersion() -> String {
        let bundle = Bundle.main
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String
        if let version, let build {
            return "\(version) (\(build))"
        }
        return version ?? "—"
    }
}

