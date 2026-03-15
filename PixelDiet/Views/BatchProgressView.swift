import SwiftUI
import AppKit

struct BatchProgressView: View {
    var batchJob: BatchJob
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 10) {
            // Progress bar
            ProgressView(value: batchJob.progress) {
                HStack {
                    if batchJob.isProcessing {
                        Text(String(localized: "Processing..."))
                            .font(.caption.bold())
                    } else if batchJob.endTime != nil {
                        Text(String(localized: "Complete"))
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                    }

                    Spacer()

                    Text(String(localized: "\(batchJob.processedCount) of \(batchJob.items.count)"))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .tint(progressTint)

            // Stats row
            HStack(spacing: 16) {
                // Completed
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text(String(localized: "\(batchJob.completedCount) completed"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Failed
                if batchJob.failedCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                        Text(String(localized: "\(batchJob.failedCount) failed"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Skipped
                if batchJob.skippedCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Text(String(localized: "\(batchJob.skippedCount) skipped"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Elapsed time
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formattedElapsedTime)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                // Total savings
                if batchJob.totalSavings > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text(String(localized: "Saved \(ByteCountFormatter.string(fromByteCount: batchJob.totalSavings, countStyle: .file)) (\(String(format: "%.0f", batchJob.totalSavingsPercentage))%)"))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.green)
                    }
                }
            }

            // Completion summary banner
            if !batchJob.isProcessing && batchJob.endTime != nil {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)

                    Text(String(localized: "\(batchJob.completedCount) images compressed. Saved \(ByteCountFormatter.string(fromByteCount: batchJob.totalSavings, countStyle: .file)) (\(String(format: "%.0f", batchJob.totalSavingsPercentage))%)"))
                        .font(.callout)

                    Spacer()

                    if let outputDir = BookmarkManager.resolveBookmark() {
                        Button {
                            NSWorkspace.shared.open(outputDir)
                            BookmarkManager.stopAccessing(outputDir)
                        } label: {
                            Label(String(localized: "Open Output Folder"), systemImage: "folder")
                        }
                        .controlSize(.small)
                    }

                    Button {
                        onDismiss?()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .help("Dismiss")
                }
                .padding(10)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onAppear {
                    NSSound(named: "Glass")?.play()
                }
            }
        }
    }

    private var progressTint: Color {
        if batchJob.failedCount > 0 && !batchJob.isProcessing {
            return .orange
        }
        return .accentColor
    }

    private var formattedElapsedTime: String {
        let elapsed = batchJob.elapsedTime
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
