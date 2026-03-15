import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Must be `nonisolated` - used from both MainActor and background services.
/// Without this, static properties like `allInputExtensions` can't be accessed
/// from nonisolated contexts (ImageCompressor, FileManager.findImages, etc.)
nonisolated enum ImageFormat: String, CaseIterable, Identifiable, Codable, Sendable {
    case original  // Keep source format
    case jpeg
    case png
    case webp
    case heic
    case heif
    case avif
    case tiff
    case bmp
    case gif
    case ppm

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .original: "Original"
        case .jpeg: "JPEG"
        case .png:  "PNG"
        case .webp: "WebP"
        case .heic: "HEIC"
        case .heif: "HEIF"
        case .avif: "AVIF"
        case .tiff: "TIFF"
        case .bmp:  "BMP"
        case .gif:  "GIF"
        case .ppm:  "PPM"
        }
    }

    /// UTType for ImageIO - returns nil for .original (resolved at compression time)
    var utType: UTType? {
        switch self {
        case .original: nil
        case .jpeg: .jpeg
        case .png:  .png
        case .webp: .webP
        case .heic: .heic
        case .heif: .heic
        case .avif: UTType("public.avif")
        case .tiff: .tiff
        case .bmp:  .bmp
        case .gif:  .gif
        case .ppm:  UTType("public.pbm")
        }
    }

    var fileExtension: String {
        switch self {
        case .original: ""
        case .jpeg: "jpg"
        case .heif: "heif"
        default: rawValue
        }
    }

    /// Whether this format supports a quality parameter
    var supportsQuality: Bool {
        switch self {
        case .jpeg, .webp, .heic, .heif, .avif: true
        case .original: true
        case .png, .tiff, .bmp, .gif, .ppm: false
        }
    }

    /// Whether this format supports alpha channel
    var supportsAlpha: Bool {
        switch self {
        case .png, .webp, .tiff, .gif: true
        case .original: true
        case .jpeg, .heic, .heif, .avif, .bmp, .ppm: false
        }
    }

    /// Whether this format can be used as output - checks runtime ImageIO support
    var canBeOutput: Bool {
        switch self {
        case .ppm: false
        case .webp: true  // Encoded via libwebp (bundled)
        case .avif: Self.isEncodingAvailable(typeIdentifier: "public.avif")
        default: true
        }
    }

    /// Formats available in the output picker (excludes unsupported formats at runtime)
    static var availableOutputFormats: [ImageFormat] {
        allCases.filter { $0.canBeOutput }
    }

    /// Check if AVIF encoding is available on this system
    static var isAVIFEncodingAvailable: Bool {
        isEncodingAvailable(typeIdentifier: "public.avif")
    }

    /// Check if WebP encoding is available on this system
    static var isWebPEncodingAvailable: Bool {
        isEncodingAvailable(typeIdentifier: "org.webmproject.webp")
    }

    /// Check if a given type identifier is supported for CGImageDestination writing
    private static func isEncodingAvailable(typeIdentifier: String) -> Bool {
        guard let typeIDs = CGImageDestinationCopyTypeIdentifiers() as? [String] else { return false }
        return typeIDs.contains(typeIdentifier)
    }

    /// Detect format from file extension
    static func from(extension ext: String) -> ImageFormat? {
        let lower = ext.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        switch lower {
        case "jpg", "jpeg": return .jpeg
        case "png": return .png
        case "webp": return .webp
        case "heic": return .heic
        case "heif": return .heif
        case "avif": return .avif
        case "tiff", "tif": return .tiff
        case "bmp": return .bmp
        case "gif": return .gif
        case "ppm": return .ppm
        default: return nil
        }
    }

    /// Detect format from CGImageSource type identifier
    static func from(typeIdentifier: String) -> ImageFormat? {
        switch typeIdentifier {
        case "public.jpeg": return .jpeg
        case "public.png": return .png
        case "org.webmproject.webp", "public.webp": return .webp
        case "public.heic": return .heic
        case "public.heif": return .heif
        case "public.avif": return .avif
        case "public.tiff": return .tiff
        case "com.microsoft.bmp": return .bmp
        case "com.compuserve.gif": return .gif
        default: return nil
        }
    }

    /// All extensions that can be used as input
    static var allInputExtensions: Set<String> {
        Set(["jpg", "jpeg", "png", "webp", "heic", "heif", "avif",
             "tiff", "tif", "bmp", "gif", "ppm"])
    }
}
