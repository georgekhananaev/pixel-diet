import Foundation

struct BookmarkManager {
    private static let bookmarkKey = "com.georgekhananaev.PixelDiet.outputBookmark"

    /// Save a security-scoped bookmark for a user-selected directory
    static func saveBookmark(for url: URL) throws {
        let data = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(data, forKey: bookmarkKey)
    }

    /// Resolve a saved bookmark. Returns URL with access started.
    /// Caller MUST call stopAccessingSecurityScopedResource() when done.
    static func resolveBookmark() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }

        if isStale {
            // Bookmark is stale — user needs to re-select folder
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
            return nil
        }

        guard url.startAccessingSecurityScopedResource() else { return nil }
        return url
    }

    /// Stop accessing a security-scoped resource
    static func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}
