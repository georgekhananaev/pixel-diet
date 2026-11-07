import Foundation

/// How a source image stores its pixels, which decides how much memory compressing it takes.
nonisolated struct PixelLayout: Sendable, Equatable {
    var hasAlpha = false
    /// More than 8 bits per color component, as in 16-bit TIFF and PNG exports
    var isHighBitDepth = false
    /// Interlaced PNG, which is decoded at full size even when downscaling
    var isInterlaced = false
}
