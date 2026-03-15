import Foundation
import os

actor BatchProcessor {
    /// nonisolated: allows access from @Sendable closures without actor hop.
    /// This is safe because ImageCompressing is Sendable and compress() is pure.
    /// Without nonisolated, all compress() calls would serialize on actor executor,
    /// defeating TaskGroup parallelism. (Round 2 Fix: CR-2)
    nonisolated let compressor: any ImageCompressing
    private let logger = Logger(subsystem: "com.georgekhananaev.PixelDiet", category: "batch")

    init(compressor: any ImageCompressing = ImageCompressor()) {
        self.compressor = compressor
    }

    /// Process all tasks in parallel using TaskGroup.
    /// Receives Sendable structs only — no @Observable classes cross this boundary.
    func process(
        tasks: [ImageTask],
        settings: SettingsSnapshot,
        onItemComplete: @escaping @MainActor @Sendable (UUID, ProcessingStatus, Int64?, CGSize?) -> Void
    ) async {
        // Adaptive concurrency based on memory estimation
        // Use task.originalSize * 4 as proxy for decoded memory, with 1GB budget
        let memoryBudget: Int64 = 1_073_741_824 // 1 GB
        let cpuCount = ProcessInfo.processInfo.activeProcessorCount
        let averageTaskMemory = tasks.isEmpty ? Int64(1) : max(1, (tasks.reduce(Int64(0)) { $0 + $1.originalSize } / Int64(tasks.count)) * 4)
        let memoryBasedConcurrency = max(1, Int(memoryBudget / averageTaskMemory))
        let maxConcurrency = min(cpuCount, memoryBasedConcurrency)

        await withTaskGroup(of: Void.self) { group in
            var running = 0

            for task in tasks {
                // Cooperative cancellation
                if Task.isCancelled { break }

                // Skip animated GIFs / multi-page TIFFs with warning
                if task.frameCount > 1 {
                    await onItemComplete(
                        task.id,
                        .warning(message: "Multi-frame image — only first frame processed"),
                        nil, nil
                    )
                }

                // Throttle concurrency
                if running >= maxConcurrency {
                    await group.next()
                    running -= 1
                }

                running += 1

                group.addTask {
                    // Check cancellation inside each task too
                    guard !Task.isCancelled else {
                        await onItemComplete(task.id, .failed(error: "Cancelled"), nil, nil)
                        return
                    }

                    let compressor = self.compressor
                    do {
                        let result = try compressor.compress(task: task, settings: settings)

                        // Use > not >= (same-size ok for format conversion)
                        if settings.skipIfLarger && result.outputSize > task.originalSize {
                            try? FileManager.default.removeItem(at: result.outputURL)
                            await onItemComplete(
                                task.id,
                                .skipped(reason: "Output larger than original"),
                                nil, nil
                            )
                        } else {
                            await onItemComplete(
                                task.id,
                                .completed,
                                result.outputSize,
                                result.outputDimensions
                            )
                        }
                    } catch {
                        self.logger.error("Failed: \(task.sourceURL.lastPathComponent): \(error)")
                        await onItemComplete(
                            task.id,
                            .failed(error: error.localizedDescription),
                            nil, nil
                        )
                    }
                }
            }
        }
    }
}
