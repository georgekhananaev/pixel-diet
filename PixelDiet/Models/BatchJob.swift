import Foundation
import Observation

@Observable
class BatchJob {
    var items: [ImageItem] = []
    var isProcessing: Bool = false
    var startTime: Date?
    var endTime: Date?

    // Incremental counters — O(1) instead of O(n) per render
    private(set) var completedCount: Int = 0
    private(set) var failedCount: Int = 0
    private(set) var skippedCount: Int = 0
    private(set) var totalCompressedSize: Int64 = 0

    var processedCount: Int {
        completedCount + failedCount + skippedCount
    }

    var progress: Double {
        guard !items.isEmpty else { return 0 }
        return Double(processedCount) / Double(items.count)
    }

    var totalSavings: Int64 {
        totalOriginalSize - totalCompressedSize
    }

    var totalSavingsPercentage: Double {
        guard totalOriginalSize > 0 else { return 0 }
        return Double(totalSavings) / Double(totalOriginalSize) * 100.0
    }

    var elapsedTime: TimeInterval {
        guard let start = startTime else { return 0 }
        let end = endTime ?? Date()
        return end.timeIntervalSince(start)
    }

    /// Update counters when an item completes (called from @MainActor callback)
    func recordCompletion(status: ProcessingStatus, compressedSize: Int64?) {
        switch status {
        case .completed:
            completedCount += 1
            if let size = compressedSize {
                totalCompressedSize += size
            }
        case .failed:
            failedCount += 1
        case .skipped:
            skippedCount += 1
        default:
            break
        }
    }

    /// Add items with deduplication by sourceURL
    func addItems(_ newItems: [ImageItem]) {
        let existingURLs = Set(items.map(\.sourceURL))
        let unique = newItems.filter { !existingURLs.contains($0.sourceURL) }
        items.append(contentsOf: unique)
        totalOriginalSize += unique.reduce(0) { $0 + $1.originalSize }
    }

    /// Decrement failed counter before retry
    func decrementFailed() {
        if failedCount > 0 { failedCount -= 1 }
    }

    /// Decrement skipped counter before retry
    func decrementSkipped() {
        if skippedCount > 0 { skippedCount -= 1 }
    }

    /// Incremental original size — updated in addItems, not computed
    private(set) var totalOriginalSize: Int64 = 0

    func clear() {
        items.removeAll()
        isProcessing = false
        startTime = nil
        endTime = nil
        completedCount = 0
        failedCount = 0
        skippedCount = 0
        totalCompressedSize = 0
        totalOriginalSize = 0
    }
}
