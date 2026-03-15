import Foundation
import Observation

@Observable
class CompressionSettings {
    var outputFormat: ImageFormat = .jpeg

    /// Quality: 10-100. Use setQuality() for clamped setting.
    var quality: Int = 80

    /// Max longest edge in pixels. 0 = no resize. Use setMaxDimension() for clamped setting.
    var maxDimension: Int = 1920

    var preserveDirectoryStructure: Bool = false
    var stripMetadata: Bool = true
    var skipIfLarger: Bool = true
    var outputDirectory: URL?

    /// Set quality with clamping to valid range
    func setQuality(_ value: Int) {
        quality = value.clamped(to: 10...100)
    }

    /// Set maxDimension with clamping to valid range (0 = no resize)
    func setMaxDimension(_ value: Int) {
        if value == 0 {
            maxDimension = 0
        } else {
            maxDimension = value.clamped(to: 64...16384)
        }
    }

    /// Create a Sendable snapshot for actor boundary crossing.
    /// Caller must ensure outputDirectory is non-nil before calling.
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
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
