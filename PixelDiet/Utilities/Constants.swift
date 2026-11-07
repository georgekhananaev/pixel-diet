import Foundation

nonisolated enum Constants {
    static let defaultQuality = 80
    static let qualityRange = 10...100
    static let defaultMaxDimension = 1920
    /// Allowed max-dimension values; 0 (no resize) is allowed separately.
    /// The upper bound is the largest size WebP can store.
    static let maxDimensionRange = 64...WebPEncoder.maxDimension
    /// Budget for the estimated memory of images compressed at the same time: a quarter of the
    /// Mac's memory (2 GB on an 8 GB Mac), so a large batch never pushes the system into swapping
    static let memoryBudget = Int64(ProcessInfo.processInfo.physicalMemory / 4)
    /// Longest thumbnail edge in pixels: list rows show 32 pt squares (aspect fill) on 2x screens
    static let thumbnailMaxSize: CGFloat = 96
    static let thumbnailCacheLimit = 500
}
