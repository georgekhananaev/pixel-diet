import Foundation

nonisolated struct ImageTask: Sendable {
    let id: UUID
    let sourceURL: URL
    let relativePath: String?
    /// Final output format, already resolved from the requested format and the source format
    let outputFormat: ImageFormat
    /// Source size and pixel storage, to estimate memory use
    let dimensions: CGSize
    let pixelLayout: PixelLayout
    var precomputedDestination: URL?
}

extension ImageItem {
    /// Create a Sendable snapshot for actor boundary crossing
    func toTask(requestedFormat: ImageFormat) -> ImageTask {
        ImageTask(
            id: id,
            sourceURL: sourceURL,
            relativePath: relativePath,
            outputFormat: ImageFormat.resolvedOutput(requested: requestedFormat, source: effectiveFormat),
            dimensions: originalDimensions,
            pixelLayout: pixelLayout
        )
    }
}
