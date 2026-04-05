import Foundation
import AVFoundation

import class AVFoundation.AVAudioPlayer

public struct AudioLibrary: Sendable {
    public let categories: [AudioCategory]
    public let tracks: [AudioTrack]

    public var tracksByCategory: [String: [AudioTrack]] {
        Dictionary(grouping: tracks, by: { $0.category })
    }
}

public final class AudioLibraryService: Sendable {
    public init() {}

    private static let supportedExtensions: Set<String> = ["mp3", "m4a"]
    private static let userAudioRootFolderName = "DreamNestUserAudio"

    public func scanBundledAudio() -> AudioLibrary {
        let bundle = Bundle.main
        guard let resourceRoot = bundle.resourceURL else {
            return AudioLibrary(categories: [], tracks: [])
        }
        let resourceRootPath = resourceRoot.path.hasSuffix("/") ? resourceRoot.path : resourceRoot.path + "/"

        let audioURLs: [URL] = {
            let fm = FileManager.default
            guard let enumerator = fm.enumerator(
                at: resourceRoot,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                return []
            }

            var urls: [URL] = []
            for case let fileURL as URL in enumerator {
                if Self.supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                    urls.append(fileURL)
                }
            }
            return urls
        }()

        if audioURLs.isEmpty {
            return AudioLibrary(categories: [], tracks: [])
        }

        let parsedTracks: [AudioTrack] = audioURLs.compactMap { url in
            let filename = url.lastPathComponent
            let base = url.deletingPathExtension().lastPathComponent

            // Compute resource subdirectory relative to the bundle root:
            // - If the file is at `<bundle>/Audio/foo.mp3`, returns `Audio`
            // - If it is at `<bundle>/Resources/Audio/foo.mp3`, returns `Resources/Audio`
            let parentDir = url.deletingLastPathComponent().path
            let relativeParent = parentDir.hasPrefix(resourceRootPath)
                ? String(parentDir.dropFirst(resourceRootPath.count))
                : ""

            // Expected naming convention:
            //   CategoryKey__Title__anything-else?.mp3
            // We use first "__" as category separator.
            let parts = base.split(separator: "__", omittingEmptySubsequences: true)
            let categoryKey: String = parts.count >= 2 ? String(parts[0]) : "Lullabies"
            let titleRaw: String = parts.count >= 2 ? String(parts[1]) : String(base)
            let title = titleRaw
                .replacingOccurrences(of: "_", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .capitalized

            let duration = Self.durationSeconds(for: url)
            return AudioTrack(
                id: filename,
                title: title.isEmpty ? "Unknown" : title,
                category: categoryKey,
                durationSeconds: duration,
                filename: filename,
                bundleSubdirectory: relativeParent
            )
        }

        let sortedTracks = parsedTracks.sorted {
            if $0.category != $1.category { return $0.category < $1.category }
            return $0.title < $1.title
        }

        let categoryKeys = Array(Set(sortedTracks.map { $0.category })).sorted()
        let categories = categoryKeys.map { AudioCategory(id: $0) }

        return AudioLibrary(categories: categories, tracks: sortedTracks)
    }

    /// Scan user-created audio in Documents and treat them as normal tracks.
    public func scanUserAudio() -> AudioLibrary {
        guard let docsRoot = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return AudioLibrary(categories: [], tracks: [])
        }

        let userRoot = docsRoot.appendingPathComponent(Self.userAudioRootFolderName, isDirectory: true)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: userRoot.path, isDirectory: &isDir), isDir.boolValue else {
            return AudioLibrary(categories: [], tracks: [])
        }

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: userRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return AudioLibrary(categories: [], tracks: [])
        }

        var tracks: [AudioTrack] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.isFileURL else { continue }
            let ext = fileURL.pathExtension.lowercased()
            guard Self.supportedExtensions.contains(ext) else { continue }

            let filename = fileURL.lastPathComponent
            let base = fileURL.deletingPathExtension().lastPathComponent

            let parts = base.split(separator: "__", omittingEmptySubsequences: true)
            let categoryKey: String = parts.count >= 2 ? String(parts[0]) : "Lullabies"
            let titleRaw: String = parts.count >= 2 ? String(parts[1]) : String(base)
            let title = titleRaw
                .replacingOccurrences(of: "_", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .capitalized

            // Compute relative path under Documents for later playback.
            let docsRelativePath = fileURL.path.replacingOccurrences(of: (docsRoot.path + "/"), with: "")

            let duration = Self.durationSeconds(for: fileURL)
            tracks.append(
                AudioTrack(
                    id: filename,
                    title: title.isEmpty ? "Unknown" : title,
                    category: categoryKey,
                    durationSeconds: duration,
                    filename: filename,
                    bundleSubdirectory: "",
                    documentsRelativePath: docsRelativePath
                )
            )
        }

        let sortedTracks = tracks.sorted {
            if $0.category != $1.category { return $0.category < $1.category }
            return $0.title < $1.title
        }

        let categoryKeys = Array(Set(sortedTracks.map { $0.category })).sorted()
        let categories = categoryKeys.map { AudioCategory(id: $0) }
        return AudioLibrary(categories: categories, tracks: sortedTracks)
    }

    /// Bundled + user audio.
    public func scanAllAudio() -> AudioLibrary {
        let bundled = scanBundledAudio()
        let user = scanUserAudio()

        let allTracks = bundled.tracks + user.tracks
        let categoryKeys = Array(Set(allTracks.map { $0.category })).sorted()
        let categories = categoryKeys.map { AudioCategory(id: $0) }

        return AudioLibrary(categories: categories, tracks: allTracks)
    }

    private static func durationSeconds(for url: URL) -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let seconds = asset.duration.seconds
        if seconds.isFinite, seconds > 0 {
            return seconds
        }

        // Fallback: AVAudioPlayer sometimes yields a usable duration where AVURLAsset does not.
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            let fallback = player.duration
            if fallback.isFinite, fallback > 0 { return fallback }
        } catch {
            // Ignore: return 0 and let UI handle unknown durations.
        }

        return 0
    }
}

