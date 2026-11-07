import Foundation
import ImageIO
import UniformTypeIdentifiers
import os
import CoreGraphics

/// CRITICAL: Must be `nonisolated` under Swift 6.2 with MainActor default isolation.
/// Without this, compress() would hop to MainActor for every call from TaskGroup,
/// serializing all compression on the main thread and freezing the UI. (Round 3 Fix)
nonisolated struct ImageCompressor: ImageCompressing {
    func compress(task: ImageTask, settings: SettingsSnapshot) throws -> CompressionResult {
        let outputFormat = task.outputFormat

        // Validate output format is available and can be written
        guard outputFormat.canBeOutput, let utType = outputFormat.utType else {
            throw CompressionError.unsupportedFormat(outputFormat.displayName)
        }

        // 1. Create CGImageSource. ImageIO opens any path, so check the file is still there
        // (it may have been moved or deleted since it was added) and actually holds an image.
        // Its size is read now too (the image's, for a symbolic link): the file may have been replaced since it was added.
        let sourcePath = task.sourceURL.resolvingSymlinksInPath().path
        guard let sourceSize = (try? FileManager.default.attributesOfItem(atPath: sourcePath))?[.size] as? Int64 else {
            throw CompressionError.sourceUnavailable
        }
        guard let source = CGImageSourceCreateWithURL(task.sourceURL as CFURL, nil),
              CGImageSourceGetCount(source) > 0 else {
            throw CompressionError.cannotReadImage
        }

        // 2. Check for animated/multi-page
        let frameCount = CGImageSourceGetCount(source)
        if frameCount > 1 {
            Logger.compression.warning("Multi-frame image (\(frameCount) frames): \(task.sourceURL.lastPathComponent)")
            // Process only first frame - caller should have warned user
        }

        // 3. Read the metadata once, without decoding the image; fail fast on bad dimensions
        let sourceProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        let srcWidth = sourceProperties[kCGImagePropertyPixelWidth] as? Int ?? 0
        let srcHeight = sourceProperties[kCGImagePropertyPixelHeight] as? Int ?? 0
        guard srcWidth > 0 && srcHeight > 0 else {
            throw CompressionError.invalidDimensions
        }

        // 4. Decode upright, downsampling during decode when resizing. The EXIF orientation is
        // always applied to the pixels: BMP, AVIF, GIF and WebP cannot carry the tag reliably.
        let image = try decodeUpright(
            source,
            longestEdge: settings.maxDimension > 0 ? settings.maxDimension : max(srcWidth, srcHeight)
        )
        guard image.width > 0 && image.height > 0 else {
            throw CompressionError.invalidDimensions
        }

        // 5. Use pre-computed destination path (collision resolved on @MainActor)
        let destURL = try task.precomputedDestination ?? PathSanitizer.buildDestinationURL(
            source: task.sourceURL,
            outputDir: settings.outputDirectory,
            format: outputFormat,
            relativePath: settings.preserveDirectoryStructure ? task.relativePath : nil
        )
        let destDirectory = destURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: destDirectory, withIntermediateDirectories: true)

        // 6. Write to a hidden temp file next to the destination, then move it into place.
        // Same volume as the destination (a move from the system temp dir cannot replace
        // files on external drives) and inside the folder the user granted access to.
        let tempURL = destDirectory.appendingPathComponent("\(TempFileSweeper.prefix)\(UUID().uuidString).\(outputFormat.fileExtension)")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Keeping metadata also keeps the color profile; stripping it converts colors to sRGB,
        // so they look the same in every browser and app
        let keepsMetadata = !settings.stripMetadata
        if outputFormat == .webp {
            let metadata = keepsMetadata ? CGImageSourceCopyMetadataAtIndex(source, 0, nil) : nil
            try WebPEncoder.encode(image, quality: settings.quality, metadata: metadata).write(to: tempURL)
        } else {
            try writeImage(
                rendered(image, flattened: !outputFormat.supportsAlpha, inSRGB: !keepsMetadata),
                to: tempURL,
                format: outputFormat,
                utType: utType,
                quality: settings.quality,
                metadata: keepsMetadata ? Self.uprightMetadata(sourceProperties) : [:]
            )
        }

        // 7. Decide "skip if larger" before touching the destination, so an existing
        // file the user chose to overwrite is never lost for a result we discard.
        let outputSize = Int64(try tempURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        if settings.skipIfLarger && outputSize > sourceSize {
            throw CompressionError.outputLargerThanOriginal
        }

        // 8. Atomic move - try moveItem first, fall back to replaceItemAt
        let finalURL: URL
        do {
            try FileManager.default.moveItem(at: tempURL, to: destURL)
            finalURL = destURL
        } catch let error as NSError where error.code == NSFileWriteFileExistsError {
            finalURL = try FileManager.default.replaceItemAt(destURL, withItemAt: tempURL) ?? destURL
        }

        return CompressionResult(
            sourceSize: sourceSize,
            outputURL: finalURL,
            outputSize: outputSize,
            outputDimensions: CGSize(width: image.width, height: image.height)
        )
    }

    // MARK: - Decode

    /// Decodes at most `longestEdge` pixels on the longer side (never upscaling) in display
    /// orientation, with ImageIO downsampling during decode instead of loading the full-resolution bitmap.
    private func decodeUpright(_ source: CGImageSource, longestEdge: Int) throws -> CGImage {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: longestEdge
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw CompressionError.resizeFailed
        }
        return image
    }

    // MARK: - Pixels

    /// The pixels to write, redrawn only when needed: onto white for formats without
    /// transparency (as people expect from a transparent logo saved as JPEG, instead of a
    /// black background), and in sRGB when the color profile is not kept. Grayscale stays gray.
    private func rendered(_ image: CGImage, flattened: Bool, inSRGB: Bool) -> CGImage {
        let model = image.colorSpace?.model
        let flattens = flattened && image.hasAlpha
        let converts = inSRGB && model != .monochrome && image.colorSpace?.name != CGColorSpace.sRGB
        guard flattens || converts else { return image }

        // Gray and RGB spaces are kept unless converting; anything else is drawn in sRGB
        let keepsSpace = !converts && (model == .monochrome || model == .rgb) && !image.usesExtendedRange
        guard let space = keepsSpace ? image.colorSpace : CGColorSpace(name: CGColorSpace.sRGB) else { return image }
        let alphaInfo: CGImageAlphaInfo = switch (flattens || !image.hasAlpha, space.model == .monochrome) {
        case (true, true): .none
        case (true, false): .noneSkipLast
        case (false, _): .premultipliedLast
        }
        guard let context = CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: alphaInfo.rawValue
        ) else {
            return image
        }

        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        if flattens {
            context.setFillColor(CGColor.white)
            context.fill(bounds)
        }
        context.draw(image, in: bounds)
        return context.makeImage() ?? image
    }

    // MARK: - Write

    /// Source metadata for the upright, possibly resized output: orientation reset, and the
    /// original pixel size dropped (the HEIC writer would copy it as is).
    private static func uprightMetadata(_ properties: [CFString: Any]) -> [CFString: Any] {
        var metadata = properties
        metadata[kCGImagePropertyOrientation] = 1
        if var tiff = metadata[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            tiff[kCGImagePropertyTIFFOrientation] = 1
            metadata[kCGImagePropertyTIFFDictionary] = tiff
        }
        if var exif = metadata[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            exif[kCGImagePropertyExifPixelXDimension] = nil
            exif[kCGImagePropertyExifPixelYDimension] = nil
            metadata[kCGImagePropertyExifDictionary] = exif
        }
        return metadata
    }

    private func writeImage(
        _ image: CGImage,
        to url: URL,
        format: ImageFormat,
        utType: UTType,
        quality: Int,
        metadata: [CFString: Any]
    ) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, utType.identifier as CFString, 1, nil
        ) else {
            throw CompressionError.cannotCreateDestination
        }

        var properties = metadata
        if format.supportsQuality {
            properties[kCGImageDestinationLossyCompressionQuality] = Double(quality) / 100.0
        }

        CGImageDestinationAddImage(destination, image, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw CompressionError.writeFailed
        }
    }
}

/// Must be `nonisolated` - returned from background compression tasks (Round 3 Fix)
nonisolated struct CompressionResult: Sendable {
    /// Size of the source file when it was compressed
    let sourceSize: Int64
    let outputURL: URL
    let outputSize: Int64
    let outputDimensions: CGSize
}
