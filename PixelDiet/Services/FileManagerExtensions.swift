import Foundation
import os

private let logger = Logger(subsystem: "com.georgekhananaev.PixelDiet", category: "fileAccess")

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

    /// Calculate total size of files at URLs
    func totalSize(of urls: [URL]) -> Int64 {
        urls.reduce(0) { total, url in
            do {
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                return total + Int64(size)
            } catch {
                logger.warning("Failed to read file size for \(url.lastPathComponent): \(error.localizedDescription)")
                return total
            }
        }
    }

    /// Check available disk space at a path
    func availableDiskSpace(at url: URL) -> Int64? {
        do {
            let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return values.volumeAvailableCapacityForImportantUsage
        } catch {
            logger.warning("Failed to check disk space at \(url.path): \(error.localizedDescription)")
            return nil
        }
    }

    /// Test if a directory is writable by creating and removing a temp file
    func isDirectoryWritable(_ url: URL) -> Bool {
        let testFile = url.appendingPathComponent(".pixeldiet-write-test-\(UUID().uuidString)")
        do {
            try Data().write(to: testFile)
            try removeItem(at: testFile)
            return true
        } catch {
            return false
        }
    }
}
