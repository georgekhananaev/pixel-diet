import SwiftUI

struct StatusBadge: View {
    let status: ProcessingStatus

    private var statusTrigger: Int {
        switch status {
        case .completed: return 1
        case .failed: return 2
        case .skipped: return 3
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
                    .foregroundStyle(.success)
                    .font(.caption)
                    .symbolEffect(.bounce, value: statusTrigger)
                    .accessibilityLabel(String(localized: "Completed"))

            case .skipped:
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(.caution)
                    .font(.caption)
                    .symbolEffect(.bounce, value: statusTrigger)
                    .accessibilityLabel(String(localized: "Skipped"))

            case .failed(let error):
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.failure)
                    .font(.caption)
                    .symbolEffect(.bounce, value: statusTrigger)
                    .accessibilityLabel(String(localized: "Failed"))
                    .help(error)
            }
        }
        .contentTransition(.symbolEffect(.replace))
    }
}
