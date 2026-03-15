import SwiftUI

struct StatusBadge: View {
    let status: ProcessingStatus

    private var statusTrigger: Int {
        switch status {
        case .completed: return 1
        case .failed: return 2
        case .skipped: return 3
        case .warning: return 4
        default: return 0
        }
    }

    var body: some View {
        Group {
            switch status {
            case .queued:
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .accessibilityLabel(String(localized: "Queued"))

            case .processing:
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(String(localized: "Processing"))

            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
                    .symbolEffect(.bounce, value: statusTrigger)
                    .accessibilityLabel(String(localized: "Completed"))

            case .skipped:
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                    .symbolEffect(.bounce, value: statusTrigger)
                    .accessibilityLabel(String(localized: "Skipped"))

            case .failed(let error):
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                    .symbolEffect(.bounce, value: statusTrigger)
                    .accessibilityLabel(String(localized: "Failed"))
                    .help(error)

            case .warning(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
                    .symbolEffect(.bounce, value: statusTrigger)
                    .accessibilityLabel(String(localized: "Warning"))
                    .help(message)
            }
        }
        .contentTransition(.symbolEffect(.replace))
    }
}
