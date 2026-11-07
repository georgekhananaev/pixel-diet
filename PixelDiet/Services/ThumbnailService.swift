import Foundation
import ImageIO

/// Returns CGImage (which is Sendable) - convert to NSImage on @MainActor.
/// NSImage is NOT Sendable and cannot cross actor boundaries.
/// Uses NSCache for automatic memory-pressure eviction.
actor ThumbnailService {
    private let cache = NSCache<NSURL, CGImageWrapper>()

    init() {
        cache.countLimit = Constants.thumbnailCacheLimit
    }

    /// Generate or retrieve cached thumbnail. Returns CGImage (Sendable).
    func thumbnail(for url: URL, maxSize: CGFloat = Constants.thumbnailMaxSize) async -> CGImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached.image
        }

        // Offload ImageIO work to a detached task to avoid serializing on actor executor
        let cgImage = await Task.detached {
            Self.downsampledImage(at: url, maxPixelSize: maxSize)
        }.value

        if let cgImage {
            cache.setObject(CGImageWrapper(cgImage), forKey: url as NSURL)
        }
        return cgImage
    }

    /// Decodes an image at reduced size with EXIF orientation applied, without
    /// loading the full-resolution bitmap. Synchronous - call off the main actor.
    nonisolated static func downsampledImage(at url: URL, maxPixelSize: CGFloat) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

/// NSCache requires class values - simple wrapper for CGImage.
/// Must be `nonisolated` - used inside actor. (Round 3 Fix)
nonisolated final class CGImageWrapper: NSObject {
    let image: CGImage
    init(_ image: CGImage) { self.image = image }
}
