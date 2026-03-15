import Foundation
import Observation

/// Summary of a completed compression run
@Observable
class RunSummary: Identifiable {
    let id: Int  // run ID
    let format: String
    let quality: Int
    let startTime: Date
    var endTime: Date?
    var completedCount: Int = 0
    var failedCount: Int = 0
    var skippedCount: Int = 0
    var completedOriginalSize: Int64 = 0
    var totalCompressedSize: Int64 = 0
    var itemCount: Int = 0

    init(id: Int, format: String, quality: Int, startTime: Date, itemCount: Int) {
        self.id = id
        self.format = format
        self.quality = quality
        self.startTime = startTime
        self.itemCount = itemCount
    }

    var processedCount: Int { completedCount + failedCount + skippedCount }

    var progress: Double {
        guard itemCount > 0 else { return 0 }
        return Double(processedCount) / Double(itemCount)
    }

    var totalSavings: Int64 { completedOriginalSize - totalCompressedSize }

    var totalSavingsPercentage: Double {
        guard completedOriginalSize > 0 else { return 0 }
        return Double(totalSavings) / Double(completedOriginalSize) * 100.0
    }

    var elapsedTime: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    var isComplete: Bool { endTime != nil }
}

@Observable
class BatchJob {
    var items: [ImageItem] = []
    var isProcessing: Bool = false

    /// Incremented each time startCompression is called
    private(set) var currentRunId: Int = 0

    /// History of all runs in this session
    var runHistory: [RunSummary] = []

    /// The currently active run (nil if not processing)
    var activeRun: RunSummary? {
        runHistory.last(where: { !$0.isComplete })
    }

    // Aggregate counters across ALL runs
    var totalCompletedCount: Int { runHistory.reduce(0) { $0 + $1.completedCount } }
    var totalFailedCount: Int { runHistory.reduce(0) { $0 + $1.failedCount } }
    var totalSkippedCount: Int { runHistory.reduce(0) { $0 + $1.skippedCount } }
    var totalProcessedCount: Int { totalCompletedCount + totalFailedCount + totalSkippedCount }

    var totalSavings: Int64 { runHistory.reduce(0) { $0 + $1.totalSavings } }
    var totalSavingsPercentage: Double {
        let origSize = runHistory.reduce(Int64(0)) { $0 + $1.completedOriginalSize }
        guard origSize > 0 else { return 0 }
        let compSize = runHistory.reduce(Int64(0)) { $0 + $1.totalCompressedSize }
        return Double(origSize - compSize) / Double(origSize) * 100.0
    }

    // Keep these for backward compat with progress view
    var completedCount: Int { totalCompletedCount }
    var failedCount: Int { totalFailedCount }
    var skippedCount: Int { totalSkippedCount }

    var progress: Double {
        guard let run = activeRun else {
            // If no active run, show 1.0 if we have history
            return runHistory.isEmpty ? 0 : 1.0
        }
        return run.progress
    }

    var startTime: Date? { activeRun?.startTime ?? runHistory.last?.startTime }
    var endTime: Date? { activeRun == nil ? runHistory.last?.endTime : nil }

    var elapsedTime: TimeInterval {
        activeRun?.elapsedTime ?? runHistory.last?.elapsedTime ?? 0
    }

    /// Start a new run
    func startRun(format: String, quality: Int, itemCount: Int) {
        currentRunId += 1
        let run = RunSummary(
            id: currentRunId,
            format: format,
            quality: quality,
            startTime: Date(),
            itemCount: itemCount
        )
        runHistory.append(run)
    }

    /// Record a completion for the active run
    func recordCompletion(status: ProcessingStatus, originalSize: Int64, compressedSize: Int64?) {
        guard let run = activeRun else { return }
        switch status {
        case .completed:
            run.completedCount += 1
            run.completedOriginalSize += originalSize
            if let size = compressedSize {
                run.totalCompressedSize += size
            }
        case .failed:
            run.failedCount += 1
        case .skipped:
            run.skippedCount += 1
        default:
            break
        }
    }

    /// Finish the active run
    func finishRun() {
        activeRun?.endTime = Date()
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
        // Find the run that has failures and decrement
        if let run = runHistory.last(where: { $0.failedCount > 0 }) {
            run.failedCount -= 1
        }
    }

    /// Decrement skipped counter before retry
    func decrementSkipped() {
        if let run = runHistory.last(where: { $0.skippedCount > 0 }) {
            run.skippedCount -= 1
        }
    }

    /// Incremental original size — updated in addItems, not computed
    private(set) var totalOriginalSize: Int64 = 0

    var processedCount: Int { totalProcessedCount }

    func clear() {
        items.removeAll()
        isProcessing = false
        runHistory.removeAll()
        totalOriginalSize = 0
        currentRunId = 0
    }
}
