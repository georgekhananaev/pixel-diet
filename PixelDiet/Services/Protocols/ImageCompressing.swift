import Foundation

/// Must be nonisolated - implementations run on background threads in TaskGroup
nonisolated protocol ImageCompressing: Sendable {
    func compress(task: ImageTask, settings: SettingsSnapshot) throws -> CompressionResult
}
