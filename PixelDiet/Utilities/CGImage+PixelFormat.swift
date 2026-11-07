import CoreGraphics

nonisolated extension CGImage {
    /// Whether the pixels carry an alpha channel (images with a skipped alpha byte are opaque).
    var hasAlpha: Bool {
        switch alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: false
        default: true
        }
    }

    /// Whether the color space is extended range (HDR or float images), which 8-bit bitmaps cannot use.
    var usesExtendedRange: Bool {
        colorSpace.map(CGColorSpaceUsesExtendedRange) ?? false
    }
}
