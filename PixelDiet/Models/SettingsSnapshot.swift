import Foundation

nonisolated struct SettingsSnapshot: Sendable {
    let outputFormat: ImageFormat
    let quality: Int
    let maxDimension: Int
    let preserveDirectoryStructure: Bool
    let stripMetadata: Bool
    let skipIfLarger: Bool
    let outputDirectory: URL
}
