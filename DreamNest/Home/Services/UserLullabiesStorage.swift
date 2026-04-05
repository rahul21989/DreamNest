import Foundation
import AVFoundation

enum UserLullabiesStorageError: LocalizedError {
    case unsupportedFormat
    case missingDocumentsFolder
    case copyFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Unsupported audio format. Please choose an MP3 or M4A file."
        case .missingDocumentsFolder:
            return "Could not access app Documents folder."
        case .copyFailed:
            return "Could not save the lullaby to this device."
        }
    }
}

/// Handles saving/importing/recording lullabies into the app's Documents directory.
enum UserLullabiesStorage {
    private static let userAudioRootFolderName = "DreamNestUserAudio"
    private static let lullabiesSubfolderName = "Lullabies"

    private static let allowedExtensions: Set<String> = ["mp3", "m4a"]

    private static func docsRootURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    private static func userAudioRootURL() -> URL? {
        docsRootURL()?.appendingPathComponent(userAudioRootFolderName, isDirectory: true)
    }

    private static func lullabiesFolderURL() -> URL? {
        userAudioRootURL()?.appendingPathComponent(lullabiesSubfolderName, isDirectory: true)
    }

    private static func ensureFolders() throws {
        guard let lullabiesURL = lullabiesFolderURL() else { throw UserLullabiesStorageError.missingDocumentsFolder }
        if !FileManager.default.fileExists(atPath: lullabiesURL.path) {
            try FileManager.default.createDirectory(at: lullabiesURL, withIntermediateDirectories: true)
        }
    }

    private static func sanitizedTitleSegment(_ raw: String) -> String {
        // Keep it stable and filename-friendly.
        let replaced = raw
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
        let allowed = replaced.filter { $0.isLetter || $0.isNumber || $0 == "_" }
        let trimmed = String(allowed).trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Lullaby" : trimmed
    }

    private static func parseTitleForDisplay(fromBase base: String) -> String {
        // Expected: Lullabies__TitleSegment__AnythingElse?.ext
        let parts = base.split(separator: "__", omittingEmptySubsequences: true)
        let titleRaw: String
        if parts.count >= 2 {
            titleRaw = String(parts[1])
        } else {
            titleRaw = base
        }

        return titleRaw
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .capitalized
    }

    private static func documentsRelativePath(for url: URL) -> String {
        guard let docsRoot = docsRootURL() else { return url.lastPathComponent }
        let prefix = docsRoot.path + "/"
        if url.path.hasPrefix(prefix) {
            return String(url.path.dropFirst(prefix.count))
        }
        return url.lastPathComponent
    }

    private static func durationSeconds(for url: URL) -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let seconds = asset.duration.seconds
        if seconds.isFinite, seconds > 0 { return seconds }

        // Fallback best-effort.
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            let fallback = player.duration
            if fallback.isFinite, fallback > 0 { return fallback }
        } catch {
            // Ignore and return 0
        }
        return 0
    }

    /// Copies an imported MP3/M4A file into Documents and returns an `AudioTrack` representing it.
    static func importLullaby(from sourceURL: URL) throws -> AudioTrack {
        try ensureFolders()
        let ext = sourceURL.pathExtension.lowercased()
        guard allowedExtensions.contains(ext) else { throw UserLullabiesStorageError.unsupportedFormat }

        let base = sourceURL.deletingPathExtension().lastPathComponent

        let parts = base.split(separator: "__", omittingEmptySubsequences: true)
        let rawTitleSegment = parts.count >= 2 ? String(parts[1]) : base

        let titleDisplay = parseTitleForDisplay(fromBase: base)
        let safeTitleSegment = sanitizedTitleSegment(rawTitleSegment)
        let unique = UUID().uuidString.prefix(8)

        let filename = "Lullabies__\(safeTitleSegment)__\(unique).\(ext)"
        guard let destURL = lullabiesFolderURL()?.appendingPathComponent(filename) else {
            throw UserLullabiesStorageError.missingDocumentsFolder
        }

        // If collision, generate a different UUID-suffix.
        if FileManager.default.fileExists(atPath: destURL.path) {
            let unique2 = UUID().uuidString.prefix(8)
            let filename2 = "Lullabies__\(safeTitleSegment)__\(unique2).\(ext)"
            guard let destURL2 = lullabiesFolderURL()?.appendingPathComponent(filename2) else {
                throw UserLullabiesStorageError.copyFailed
            }
            try FileManager.default.copyItem(at: sourceURL, to: destURL2)
            let docsRelative = documentsRelativePath(for: destURL2)
            let duration = durationSeconds(for: destURL2)
            return AudioTrack(
                id: filename2,
                title: titleDisplay,
                category: "Lullabies",
                durationSeconds: duration,
                filename: filename2,
                bundleSubdirectory: "",
                documentsRelativePath: docsRelative
            )
        }

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
        } catch {
            throw UserLullabiesStorageError.copyFailed
        }

        let docsRelative = documentsRelativePath(for: destURL)
        let duration = durationSeconds(for: destURL)
        return AudioTrack(
            id: filename,
            title: titleDisplay,
            category: "Lullabies",
            durationSeconds: duration,
            filename: filename,
            bundleSubdirectory: "",
            documentsRelativePath: docsRelative
        )
    }

    /// Saves a recorded audio file from a temporary location into Documents.
    static func saveRecordedLullaby(from tempURL: URL) throws -> AudioTrack {
        // For recordings we always store as m4a.
        try ensureFolders()
        let ext = tempURL.pathExtension.lowercased()
        guard ["m4a", "mp3"].contains(ext) else {
            throw UserLullabiesStorageError.unsupportedFormat
        }

        let titleDisplay = "Voice"
        let safeTitleSegment = "Voice"
        let unique = UUID().uuidString.prefix(8)
        let filename = "Lullabies__\(safeTitleSegment)__\(unique).m4a"

        guard let destURL = lullabiesFolderURL()?.appendingPathComponent(filename) else {
            throw UserLullabiesStorageError.missingDocumentsFolder
        }

        // If temp is already m4a, copy. If it's mp3, best effort copy anyway; AVAudioPlayer may still play it.
        do {
            try FileManager.default.copyItem(at: tempURL, to: destURL)
        } catch {
            throw UserLullabiesStorageError.copyFailed
        }

        let docsRelative = documentsRelativePath(for: destURL)
        let duration = durationSeconds(for: destURL)
        return AudioTrack(
            id: filename,
            title: titleDisplay,
            category: "Lullabies",
            durationSeconds: duration,
            filename: filename,
            bundleSubdirectory: "",
            documentsRelativePath: docsRelative
        )
    }
}

