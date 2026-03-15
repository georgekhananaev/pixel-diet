import Foundation
import ImageIO

/// CRITICAL: Must be `nonisolated` — runs in TaskGroup child tasks for file discovery.
/// Without this, all image analysis serializes on MainActor. (Round 3 Fix)
nonisolated struct ImageAnalyzer: ImageAnalyzing {
    /// Must also be `nonisolated` — returned from background tasks
    nonisolated struct ImageInfo: Sendable {
        let fileSize: Int64
        let dimensions: CGSize
        let format: ImageFormat?
        let detectedFormat: ImageFormat?
        let hasAlpha: Bool
        let colorSpaceName: String?
        let dpi: Double?
        let bitDepth: Int
        let frameCount: Int
        let hasGPSData: Bool
    }

    /// Analyze an image file without fully loading it into memory
    func analyze(url: URL) throws -> ImageInfo {
        let fileSize = try FileManager.default
            .attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0

        // Skip zero-byte files
        guard fileSize > 0 else {
            throw CompressionError.cannotReadImage
        }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw CompressionError.cannotReadImage
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]

        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
        let hasAlpha = properties?[kCGImagePropertyHasAlpha] as? Bool ?? false
        let colorSpace = properties?[kCGImagePropertyColorModel] as? String
        let dpiWidth = properties?[kCGImagePropertyDPIWidth] as? Double
        let bitDepth = properties?[kCGImagePropertyDepth] as? Int ?? 8

        // Frame count for animated GIF / multi-page TIFF
        let frameCount = CGImageSourceGetCount(source)

        // GPS data detection
        let gpsDict = properties?[kCGImagePropertyGPSDictionary as CFString]
        let hasGPS = gpsDict != nil

        // Content-based format detection
        let detectedFormat: ImageFormat?
        if let sourceType = CGImageSourceGetType(source) as? String {
            detectedFormat = ImageFormat.from(typeIdentifier: sourceType)
        } else {
            detectedFormat = nil
        }

        let extensionFormat = ImageFormat.from(extension: url.pathExtension)

        return ImageInfo(
            fileSize: fileSize,
            dimensions: CGSize(width: width, height: height),
            format: extensionFormat,
            detectedFormat: detectedFormat,
            hasAlpha: hasAlpha,
            colorSpaceName: colorSpace,
            dpi: dpiWidth,
            bitDepth: bitDepth,
            frameCount: frameCount,
            hasGPSData: hasGPS
        )
    }

    /// Content-based format detection for files without extensions
    func sniffFormat(url: URL) -> ImageFormat? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let typeID = CGImageSourceGetType(source) as? String else {
            return nil
        }
        return ImageFormat.from(typeIdentifier: typeID)
    }
}
