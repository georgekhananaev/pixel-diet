import Foundation

/// Must be nonisolated - implementations run on background threads in TaskGroup
nonisolated protocol ImageAnalyzing: Sendable {
    func analyze(url: URL) throws -> ImageAnalyzer.ImageInfo
    func sniffFormat(url: URL) -> ImageFormat?
}
