import Foundation
import os

actor BatchProcessor {
    /// nonisolated: allows access from @Sendable closures without actor hop.
    /// This is safe because ImageCompressing is Sendable and compress() is pure.
    /// Without nonisolated, all compress() calls would serialize on actor executor,
    /// defeating TaskGroup parallelism. (Round 2 Fix: CR-2)
    nonisolated let compressor: any ImageCompressing

    init(compressor: any ImageCompressing = ImageCompressor()) {
        self.compressor = compressor
    }

    /// Peak memory while one image is compressed, measured with ImageIO and libwebp on 24 and
    /// 48 MP photos (release build, rounded up), per output pixel unless noted. Downscaling costs
    /// more per final pixel than full size (the decoder works at up to twice the final size), but
    /// never less than the source needs: progressive JPEG keeps all of it, interlaced PNG decodes
    /// it at full size.
    private nonisolated enum PeakBytes {
        static let fullSizeDecode: Double = 13
        static let fullSizeDecodeHighBitDepth: Double = 23
        static let downscaledDecode: Double = 28
        static let downscaledDecodeHighBitDepth: Double = 30
        static let perSourcePixel: Double = 1
        static let perSourcePixelInterlaced: Double = 4.5
        static let webpEncode: Double = 24
        static let webpEncodeWithAlpha: Double = 45
        static let avifEncode: Double = 14
        static let avifEncoderBase: Double = 75_000_000
    }

    /// Estimated peak memory to compress one image (at least 1 byte): the larger of decoding and
    /// encoding, for the size the image is resized to.
    nonisolated static func estimatedMemory(of task: ImageTask, maxDimension: Int) -> Int64 {
        let width = max(0, task.dimensions.width)
        let height = max(0, task.dimensions.height)
        let longestEdge = max(width, height)
        let isDownscaled = maxDimension > 0 && longestEdge > CGFloat(maxDimension)
        let scale = isDownscaled ? CGFloat(maxDimension) / longestEdge : 1
        let sourcePixels = Double(width) * Double(height)
        let outputPixels = Double((width * scale).rounded()) * Double((height * scale).rounded())
        let layout = task.pixelLayout

        let decode = isDownscaled
            ? max(
                outputPixels * (layout.isHighBitDepth ? PeakBytes.downscaledDecodeHighBitDepth : PeakBytes.downscaledDecode),
                sourcePixels * (layout.isInterlaced ? PeakBytes.perSourcePixelInterlaced : PeakBytes.perSourcePixel)
            )
            : outputPixels * (layout.isHighBitDepth ? PeakBytes.fullSizeDecodeHighBitDepth : PeakBytes.fullSizeDecode)
        let encode = switch task.outputFormat {
        case .webp: outputPixels * (layout.hasAlpha ? PeakBytes.webpEncodeWithAlpha : PeakBytes.webpEncode)
        case .avif: PeakBytes.avifEncoderBase + outputPixels * PeakBytes.avifEncode
        default: 0.0
        }
        let bytes = max(decode, encode)
        return bytes < Double(Int64.max) ? max(1, Int64(bytes)) : Int64.max
    }

    /// Process all tasks in parallel using TaskGroup.
    /// Receives Sendable structs only - no @Observable classes cross this boundary.
    /// `onItemComplete` is called exactly once per task with a terminal status;
    /// after cancellation, tasks that never started are reported as cancelled.
    func process(
        tasks: [ImageTask],
        settings: SettingsSnapshot,
        memoryBudget: Int64 = Constants.memoryBudget,
        onItemComplete: @escaping @MainActor @Sendable (UUID, ProcessingStatus, CompressionResult?) -> Void
    ) async {
        let cpuCount = ProcessInfo.processInfo.activeProcessorCount

        // Each child task returns its estimated memory so the slot can be released
        await withTaskGroup(of: Int64.self) { group in
            var running = 0
            var bytesInFlight: Int64 = 0

            for (index, task) in tasks.enumerated() {
                let cost = Self.estimatedMemory(of: task, maxDimension: settings.maxDimension)

                // Wait for a slot: at most one task per core, and the estimated memory of
                // running tasks within budget. An image larger than the whole budget runs alone.
                while running > 0 && (running >= cpuCount || cost > memoryBudget - bytesInFlight) {
                    guard let released = await group.next() else { break }
                    running -= 1
                    bytesInFlight -= released
                }

                // Cooperative cancellation: report every task that never started
                if Task.isCancelled {
                    for remaining in tasks[index...] {
                        await onItemComplete(remaining.id, .cancelled, nil)
                    }
                    break
                }

                running += 1
                bytesInFlight += cost

                group.addTask {
                    guard !Task.isCancelled else {
                        await onItemComplete(task.id, .cancelled, nil)
                        return cost
                    }

                    let compressor = self.compressor
                    do {
                        let result = try compressor.compress(task: task, settings: settings)
                        await onItemComplete(task.id, .completed, result)
                    } catch CompressionError.outputLargerThanOriginal {
                        await onItemComplete(
                            task.id,
                            .skipped(reason: CompressionError.outputLargerThanOriginal.localizedDescription),
                            nil
                        )
                    } catch {
                        Logger.batch.error("Failed: \(task.sourceURL.path) -> \(error.localizedDescription)")
                        await onItemComplete(task.id, .failed(error: error.localizedDescription), nil)
                    }
                    return cost
                }
            }
        }
    }
}
