import Foundation
import ImageIO

/// CRITICAL: Must be `nonisolated` - runs in TaskGroup child tasks for file discovery.
/// Without this, all image analysis serializes on MainActor. (Round 3 Fix)
nonisolated struct ImageAnalyzer: ImageAnalyzing {
    /// Must also be `nonisolated` - returned from background tasks
    nonisolated struct ImageInfo: Sendable {
        let fileSize: Int64
        let dimensions: CGSize
        let detectedFormat: ImageFormat?
        let colorSpaceName: String?
        let frameCount: Int
        let hasGPSData: Bool
        let pixelLayout: PixelLayout
    }

    /// Analyze an image file without fully loading it into memory.
    /// Throws `cannotReadImage` for empty files and files ImageIO cannot decode.
    func analyze(url: URL) throws -> ImageInfo {
        // The size of the image a symbolic link points to, not of the link
        let fileSize = Int64(try url.resolvingSymlinksInPath().resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)

        // Skip zero-byte files
        guard fileSize > 0 else {
            throw CompressionError.cannotReadImage
        }

        // ImageIO opens any file; only accept sources with at least one decodable image
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int, width > 0,
              let height = properties[kCGImagePropertyPixelHeight] as? Int, height > 0 else {
            throw CompressionError.cannotReadImage
        }

        // Content-based format detection
        let detectedFormat = (CGImageSourceGetType(source) as? String).flatMap(ImageFormat.from(typeIdentifier:))

        // Size as the photo is displayed: EXIF orientations 5-8 rotate it by 90 degrees
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        let isRotated = (5...8).contains(orientation)

        return ImageInfo(
            fileSize: fileSize,
            dimensions: isRotated ? CGSize(width: height, height: width) : CGSize(width: width, height: height),
            detectedFormat: detectedFormat,
            // The embedded profile ("Display P3"), else the color model ("RGB", "Gray")
            colorSpaceName: properties[kCGImagePropertyProfileName] as? String ?? properties[kCGImagePropertyColorModel] as? String,
            // Frame count for animated GIF / multi-page TIFF
            frameCount: CGImageSourceGetCount(source),
            hasGPSData: properties[kCGImagePropertyGPSDictionary] != nil,
            pixelLayout: PixelLayout(
                hasAlpha: properties[kCGImagePropertyHasAlpha] as? Bool ?? false,
                isHighBitDepth: (properties[kCGImagePropertyDepth] as? Int ?? 8) > 8,
                isInterlaced: (properties[kCGImagePropertyPNGDictionary] as? [CFString: Any])?[kCGImagePropertyPNGInterlaceType] as? Int == 1
            )
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
