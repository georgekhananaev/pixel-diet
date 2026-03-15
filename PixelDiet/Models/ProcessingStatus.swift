/// Must be nonisolated — used in callbacks across actor boundaries
nonisolated enum ProcessingStatus: Equatable, Sendable {
    case queued
    case processing
    case completed
    case skipped(reason: String)
    case failed(error: String)
    case warning(message: String)
}
