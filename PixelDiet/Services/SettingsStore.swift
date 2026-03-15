import Foundation

protocol SettingsStoring {
    func save(_ settings: SettingsData) throws
    func load() -> SettingsData?
}

/// Codable representation for persistence (single JSON blob, versioned)
struct SettingsData: Codable {
    var version: Int = 1
    var outputFormat: String = "jpeg"
    var quality: Int = 80
    var maxDimension: Int = 1920
    var preserveDirectoryStructure: Bool = false
    var stripMetadata: Bool = true
    var skipIfLarger: Bool = true
}

struct SettingsStore: SettingsStoring {
    private let defaults: UserDefaults
    private let key = "com.georgekhananaev.PixelDiet.settings"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(_ settings: SettingsData) throws {
        let data = try JSONEncoder().encode(settings)
        defaults.set(data, forKey: key)
    }

    func load() -> SettingsData? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SettingsData.self, from: data)
    }
}
