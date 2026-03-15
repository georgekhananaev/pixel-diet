import AppKit
import Observation

@Observable
class ImageItem: Identifiable {
    let id = UUID()
    let sourceURL: URL
    let originalFormat: ImageFormat?
    let detectedFormat: ImageFormat?
    let originalSize: Int64
    let originalDimensions: CGSize
    let frameCount: Int
    let hasGPSData: Bool
    let relativePath: String?
    let bitDepth: Int
    let colorSpaceName: String?

    var destinationURL: URL?
    var status: ProcessingStatus = .queued
    var compressedSize: Int64?
    var compressedDimensions: CGSize?
    var errorMessage: String?

    /// Which compression run this item was part of (nil = not yet processed)
    var batchRunId: Int?
    /// The output format used for this item's compression
    var outputFormatUsed: String?

    var thumbnail: NSImage?

    var savingsPercentage: Double? {
        guard let compressed = compressedSize, originalSize > 0 else { return nil }
        return Double(originalSize - compressed) / Double(originalSize) * 100.0
    }

    var formattedOriginalSize: String {
        ByteCountFormatter.string(fromByteCount: originalSize, countStyle: .file)
    }

    var formattedCompressedSize: String? {
        guard let size = compressedSize else { return nil }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var fileName: String {
        sourceURL.lastPathComponent
    }

    var isAnimated: Bool { frameCount > 1 }

    /// The effective format (detected > extension-based)
    var effectiveFormat: ImageFormat? {
        detectedFormat ?? originalFormat
    }

    init(
        sourceURL: URL,
        originalSize: Int64,
        originalDimensions: CGSize,
        frameCount: Int = 1,
        hasGPSData: Bool = false,
        relativePath: String? = nil,
        bitDepth: Int = 8,
        colorSpaceName: String? = nil,
        detectedFormat: ImageFormat? = nil
    ) {
        self.sourceURL = sourceURL
        self.originalSize = originalSize
        self.originalDimensions = originalDimensions
        self.frameCount = frameCount
        self.hasGPSData = hasGPSData
        self.relativePath = relativePath
        self.bitDepth = bitDepth
        self.colorSpaceName = colorSpaceName
        self.detectedFormat = detectedFormat
        self.originalFormat = ImageFormat.from(extension: sourceURL.pathExtension)
    }
}
