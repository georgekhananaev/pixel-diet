import Foundation

enum Constants {
    static let defaultQuality = 80
    static let minQuality = 10
    static let maxQuality = 100
    static let defaultMaxDimension = 1920
    static let minDimension = 64
    static let maxDimension = 16384
    static let memoryBudget: Int64 = 1_024 * 1_024 * 1_024 // 1GB
    static let thumbnailMaxSize: CGFloat = 200
    static let thumbnailCacheLimit = 500
}
