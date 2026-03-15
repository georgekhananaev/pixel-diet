import Foundation
import ImageIO
import Accelerate
import UniformTypeIdentifiers
import os
import CoreGraphics
import libwebp

/// CRITICAL: Must be `nonisolated` under Swift 6.2 with MainActor default isolation.
/// Without this, compress() would hop to MainActor for every call from TaskGroup,
/// serializing all compression on the main thread and freezing the UI. (Round 3 Fix)
nonisolated struct ImageCompressor: ImageCompressing {
    private let logger = Logger(subsystem: "com.georgekhananaev.PixelDiet", category: "compression")

    func compress(task: ImageTask, settings: SettingsSnapshot) throws -> CompressionResult {
        // Resolve output format (.original -> use source format)
        let outputFormat = settings.outputFormat == .original
            ? (task.sourceFormat ?? .jpeg)
            : settings.outputFormat

        // Validate output format is available
        guard let utType = outputFormat.utType else {
            throw CompressionError.unsupportedFormat(outputFormat.displayName)
        }

        // 1. Create CGImageSource
        guard let source = CGImageSourceCreateWithURL(task.sourceURL as CFURL, nil) else {
            throw CompressionError.cannotReadImage
        }

        // 2. Check for animated/multi-page
        let frameCount = CGImageSourceGetCount(source)
        if frameCount > 1 {
            logger.warning("Multi-frame image (\(frameCount) frames): \(task.sourceURL.lastPathComponent)")
            // Process only first frame — caller should have warned user
        }

        // 3. Read original metadata and ICC profile (without loading full CGImage)
        let sourceProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let iccProfileData = extractICCProfileData(from: source)

        // 4. Handle metadata
        var outputMetadata: [CFString: Any]? = nil
        if !settings.stripMetadata {
            outputMetadata = sourceProperties
        }
        // When stripping metadata, EXIF orientation is applied via
        // kCGImageSourceCreateThumbnailWithTransform in resizeMemoryEfficient

        // 5. Resize using memory-efficient approach
        let resizedImage: CGImage
        if settings.maxDimension > 0 {
            resizedImage = try resizeMemoryEfficient(
                source: source,
                maxDimension: settings.maxDimension,
                applyOrientation: settings.stripMetadata
            )
        } else if settings.stripMetadata {
            // No resize, but still need to apply orientation
            resizedImage = try resizeMemoryEfficient(
                source: source,
                maxDimension: 0,
                applyOrientation: true
            )
        } else {
            // No resize, no metadata strip — load image as-is
            guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw CompressionError.cannotReadImage
            }
            resizedImage = image
        }

        // 6. Validate dimensions
        guard resizedImage.width > 0 && resizedImage.height > 0 else {
            throw CompressionError.invalidDimensions
        }

        // 7. Use pre-computed destination path (collision resolved on @MainActor)
        let destURL = try task.precomputedDestination ?? PathSanitizer.buildDestinationURL(
            source: task.sourceURL,
            outputDir: settings.outputDirectory,
            format: outputFormat,
            relativePath: settings.preserveDirectoryStructure ? task.relativePath : nil
        )

        // Create parent directories
        try FileManager.default.createDirectory(
            at: destURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        // 8. Write to SYSTEM temp directory, then atomic move
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent(UUID().uuidString + "." + outputFormat.fileExtension)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        if outputFormat == .webp {
            // Use libwebp for WebP encoding (ImageIO doesn't support WebP writing)
            try writeWebP(resizedImage, to: tempURL, quality: settings.quality)
        } else {
            try writeImage(
                resizedImage,
                to: tempURL,
                format: outputFormat,
                utType: utType,
                quality: settings.quality,
                metadata: outputMetadata,
                iccProfileData: settings.stripMetadata ? nil : iccProfileData
            )
        }

        // 9. Atomic move — try moveItem first, fall back to replaceItemAt
        let finalURL: URL
        do {
            try FileManager.default.moveItem(at: tempURL, to: destURL)
            finalURL = destURL
        } catch let error as NSError where error.code == NSFileWriteFileExistsError {
            finalURL = try FileManager.default.replaceItemAt(destURL, withItemAt: tempURL) ?? destURL
        }

        // 10. Get output file size
        let attrs = try FileManager.default.attributesOfItem(atPath: finalURL.path)
        let outputSize = attrs[.size] as? Int64 ?? 0
        let outputDimensions = CGSize(width: resizedImage.width, height: resizedImage.height)

        return CompressionResult(
            outputURL: finalURL,
            outputSize: outputSize,
            outputDimensions: outputDimensions
        )
    }

    // MARK: - Memory-Efficient Resize

    /// Uses CGImageSourceCreateThumbnailAtIndex for memory-efficient downsampling.
    /// This avoids loading the full-resolution bitmap — ImageIO downsamples during decode.
    private func resizeMemoryEfficient(
        source: CGImageSource,
        maxDimension: Int,
        applyOrientation: Bool
    ) throws -> CGImage {
        var options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: applyOrientation,
            kCGImageSourceShouldCacheImmediately: true
        ]

        if maxDimension > 0 {
            options[kCGImageSourceThumbnailMaxPixelSize] = maxDimension
        } else {
            // No resize — just decode with orientation applied
            let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
            let width = props?[kCGImagePropertyPixelWidth] as? Int ?? 0
            let height = props?[kCGImagePropertyPixelHeight] as? Int ?? 0
            let maxSide = max(width, height)
            if maxSide > 0 {
                options[kCGImageSourceThumbnailMaxPixelSize] = maxSide
            }
        }

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw CompressionError.resizeFailed
        }

        return image
    }

    // MARK: - Color Space

    /// Extract ICC profile data from metadata WITHOUT loading the full CGImage.
    private func extractICCProfileData(from source: CGImageSource) -> Data? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }
        return properties["ICC Profile" as CFString] as? Data
    }

    // MARK: - Write

    private func writeImage(
        _ image: CGImage,
        to url: URL,
        format: ImageFormat,
        utType: UTType,
        quality: Int,
        metadata: [CFString: Any]?,
        iccProfileData: Data?
    ) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, utType.identifier as CFString, 1, nil
        ) else {
            throw CompressionError.cannotCreateDestination
        }

        var properties: [CFString: Any] = [:]

        // Set quality for formats that support it
        if format.supportsQuality {
            properties[kCGImageDestinationLossyCompressionQuality] = Double(quality) / 100.0
        }

        // Only optimize color for sharing if NOT preserving color profile
        if iccProfileData == nil {
            properties[kCGImageDestinationOptimizeColorForSharing] = true
        }

        // Preserve ICC color profile from metadata
        if let iccData = iccProfileData {
            properties["ICC Profile" as CFString] = iccData
        }

        // Preserve metadata if not stripping
        if let metadata = metadata {
            for (key, value) in metadata {
                properties[key] = value
            }
        }

        CGImageDestinationAddImage(destination, image, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw CompressionError.writeFailed
        }
    }

    // MARK: - WebP Encoding (via libwebp)

    /// Encode a CGImage to WebP format using Google's libwebp library.
    /// ImageIO does not support WebP writing on most macOS versions.
    private func writeWebP(_ image: CGImage, to url: URL, quality: Int) throws {
        let width = image.width
        let height = image.height
        let hasAlpha = image.alphaInfo != .none && image.alphaInfo != .noneSkipFirst && image.alphaInfo != .noneSkipLast

        // Render CGImage into raw RGBA pixel data
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = bytesPerRow * height

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw CompressionError.writeFailed
        }

        var pixelData = [UInt8](repeating: 0, count: totalBytes)
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            throw CompressionError.writeFailed
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Encode with libwebp
        var output: UnsafeMutablePointer<UInt8>? = nil
        let qualityFloat = Float(quality)
        let outputSize: Int

        if hasAlpha {
            outputSize = pixelData.withUnsafeBufferPointer { buffer in
                Int(WebPEncodeRGBA(
                    buffer.baseAddress,
                    Int32(width),
                    Int32(height),
                    Int32(bytesPerRow),
                    qualityFloat,
                    &output
                ))
            }
        } else {
            // For images without alpha, still use RGBA data but encode as lossy
            outputSize = pixelData.withUnsafeBufferPointer { buffer in
                Int(WebPEncodeRGBA(
                    buffer.baseAddress,
                    Int32(width),
                    Int32(height),
                    Int32(bytesPerRow),
                    qualityFloat,
                    &output
                ))
            }
        }

        guard outputSize > 0, let output else {
            throw CompressionError.writeFailed
        }

        // Write to file
        let data = Data(bytes: output, count: outputSize)
        WebPFree(output)

        try data.write(to: url)
    }
}

/// Must be `nonisolated` — returned from background compression tasks (Round 3 Fix)
nonisolated struct CompressionResult: Sendable {
    let outputURL: URL
    let outputSize: Int64
    let outputDimensions: CGSize
}
