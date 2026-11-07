import Foundation

extension FileManager {
    /// Recursively find all supported image files in a directory.
    /// Skips symlinks, aliases, hidden files, and package contents.
    ///
    /// CRITICAL: Must be `nonisolated` - called from TaskGroup child tasks in
    /// MainViewModel.addFiles(). Without this, directory discovery serializes
    /// on MainActor under Swift 6.2 default isolation. (Round 3 Fix)
    nonisolated func findImages(in directory: URL) -> [URL] {
        let supportedExtensions = ImageFormat.allInputExtensions
        let analyzer = ImageAnalyzer()
        var results: [URL] = []

        guard let enumerator = self.enumerator(
            at: directory,
            includingPropertiesForKeys: [
                .fileSizeKey, .isRegularFileKey,
                .isSymbolicLinkKey, .isAliasFileKey
            ],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(
                forKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey, .isAliasFileKey]
            ) else { continue }

            // Skip symlinks
            if values.isSymbolicLink == true { continue }

            // Skip macOS Finder aliases
            if values.isAliasFile == true { continue }

            guard values.isRegularFile == true else { continue }

            // Skip zero-byte files
            let fileSize = values.fileSize ?? 0
            guard fileSize > 0 else { continue }

            let ext = url.pathExtension.lowercased()
            if supportedExtensions.contains(ext) {
                results.append(url)
            } else if ext.isEmpty, analyzer.sniffFormat(url: url) != nil {
                // No extension - content-based sniffing confirmed it's an image
                results.append(url)
            }
        }

        return results
    }

    /// Whether a file can be created in `directory`, found by creating and removing a hidden
    /// one: permission checks can be wrong on network volumes. A crash in between leaves a
    /// temp file that `TempFileSweeper` removes later.
    nonisolated func canCreateFiles(in directory: URL) -> Bool {
        let probe = directory.appendingPathComponent("\(TempFileSweeper.prefix)\(UUID().uuidString)")
        guard createFile(atPath: probe.path, contents: nil) else { return false }
        try? removeItem(at: probe)
        return true
    }
}
