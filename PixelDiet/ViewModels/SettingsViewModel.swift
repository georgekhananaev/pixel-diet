import Observation

@Observable
class SettingsViewModel {
    var settings: CompressionSettings
    private let store: SettingsStoring

    init(store: SettingsStoring = SettingsStore()) {
        self.store = store
        self.settings = CompressionSettings()
        loadSettings()
    }

    func loadSettings() {
        guard let data = store.load() else { return }
        settings.outputFormat = ImageFormat(rawValue: data.outputFormat) ?? .jpeg
        settings.quality = data.quality
        settings.maxDimension = data.maxDimension
        settings.preserveDirectoryStructure = data.preserveDirectoryStructure
        settings.stripMetadata = data.stripMetadata
        settings.skipIfLarger = data.skipIfLarger
    }

    func saveSettings() {
        let data = SettingsData(
            outputFormat: settings.outputFormat.rawValue,
            quality: settings.quality,
            maxDimension: settings.maxDimension,
            preserveDirectoryStructure: settings.preserveDirectoryStructure,
            stripMetadata: settings.stripMetadata,
            skipIfLarger: settings.skipIfLarger
        )
        try? store.save(data)
    }
}
