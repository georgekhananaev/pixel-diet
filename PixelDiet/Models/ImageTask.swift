import Foundation

nonisolated struct ImageTask: Sendable {
    let id: UUID
    let sourceURL: URL
    let originalSize: Int64
    let relativePath: String?
    let sourceFormat: ImageFormat?
    let bitDepth: Int
    let colorSpaceName: String?
    let frameCount: Int
    var precomputedDestination: URL?
}

extension ImageItem {
    /// Create a Sendable snapshot for actor boundary crossing
    func toTask() -> ImageTask {
        ImageTask(
            id: id,
            sourceURL: sourceURL,
            originalSize: originalSize,
            relativePath: relativePath,
            sourceFormat: effectiveFormat,
            bitDepth: bitDepth,
            colorSpaceName: colorSpaceName,
            frameCount: frameCount
        )
    }
}
