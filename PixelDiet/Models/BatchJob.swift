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

    /// Incremented for every run and never reset, so run IDs stay unique even when
    /// Clear All is undone after newer runs
    private(set) var currentRunId: Int = 0

    /// History of all runs in this session
    var runHistory: [RunSummary] = []

    /// The currently active run (nil if not processing)
    var activeRun: RunSummary? {
        runHistory.last(where: { !$0.isComplete })
    }

    var progress: Double {
        guard let run = activeRun else {
            // If no active run, show 1.0 if we have history
            return runHistory.isEmpty ? 0 : 1.0
        }
        return run.progress
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

    /// Images and runs taken out of the queue by one action, with their former
    /// positions, so Undo can put them back.
    struct Removal {
        fileprivate let items: [(index: Int, item: ImageItem)]
        fileprivate let runs: [RunSummary]

        var itemIDs: Set<UUID> { Set(items.map(\.item.id)) }
    }

    /// Incremental original size - updated whenever items are added or removed, not computed
    private(set) var totalOriginalSize: Int64 = 0

    /// Adds images, skipping any whose file is already queued (also within `newItems`).
    /// Returns the items actually added.
    @discardableResult
    func addItems(_ newItems: [ImageItem]) -> [ImageItem] {
        var queued = Set(items.map(\.sourceURL))
        let unique = newItems.filter { queued.insert($0.sourceURL).inserted }
        items.append(contentsOf: unique)
        totalOriginalSize += unique.reduce(0) { $0 + $1.originalSize }
        return unique
    }

    @discardableResult
    func removeItems(withIDs ids: Set<UUID>) -> Removal {
        let removed = items.enumerated()
            .filter { ids.contains($0.element.id) }
            .map { (index: $0.offset, item: $0.element) }
        items.removeAll { ids.contains($0.id) }
        totalOriginalSize -= removed.reduce(0) { $0 + $1.item.originalSize }
        return Removal(items: removed, runs: [])
    }

    /// Empties the queue and the run history.
    @discardableResult
    func clear() -> Removal {
        let removal = Removal(items: items.enumerated().map { (index: $0.offset, item: $0.element) }, runs: runHistory)
        items.removeAll()
        runHistory.removeAll()
        totalOriginalSize = 0
        return removal
    }

    /// Records the size of an image's file after a run found it was replaced since it was added.
    func updateOriginalSize(of item: ImageItem, to size: Int64) {
        totalOriginalSize += size - item.originalSize
        item.originalSize = size
    }

    /// Puts back what `removal` took out: images at their former positions (skipping
    /// files that were added again since) and runs in ID order.
    func restore(_ removal: Removal) {
        var queued = Set(items.map(\.sourceURL))
        for (index, item) in removal.items where queued.insert(item.sourceURL).inserted {
            items.insert(item, at: min(index, items.count))
            totalOriginalSize += item.originalSize
        }
        let knownRuns = Set(runHistory.map(\.id))
        runHistory = (runHistory + removal.runs.filter { !knownRuns.contains($0.id) }).sorted { $0.id < $1.id }
    }

    /// Takes out again what `removal` took out (Redo), except images and the run that a batch
    /// in progress is working on. Returns what was taken out, for the next Undo.
    @discardableResult
    func reapply(_ removal: Removal) -> Removal {
        let busy = isProcessing ? Set(items.filter { $0.batchRunId == currentRunId }.map(\.id)) : []
        let removedItems = removeItems(withIDs: removal.itemIDs.subtracting(busy)).items
        let runIDs = Set(removal.runs.map(\.id))
        let removedRuns = runHistory.filter { runIDs.contains($0.id) && $0.isComplete }
        runHistory.removeAll { runIDs.contains($0.id) && $0.isComplete }
        return Removal(items: removedItems, runs: removedRuns)
    }
}
