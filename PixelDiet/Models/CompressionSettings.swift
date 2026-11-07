import Foundation
import Observation
import os

/// User-adjustable compression settings. Every change is persisted, and the
/// output folder is restored from its security-scoped bookmark on launch.
@Observable
class CompressionSettings {
    var outputFormat: ImageFormat = .jpeg { didSet { persist() } }

    /// Quality: 10-100. Use setQuality() for clamped setting.
    var quality: Int = Constants.defaultQuality { didSet { persist() } }

    /// Max longest edge in pixels. 0 = no resize. Use setMaxDimension() for clamped setting.
    var maxDimension: Int = Constants.defaultMaxDimension { didSet { persist() } }

    var preserveDirectoryStructure: Bool = false { didSet { persist() } }
    var stripMetadata: Bool = true { didSet { persist() } }
    var skipIfLarger: Bool = true { didSet { persist() } }
    private(set) var outputDirectory: URL?

    @ObservationIgnored private let store: any SettingsStoring
    @ObservationIgnored private let bookmarks: any BookmarkStoring
    /// Folder resolved from a bookmark, whose security-scoped access we started
    @ObservationIgnored private var bookmarkedDirectory: URL?
    @ObservationIgnored private var isRestoring = false

    init(store: any SettingsStoring = SettingsStore(), bookmarks: any BookmarkStoring = BookmarkManager()) {
        self.store = store
        self.bookmarks = bookmarks
        restore()
    }

    /// Set quality with clamping to valid range
    func setQuality(_ value: Int) {
        quality = value.clamped(to: Constants.qualityRange)
    }

    /// Set maxDimension with clamping to valid range (0 = no resize)
    func setMaxDimension(_ value: Int) {
        maxDimension = value == 0 ? 0 : value.clamped(to: Constants.maxDimensionRange)
    }

    /// Use a folder the user just picked, and remember it across launches.
    func chooseOutputDirectory(_ url: URL) {
        bookmarkedDirectory?.stopAccessingSecurityScopedResource()
        bookmarkedDirectory = nil
        outputDirectory = url
        do {
            try bookmarks.save(url)
        } catch {
            Logger.fileAccess.error("Failed to save output folder bookmark: \(error.localizedDescription)")
        }
    }

    /// Create a Sendable snapshot for actor boundary crossing.
    /// Returns nil while no output directory is selected.
    func snapshot() -> SettingsSnapshot? {
        guard let outputDirectory else { return nil }
        return SettingsSnapshot(
            outputFormat: outputFormat,
            quality: quality,
            maxDimension: maxDimension,
            preserveDirectoryStructure: preserveDirectoryStructure,
            stripMetadata: stripMetadata,
            skipIfLarger: skipIfLarger,
            outputDirectory: outputDirectory
        )
    }

    // MARK: - Persistence

    private func restore() {
        isRestoring = true
        defer { isRestoring = false }

        if let data = store.load() {
            if let format = ImageFormat(rawValue: data.outputFormat), ImageFormat.availableOutputFormats.contains(format) {
                outputFormat = format
            }
            setQuality(data.quality)
            setMaxDimension(data.maxDimension)
            preserveDirectoryStructure = data.preserveDirectoryStructure
            stripMetadata = data.stripMetadata
            skipIfLarger = data.skipIfLarger
        }

        if let url = bookmarks.resolve() {
            bookmarkedDirectory = url
            outputDirectory = url
        }
    }

    private func persist() {
        guard !isRestoring else { return }
        let data = SettingsData(
            outputFormat: outputFormat.rawValue,
            quality: quality,
            maxDimension: maxDimension,
            preserveDirectoryStructure: preserveDirectoryStructure,
            stripMetadata: stripMetadata,
            skipIfLarger: skipIfLarger
        )
        do {
            try store.save(data)
        } catch {
            Logger.fileAccess.error("Failed to save settings: \(error.localizedDescription)")
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
