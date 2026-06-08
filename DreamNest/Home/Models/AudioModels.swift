import Foundation

public struct AudioCategory: Identifiable, Hashable, Sendable {
    public let id: String // category key
    public let displayName: String

    public init(id: String, displayName: String? = nil) {
        self.id = id
        self.displayName = displayName ?? id.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

public struct AudioTrack: Identifiable, Hashable, Sendable {
    public let id: String // filename without path (including extension)
    public let title: String
    public let category: String // category key
    public let durationSeconds: TimeInterval
    public let filename: String // e.g. "lullabies__twinkle_twinkle.mp3"
    public let bundleSubdirectory: String // relative to app bundle root (e.g. "Audio" or "Resources/Audio")
    /// If non-nil, this track is stored in the app's Documents directory at this relative path.
    public let documentsRelativePath: String?
    /// Recording creation date — populated for user-created tracks only.
    public let createdAt: Date?

    public init(
        id: String,
        title: String,
        category: String,
        durationSeconds: TimeInterval,
        filename: String,
        bundleSubdirectory: String = "Audio",
        documentsRelativePath: String? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.durationSeconds = durationSeconds
        self.filename = filename
        self.bundleSubdirectory = bundleSubdirectory
        self.documentsRelativePath = documentsRelativePath
        self.createdAt = createdAt
    }

    public var isUserCreated: Bool { documentsRelativePath != nil }

    public func fileURL(in bundle: Bundle = .main) -> URL? {
        if let documentsRelativePath {
            let docsRoot = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            return docsRoot?.appendingPathComponent(documentsRelativePath)
        }

        let resourceName = NSString(string: filename).deletingPathExtension
        let ext = NSString(string: filename).pathExtension
        let sub = bundleSubdirectory.isEmpty ? nil : bundleSubdirectory
        return bundle.url(forResource: resourceName, withExtension: ext, subdirectory: sub)
    }
}
