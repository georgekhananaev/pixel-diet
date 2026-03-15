import SwiftUI
import AppKit

struct BatchProgressView: View {
    var batchJob: BatchJob
    var onDismiss: (() -> Void)? = nil
    @State private var expandedRunId: Int?
    @State private var showingDetail: StatusDetailInfo?

    struct StatusDetailInfo: Identifiable {
        let id = UUID()
        let runId: Int
        let statusType: StatusType
    }

    enum StatusType {
        case completed, failed, skipped
    }

    var body: some View {
        VStack(spacing: 8) {
            // Show each run as its own row - newest first
            ForEach(batchJob.runHistory.reversed()) { run in
                RunRow(
                    run: run,
                    isExpanded: expandedRunId == run.id,
                    isCurrent: run.id == batchJob.currentRunId,
                    onToggleExpand: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedRunId = expandedRunId == run.id ? nil : run.id
                        }
                    },
                    onStatTap: { statusType in
                        showingDetail = StatusDetailInfo(runId: run.id, statusType: statusType)
                    }
                )
            }

            // Dismiss button when not processing
            if !batchJob.isProcessing && !batchJob.runHistory.isEmpty {
                HStack {
                    Spacer()
                    Button {
                        if let outputDir = BookmarkManager.resolveBookmark() {
                            NSWorkspace.shared.open(outputDir)
                            BookmarkManager.stopAccessing(outputDir)
                        }
                    } label: {
                        Label(String(localized: "Open Output Folder"), systemImage: "folder")
                    }
                    .controlSize(.small)
                    Button {
                        onDismiss?()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(String(localized: "Dismiss"))
                    .accessibilityLabel(String(localized: "Dismiss"))
                }
            }
        }
        .sheet(item: $showingDetail) { info in
            StatusDetailSheet(
                batchJob: batchJob,
                runId: info.runId,
                statusType: info.statusType
            )
        }
    }
}

// MARK: - Run Row

struct RunRow: View {
    var run: RunSummary
    var isExpanded: Bool
    var isCurrent: Bool
    var onToggleExpand: () -> Void
    var onStatTap: (BatchProgressView.StatusType) -> Void

    var body: some View {
        VStack(spacing: 6) {
            // Header - always visible, clickable to expand
            HStack(spacing: 8) {
                // Expand arrow for completed runs
                if run.isComplete {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(width: 10)
                }

                // Run indicator
                if run.isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else {
                    ProgressView()
                        .controlSize(.mini)
                }

                // Format + quality badge
                Text("\(run.format) Q\(run.quality)")
                    .font(.caption.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                // Counts
                Text("\(run.completedCount)/\(run.itemCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                if run.skippedCount > 0 {
                    Text("(\(run.skippedCount) skipped)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if run.failedCount > 0 {
                    Text("(\(run.failedCount) failed)")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()

                // Savings
                if run.totalSavings > 0 {
                    Text(String(localized: "Saved \(ByteCountFormatter.string(fromByteCount: run.totalSavings, countStyle: .file))"))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.green)
                }

                // Time
                Text(formattedTime(run.elapsedTime))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if run.isComplete {
                    onToggleExpand()
                }
            }

            // Progress bar for active run
            if !run.isComplete {
                ProgressView(value: run.progress)
                    .tint(run.failedCount > 0 ? .orange : .accentColor)
            }

            // Expanded detail - clickable stats
            if isExpanded && run.isComplete {
                HStack(spacing: 16) {
                    StatButton(
                        icon: "checkmark.circle.fill", color: .green,
                        label: "\(run.completedCount) completed"
                    ) { onStatTap(.completed) }

                    if run.failedCount > 0 {
                        StatButton(
                            icon: "xmark.circle.fill", color: .red,
                            label: "\(run.failedCount) failed"
                        ) { onStatTap(.failed) }
                    }

                    if run.skippedCount > 0 {
                        StatButton(
                            icon: "arrow.right.circle.fill", color: .orange,
                            label: "\(run.skippedCount) skipped"
                        ) { onStatTap(.skipped) }
                    }

                    Spacer()

                    if run.totalSavings != 0 {
                        Text(String(format: "%.1f%%", run.totalSavingsPercentage))
                            .font(.caption.monospacedDigit().bold())
                            .foregroundStyle(run.totalSavings > 0 ? .green : .red)
                    }
                }
                .padding(.leading, run.isComplete ? 18 : 0)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(8)
        .background(isCurrent && !run.isComplete ? Color.accentColor.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onAppear {
            if run.isComplete && isCurrent {
                NSSound(named: "Glass")?.play()
            }
        }
    }

    private func formattedTime(_ interval: TimeInterval) -> String {
        let m = Int(interval) / 60
        let s = Int(interval) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Stat Button

struct StatButton: View {
    let icon: String
    let color: Color
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.caption)
                Text(String(localized: "\(label)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

// MARK: - Status Detail Sheet

struct StatusDetailSheet: View {
    var batchJob: BatchJob
    var runId: Int
    var statusType: BatchProgressView.StatusType
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: headerIcon)
                    .foregroundStyle(headerColor)
                    .font(.title3)
                Text(headerTitle)
                    .font(.headline)
                Text("- Run #\(runId)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(localized: "\(filteredItems.count) items"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            if filteredItems.isEmpty {
                Spacer()
                Text(String(localized: "No items"))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List(filteredItems) { item in
                    DetailRow(item: item, statusType: statusType)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .frame(width: 500, height: 400)
    }

    private var filteredItems: [ImageItem] {
        batchJob.items.filter { item in
            guard item.batchRunId == runId else { return false }
            switch statusType {
            case .completed:
                if case .completed = item.status { return true }
                return false
            case .failed:
                if case .failed = item.status { return true }
                return false
            case .skipped:
                if case .skipped = item.status { return true }
                return false
            }
        }
    }

    private var headerIcon: String {
        switch statusType {
        case .completed: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .skipped: "arrow.right.circle.fill"
        }
    }

    private var headerColor: Color {
        switch statusType {
        case .completed: .green
        case .failed: .red
        case .skipped: .orange
        }
    }

    private var headerTitle: String {
        switch statusType {
        case .completed: String(localized: "Completed")
        case .failed: String(localized: "Failed")
        case .skipped: String(localized: "Skipped")
        }
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    var item: ImageItem
    var statusType: BatchProgressView.StatusType

    var body: some View {
        HStack(spacing: 10) {
            if let thumbnail = item.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.quaternary)
                    .frame(width: 28, height: 28)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.fileName)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(reasonText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if statusType == .completed {
                if let savings = item.savingsPercentage {
                    SavingsIndicator(percentage: savings)
                }
                if let size = item.formattedCompressedSize {
                    Text(size)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var reasonText: String {
        switch item.status {
        case .completed:
            let original = ByteCountFormatter.string(fromByteCount: item.originalSize, countStyle: .file)
            let compressed = item.formattedCompressedSize ?? "?"
            let dims = item.compressedDimensions.map { "\(Int($0.width))×\(Int($0.height))" } ?? ""
            return "\(original) → \(compressed)  \(dims)"
        case .failed(let error):
            return error
        case .skipped(let reason):
            return reason
        default:
            return ""
        }
    }
}
