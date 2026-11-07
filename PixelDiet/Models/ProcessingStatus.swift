import Foundation

/// Must be nonisolated - used in callbacks across actor boundaries
nonisolated enum ProcessingStatus: Equatable, Sendable {
    case queued
    case processing
    case completed
    case skipped(reason: String)
    case failed(error: String)

    /// An image the run never got to because it was cancelled
    static let cancelled = ProcessingStatus.failed(error: CompressionError.cancelled.localizedDescription)
}
