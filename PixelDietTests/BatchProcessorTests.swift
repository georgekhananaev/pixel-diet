import Testing
import Foundation
import CoreGraphics
@testable import PixelDiet

// MARK: - Test Doubles

/// Compressor whose outcome is decided per task; optionally slow, and records peak concurrency.
struct FakeCompressor: ImageCompressing {
    enum Outcome: Sendable {
        case success
        case failure
        case larger
    }

    let delay: TimeInterval
    let probe = ConcurrencyProbe()
    let outcome: @Sendable (ImageTask) -> Outcome

    init(delay: TimeInterval = 0, outcome: @escaping @Sendable (ImageTask) -> Outcome = { _ in .success }) {
        self.delay = delay
        self.outcome = outcome
    }

    func compress(task: ImageTask, settings: SettingsSnapshot) throws -> CompressionResult {
        let bytes = BatchProcessor.estimatedMemory(of: task, maxDimension: settings.maxDimension)
        // The real file's size when the task has one (view-model tests), like ImageCompressor
        let sourceSize = (try? FileManager.default.attributesOfItem(atPath: task.sourceURL.path))?[.size] as? Int64 ?? 1_000
        probe.enter(bytes: bytes)
        defer { probe.exit(bytes: bytes) }
        if delay > 0 { Thread.sleep(forTimeInterval: delay) }
        switch outcome(task) {
        case .success:
            let url = settings.outputDirectory.appendingPathComponent(task.sourceURL.lastPathComponent)
            return CompressionResult(sourceSize: sourceSize, outputURL: url, outputSize: sourceSize / 2, outputDimensions: CGSize(width: 10, height: 10))
        case .failure:
            throw CompressionError.writeFailed
        case .larger:
            throw CompressionError.outputLargerThanOriginal
        }
    }
}

/// Thread-safe tracker of simultaneous `compress` calls and their estimated decode memory.
final class ConcurrencyProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var current = 0
    private var peakValue = 0
    private var currentBytes: Int64 = 0
    private var peakBytesValue: Int64 = 0

    var peak: Int { lock.withLock { peakValue } }
    var peakBytes: Int64 { lock.withLock { peakBytesValue } }

    func enter(bytes: Int64) {
        lock.withLock {
            current += 1
            currentBytes += bytes
            peakValue = max(peakValue, current)
            peakBytesValue = max(peakBytesValue, currentBytes)
        }
    }

    func exit(bytes: Int64) {
        lock.withLock {
            current -= 1
            currentBytes -= bytes
        }
    }
}

@MainActor
final class CompletionRecorder {
    private(set) var events: [(id: UUID, status: ProcessingStatus, result: CompressionResult?)] = []

    func record(_ id: UUID, _ status: ProcessingStatus, _ result: CompressionResult?) {
        events.append((id, status, result))
    }
}

// MARK: - BatchProcessor Tests

@MainActor
struct BatchProcessorTests {
    private let settings = TestImages.settings(outputDirectory: URL(fileURLWithPath: "/tmp/pixeldiet-fake-output"))

    private func makeTasks(_ count: Int, pixelCount: Int = 1_000) -> [ImageTask] {
        makeTasks(Array(repeating: pixelCount, count: count))
    }

    /// Images `pixelCount` pixels wide and 1 high, compressed at full size (no max edge in `settings`)
    private func makeTasks(_ pixelCounts: [Int]) -> [ImageTask] {
        pixelCounts.enumerated().map { index, pixelCount in
            task(width: pixelCount, height: 1, index: index)
        }
    }

    private func task(
        width: Int, height: Int, format: ImageFormat = .jpeg, layout: PixelLayout = PixelLayout(), index: Int = 0
    ) -> ImageTask {
        ImageTask(
            id: UUID(),
            sourceURL: URL(fileURLWithPath: "/tmp/pixeldiet-fake-input/\(index).jpg"),
            relativePath: nil,
            outputFormat: format,
            dimensions: CGSize(width: width, height: height),
            pixelLayout: layout,
            precomputedDestination: nil
        )
    }

    @Test func everyTaskReportsExactlyOneTerminalStatus() async {
        let tasks = makeTasks(20)
        let failing = Set(tasks.prefix(5).map(\.id))
        let larger = Set(tasks.suffix(3).map(\.id))
        let processor = BatchProcessor(compressor: FakeCompressor { task in
            failing.contains(task.id) ? .failure : larger.contains(task.id) ? .larger : .success
        })
        let recorder = CompletionRecorder()

        await processor.process(tasks: tasks, settings: settings) { recorder.record($0, $1, $2) }

        #expect(recorder.events.count == 20)
        #expect(Set(recorder.events.map(\.id)) == Set(tasks.map(\.id)))
        let completed = recorder.events.filter { $0.status == .completed }
        #expect(completed.count == 12)
        #expect(completed.allSatisfy { $0.result != nil })
        #expect(recorder.events.filter { if case .failed = $0.status { true } else { false } }.count == 5)
    }

    @Test func outputLargerIsReportedAsSkipped() async {
        let tasks = makeTasks(1)
        let processor = BatchProcessor(compressor: FakeCompressor { _ in .larger })
        let recorder = CompletionRecorder()

        await processor.process(tasks: tasks, settings: settings) { recorder.record($0, $1, $2) }

        #expect(recorder.events.map(\.status) == [.skipped(reason: CompressionError.outputLargerThanOriginal.localizedDescription)])
    }

    @Test func cancellationReportsEveryTaskExactlyOnce() async throws {
        // More tasks than cores, so some are still waiting when the run is cancelled
        let count = max(40, ProcessInfo.processInfo.activeProcessorCount * 3)
        let tasks = makeTasks(count)
        let processor = BatchProcessor(compressor: FakeCompressor(delay: 0.05))
        let recorder = CompletionRecorder()

        let run = Task { await processor.process(tasks: tasks, settings: settings) { recorder.record($0, $1, $2) } }
        while recorder.events.isEmpty {
            try await Task.sleep(for: .milliseconds(5))
        }
        run.cancel()
        await run.value

        #expect(recorder.events.count == count)
        #expect(Set(recorder.events.map(\.id)).count == count)
        #expect(recorder.events.contains { $0.status == .cancelled })
    }

    @Test func concurrencyIsBoundedByDecodedPixelMemory() async {
        // 48 MP photos: hundreds of MB each while compressed, though only a few MB on disk
        let tasks = makeTasks(16, pixelCount: 48_000_000)
        let budget = 5 * BatchProcessor.estimatedMemory(of: tasks[0], maxDimension: 0)
        let compressor = FakeCompressor(delay: 0.02)
        let processor = BatchProcessor(compressor: compressor)

        await processor.process(tasks: tasks, settings: settings, memoryBudget: budget) { _, _, _ in }

        #expect(compressor.probe.peak <= 5)
    }

    @Test func mixedBatchKeepsDecodedMemoryWithinBudget() async {
        // 100 MP panoramas mixed with many small images: the average is small,
        // but the large ones must not run together beyond the memory budget.
        let tasks = makeTasks(Array(repeating: 100_000_000, count: 12) + Array(repeating: 1_000_000, count: 200))
        let budget: Int64 = 2_000_000_000
        let compressor = FakeCompressor(delay: 0.01)
        let processor = BatchProcessor(compressor: compressor)

        await processor.process(tasks: tasks, settings: settings, memoryBudget: budget) { _, _, _ in }

        #expect(compressor.probe.peakBytes <= budget)
    }

    @Test func oversizedImageStillRunsAlone() async {
        // Larger than the whole budget: must still be processed (on its own), not deadlock.
        let tasks = makeTasks([400_000_000, 1_000_000, 400_000_000])
        let compressor = FakeCompressor(delay: 0.01)
        let processor = BatchProcessor(compressor: compressor)
        let recorder = CompletionRecorder()

        await processor.process(tasks: tasks, settings: settings, memoryBudget: 1_000_000_000) { recorder.record($0, $1, $2) }

        #expect(recorder.events.count == 3)
        #expect(compressor.probe.peakBytes <= BatchProcessor.estimatedMemory(of: tasks[0], maxDimension: 0))
    }

    /// Peaks measured with ImageIO and libwebp on 24 and 48 MP photos (release build)
    @Test func estimatedMemoryFollowsMeasuredPeaks() {
        let estimate = BatchProcessor.estimatedMemory(of:maxDimension:)
        let photo = task(width: 8000, height: 6000)
        #expect(estimate(photo, 0) == 48_000_000 * 13)
        #expect(estimate(photo, 9000) == 48_000_000 * 13, "Smaller than the limit: full size")
        #expect(estimate(photo, 1920) == 1920 * 1440 * 28, "Downscaled while decoding")
        #expect(estimate(photo, 640) == 48_000_000, "The decoder still reads the whole source: at least 1 B per source pixel")

        let deep = task(width: 8000, height: 6000, layout: PixelLayout(isHighBitDepth: true))
        #expect(estimate(deep, 0) == 48_000_000 * 23)
        #expect(estimate(deep, 1920) == 1920 * 1440 * 30)
        let interlaced = task(width: 8000, height: 6000, layout: PixelLayout(isInterlaced: true))
        #expect(estimate(interlaced, 1920) == 216_000_000, "Interlaced PNG is decoded at full size before downscaling")

        #expect(estimate(task(width: 6000, height: 4000, format: .webp), 0) == 24_000_000 * 24)
        #expect(estimate(task(width: 6000, height: 4000, format: .webp, layout: PixelLayout(hasAlpha: true)), 0) == 24_000_000 * 45)
        #expect(estimate(task(width: 6000, height: 4000, format: .avif), 0) == 75_000_000 + 24_000_000 * 14)

        #expect(estimate(task(width: 0, height: 0), 0) == 1)
        #expect(estimate(task(width: Int.max / 2, height: 1), 0) == Int64.max)
    }

    @Test func memoryBudgetIsAQuarterOfTheMacsMemory() {
        #expect(Constants.memoryBudget == Int64(ProcessInfo.processInfo.physicalMemory / 4))
    }
}
