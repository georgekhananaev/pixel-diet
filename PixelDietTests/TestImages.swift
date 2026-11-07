import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers
@testable import PixelDiet

/// Builders and inspectors for small on-disk image fixtures.
enum TestImages {
    struct FixtureError: Error {
        let message: String
    }

    struct Pixel {
        let red: UInt8
        let green: UInt8
        let blue: UInt8
        let alpha: UInt8
    }

    /// Holds every fixture folder. Folders left by runs over an hour ago are removed on first
    /// use; recent ones are kept, as they may belong to a test process running in parallel.
    private static let fixturesRoot: URL = {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("PixelDietTests", isDirectory: true)
        let cutoff = Date().addingTimeInterval(-3600)
        let folders = (try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        for folder in folders {
            let modified = try? folder.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            if (modified ?? .distantPast) < cutoff {
                try? fileManager.removeItem(at: folder)
            }
        }
        return root
    }()

    /// A fresh, empty temporary directory.
    static func makeDirectory() throws -> URL {
        let url = fixturesRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A solid-color image (sRGB unless `colorSpace` names another RGB space).
    /// Components are straight (non-premultiplied) values in 0...1.
    static func makeImage(
        width: Int, height: Int, red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1,
        colorSpace: CFString = CGColorSpace.sRGB
    ) throws -> CGImage {
        guard let space = CGColorSpace(name: colorSpace),
              let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ),
              let color = CGColor(colorSpace: space, components: [red, green, blue, alpha]) else {
            throw FixtureError(message: "Cannot create bitmap context")
        }
        context.setFillColor(color)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else { throw FixtureError(message: "Cannot make image") }
        return image
    }

    /// A solid-color image with 16 bits per component, as photo editors export for print.
    static func makeHighBitDepthImage(width: Int, height: Int) throws -> CGImage {
        let image = try makeImage(width: width, height: height, red: 0.2, green: 0.5, blue: 0.8)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 16, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder16Little.rawValue
              ) else {
            throw FixtureError(message: "Cannot create 16-bit context")
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let deep = context.makeImage() else { throw FixtureError(message: "Cannot make 16-bit image") }
        return deep
    }

    /// A solid-color 32-bit float image in an extended-range color space, as HDR editors export.
    static func makeExtendedRangeImage(width: Int, height: Int, alpha: CGFloat) throws -> CGImage {
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.floatComponents.rawValue
            | CGBitmapInfo.byteOrder32Little.rawValue
        guard let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB),
              let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 32, bytesPerRow: 0,
                space: space, bitmapInfo: bitmapInfo
              ) else {
            throw FixtureError(message: "Cannot create float bitmap context")
        }
        context.setFillColor(red: 0.2, green: 0.4, blue: 0.8, alpha: alpha)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else { throw FixtureError(message: "Cannot make float image") }
        return image
    }

    /// A solid 50% gray image with 50% alpha in a grayscale color space.
    static func makeGrayAlphaImage(width: Int, height: Int) throws -> CGImage {
        guard let space = CGColorSpace(name: CGColorSpace.linearGray),
              let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw FixtureError(message: "Cannot create gray bitmap context")
        }
        context.setFillColor(gray: 0.5, alpha: 0.5)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else { throw FixtureError(message: "Cannot make gray image") }
        return image
    }

    @discardableResult
    static func write(_ image: CGImage, to url: URL, type: UTType, properties: [CFString: Any] = [:]) throws -> URL {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
            throw FixtureError(message: "Cannot create destination for \(type.identifier)")
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw FixtureError(message: "Cannot finalize \(url.lastPathComponent)") }
        return url
    }

    /// Solid mid-gray binary PPM (P6).
    @discardableResult
    static func writePPM(width: Int, height: Int, to url: URL) throws -> URL {
        var data = Data("P6\n\(width) \(height)\n255\n".utf8)
        data.append(Data(repeating: 128, count: width * height * 3))
        try data.write(to: url)
        return url
    }

    static func task(source: URL, outputFormat: ImageFormat, destination: URL? = nil) throws -> ImageTask {
        let dimensions = pixelSize(of: source) ?? .zero
        return ImageTask(
            id: UUID(),
            sourceURL: source,
            relativePath: nil,
            outputFormat: outputFormat,
            dimensions: dimensions,
            pixelLayout: try ImageAnalyzer().analyze(url: source).pixelLayout,
            precomputedDestination: destination
        )
    }

    static func settings(
        outputDirectory: URL,
        outputFormat: ImageFormat = .jpeg,
        quality: Int = 80,
        maxDimension: Int = 0,
        stripMetadata: Bool = true,
        skipIfLarger: Bool = false
    ) -> SettingsSnapshot {
        SettingsSnapshot(
            outputFormat: outputFormat,
            quality: quality,
            maxDimension: maxDimension,
            preserveDirectoryStructure: false,
            stripMetadata: stripMetadata,
            skipIfLarger: skipIfLarger,
            outputDirectory: outputDirectory
        )
    }

    static func fileSize(of url: URL) throws -> Int64 {
        Int64(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
    }

    /// Stored pixel dimensions (before any EXIF orientation is applied).
    static func pixelSize(of url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return CGSize(width: width, height: height)
    }

    /// Size as a viewer shows it: stored size with EXIF orientations 5-8 swapping width and height.
    static func displaySize(of url: URL) -> CGSize? {
        guard let size = pixelSize(of: url) else { return nil }
        return (5...8).contains(orientation(of: url) ?? 1) ? CGSize(width: size.height, height: size.width) : size
    }

    static func orientation(of url: URL) -> Int? {
        properties(of: url)[kCGImagePropertyOrientation] as? Int
    }

    /// Image properties of the first frame (empty if the file cannot be read).
    static func properties(of url: URL) -> [CFString: Any] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return [:] }
        return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
    }

    /// Name of the embedded color profile, e.g. "Display P3" or "sRGB IEC61966-2.1".
    static func profileName(of url: URL) -> String? {
        properties(of: url)[kCGImagePropertyProfileName] as? String
    }

    /// Payloads of the top-level chunks of a WebP (RIFF) file, keyed by FourCC ("VP8X", "ICCP", "XMP ", ...).
    static func webpChunks(of url: URL) throws -> [String: Data] {
        let data = try Data(contentsOf: url)
        guard data.count >= 12, String(decoding: data.prefix(4), as: UTF8.self) == "RIFF",
              String(decoding: data[8..<12], as: UTF8.self) == "WEBP" else {
            throw FixtureError(message: "\(url.lastPathComponent) is not a WebP file")
        }
        var chunks: [String: Data] = [:]
        var offset = 12
        while offset + 8 <= data.count {
            let fourCC = String(decoding: data[offset..<offset + 4], as: UTF8.self)
            let size = data[offset + 4..<offset + 8].enumerated().reduce(0) { $0 | Int($1.element) << (8 * $1.offset) }
            let start = offset + 8
            guard start + size <= data.count else { throw FixtureError(message: "Truncated \(fourCC) chunk") }
            chunks[fourCC] = data[start..<start + size]
            offset = start + size + size % 2
        }
        return chunks
    }

    /// Decodes the image and returns its center pixel as premultiplied sRGB RGBA8.
    static func premultipliedCenterPixel(of url: URL) throws -> Pixel {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw FixtureError(message: "Cannot decode \(url.lastPathComponent)")
        }
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard drawn else { throw FixtureError(message: "Cannot draw \(url.lastPathComponent)") }
        let offset = ((image.height / 2) * image.width + image.width / 2) * 4
        return Pixel(red: bytes[offset], green: bytes[offset + 1], blue: bytes[offset + 2], alpha: bytes[offset + 3])
    }
}
