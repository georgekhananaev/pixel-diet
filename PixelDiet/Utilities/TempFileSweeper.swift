import Foundation

/// Removes hidden `.pixeldiet-*` temp files that a crash or forced quit left next to
/// earlier outputs. Each image is written to such a file and then moved into place.
nonisolated enum TempFileSweeper {
    static let prefix = ".pixeldiet-"

    /// Deletes temp files older than `age` in `directories` (not recursive). Younger files
    /// may belong to another running copy of the app and are left alone.
    static func removeStaleFiles(in directories: Set<URL>, olderThan age: TimeInterval = 3600, now: Date = Date()) {
        let fileManager = FileManager.default
        for directory in directories {
            guard let names = try? fileManager.contentsOfDirectory(atPath: directory.path) else { continue }
            for name in names where name.hasPrefix(prefix) {
                let url = directory.appendingPathComponent(name)
                guard let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                      now.timeIntervalSince(modified) > age else { continue }
                try? fileManager.removeItem(at: url)
            }
        }
    }
}
