import Foundation
import ImageIO

/// Returns CGImage (which is Sendable) — convert to NSImage on @MainActor.
/// NSImage is NOT Sendable and cannot cross actor boundaries.
/// Uses NSCache for automatic memory-pressure eviction.
///
/// **Swift 6.2 optimization**: Uses `@concurrent` to offload the actual
/// ImageIO thumbnail generation to the background thread pool. Without this, all
/// thumbnail loads serialize on the actor's executor, creating a bottleneck.
actor ThumbnailService {
    private let cache = NSCache<NSURL, CGImageWrapper>()

    init() {
        cache.countLimit = 500
    }

    /// Generate or retrieve cached thumbnail. Returns CGImage (Sendable).
    func thumbnail(for url: URL, maxSize: CGFloat = 200) async -> CGImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached.image
        }

        // Offload ImageIO work to background — avoid serializing on actor executor
        let cgImage = await Self.generateThumbnail(for: url, maxSize: maxSize)

        if let cgImage {
            cache.setObject(CGImageWrapper(cgImage), forKey: url as NSURL)
        }
        return cgImage
    }

    /// Offload expensive ImageIO work to concurrent thread pool
    @concurrent
    private static func generateThumbnail(for url: URL, maxSize: CGFloat) async -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    func clearCache() {
        cache.removeAllObjects()
    }
}

/// NSCache requires class values — simple wrapper for CGImage.
/// Must be `nonisolated` — used inside actor. (Round 3 Fix)
nonisolated final class CGImageWrapper: NSObject {
    let image: CGImage
    init(_ image: CGImage) { self.image = image }
}
