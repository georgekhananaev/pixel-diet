import Foundation

protocol BookmarkStoring {
    func save(_ url: URL) throws
    /// Resolves the saved folder and starts security-scoped access.
    /// Returns nil when nothing is saved or the bookmark can no longer be used.
    func resolve() -> URL?
}

struct BookmarkManager: BookmarkStoring {
    private let defaults: UserDefaults
    private let bookmarkKey = "com.georgekhananaev.PixelDiet.outputFolderBookmark"
    /// 1.0.0 stored bookmarks of dropped *input* files and folders under this key; never reuse it
    private let legacyBookmarkKey = "com.georgekhananaev.PixelDiet.outputBookmark"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Save a security-scoped bookmark for a user-selected directory
    func save(_ url: URL) throws {
        let data = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        defaults.set(data, forKey: bookmarkKey)
    }

    func resolve() -> URL? {
        defaults.removeObject(forKey: legacyBookmarkKey)
        guard let data = defaults.data(forKey: bookmarkKey) else { return nil }

        var isStale = false
        // Runs at launch: never show UI or mount a network volume to find the folder
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope, .withoutUI, .withoutMounting],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }

        guard url.startAccessingSecurityScopedResource() else {
            // Access failed - bookmark is unusable, clear it
            defaults.removeObject(forKey: bookmarkKey)
            return nil
        }

        // Only a folder can be the output folder
        guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
            url.stopAccessingSecurityScopedResource()
            defaults.removeObject(forKey: bookmarkKey)
            return nil
        }

        // The folder was moved or renamed: refresh the bookmark while we have access
        if isStale {
            try? save(url)
        }
        return url
    }
}
