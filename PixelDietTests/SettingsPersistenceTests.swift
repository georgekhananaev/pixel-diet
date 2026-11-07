import Testing
import Foundation
@testable import PixelDiet

// MARK: - Test Support

/// In-memory bookmark store; `resolve()` returns whatever was saved last.
final class FakeBookmarkStore: BookmarkStoring {
    var saved: URL?

    init(saved: URL? = nil) {
        self.saved = saved
    }

    func save(_ url: URL) throws {
        saved = url
    }

    func resolve() -> URL? {
        saved
    }
}

/// Settings persistence that lives only as long as the test.
final class InMemorySettingsStore: SettingsStoring {
    private(set) var saved: SettingsData?

    init(saved: SettingsData? = nil) {
        self.saved = saved
    }

    func save(_ settings: SettingsData) throws {
        saved = settings
    }

    func load() -> SettingsData? {
        saved
    }
}

/// UserDefaults that keeps values in memory only, so tests leave no preference files behind
/// (a removed UserDefaults suite still leaves an empty plist in the app's container).
final class InMemoryDefaults: UserDefaults, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Any] = [:]

    override func object(forKey defaultName: String) -> Any? {
        lock.withLock { values[defaultName] }
    }

    override func data(forKey defaultName: String) -> Data? {
        object(forKey: defaultName) as? Data
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        lock.withLock { values[defaultName] = value }
    }

    override func removeObject(forKey defaultName: String) {
        lock.withLock { values[defaultName] = nil }
    }
}

@MainActor
enum TestSettings {
    /// Settings backed by in-memory storage so tests never touch real preferences.
    static func make(
        store: InMemorySettingsStore = InMemorySettingsStore(),
        bookmarks: FakeBookmarkStore = FakeBookmarkStore()
    ) -> CompressionSettings {
        CompressionSettings(store: store, bookmarks: bookmarks)
    }

    /// Runs `body` with empty, in-memory UserDefaults.
    static func withScratchDefaults<T>(_ body: (UserDefaults) throws -> T) rethrows -> T {
        try body(InMemoryDefaults())
    }
}

// MARK: - Settings Persistence Tests

@MainActor
struct SettingsPersistenceTests {
    @Test func settingsPersistAcrossInstances() {
        let store = InMemorySettingsStore()
        let first = TestSettings.make(store: store)
        first.outputFormat = .webp
        first.setQuality(65)
        first.setMaxDimension(2560)
        first.stripMetadata = false
        first.skipIfLarger = false
        first.preserveDirectoryStructure = true

        let second = TestSettings.make(store: store)
        #expect(second.outputFormat == .webp)
        #expect(second.quality == 65)
        #expect(second.maxDimension == 2560)
        #expect(second.stripMetadata == false)
        #expect(second.skipIfLarger == false)
        #expect(second.preserveDirectoryStructure == true)
    }

    @Test func invalidStoredValuesAreClampedOnLoad() {
        let settings = TestSettings.make(store: InMemorySettingsStore(saved: SettingsData(quality: 500, maxDimension: 5)))
        #expect(settings.quality == 100)
        #expect(settings.maxDimension == 64)
    }

    @Test func unknownFormatFallsBackToDefault() {
        let settings = TestSettings.make(store: InMemorySettingsStore(saved: SettingsData(outputFormat: "targa")))
        #expect(settings.outputFormat == .jpeg)
    }

    @Test func outputFolderRestoredFromBookmark() {
        let folder = URL(fileURLWithPath: "/tmp/pixeldiet-output", isDirectory: true)
        let settings = TestSettings.make(bookmarks: FakeBookmarkStore(saved: folder))
        #expect(settings.outputDirectory == folder)
    }

    @Test func choosingOutputFolderSavesBookmark() {
        let bookmarks = FakeBookmarkStore()
        let settings = TestSettings.make(bookmarks: bookmarks)
        let folder = URL(fileURLWithPath: "/tmp/pixeldiet-chosen", isDirectory: true)

        settings.chooseOutputDirectory(folder)

        #expect(settings.outputDirectory == folder)
        #expect(bookmarks.saved == folder)
    }

    @Test func bookmarkRoundTrip() throws {
        let folder = try TestImages.makeDirectory()
        try TestSettings.withScratchDefaults { defaults in
            let manager = BookmarkManager(defaults: defaults)

            try manager.save(folder)
            let resolved = try #require(manager.resolve())
            defer { resolved.stopAccessingSecurityScopedResource() }

            #expect(resolved.standardizedFileURL.resolvingSymlinksInPath() == folder.standardizedFileURL.resolvingSymlinksInPath())
        }
    }

    @Test func legacyBookmarkFromVersionOneIsDiscarded() throws {
        // 1.0.0 stored bookmarks of dropped *input* files and folders under this key
        let legacyKey = "com.georgekhananaev.PixelDiet.outputBookmark"
        let inputFolder = try TestImages.makeDirectory()
        try TestSettings.withScratchDefaults { defaults in
            defaults.set(try inputFolder.bookmarkData(options: .withSecurityScope), forKey: legacyKey)

            #expect(BookmarkManager(defaults: defaults).resolve() == nil)
            #expect(defaults.data(forKey: legacyKey) == nil)
        }
    }

    @Test func bookmarkToAFileIsRejected() throws {
        let dir = try TestImages.makeDirectory()
        let file = dir.appendingPathComponent("photo.png")
        try Data("x".utf8).write(to: file)
        try TestSettings.withScratchDefaults { defaults in
            let manager = BookmarkManager(defaults: defaults)

            try manager.save(file)

            #expect(manager.resolve() == nil)
        }
    }

    @Test func missingBookmarkResolvesToNil() {
        TestSettings.withScratchDefaults { defaults in
            #expect(BookmarkManager(defaults: defaults).resolve() == nil)
        }
    }
}
