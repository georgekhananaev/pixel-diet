import SwiftUI
import AppKit

struct ImagePreviewView: View {
    let item: ImageItem

    @Environment(\.dismiss) private var dismiss
    @State private var originalImage: NSImage?
    @State private var compressedImage: NSImage?
    @State private var isLoading = true

    /// Longest edge used for preview decoding - plenty for a 280 pt pane on Retina
    private static let previewPixelSize: CGFloat = 1400

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(String(localized: "Before / After Preview"))
                    .font(.title3.bold())
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help(String(localized: "Close"))
                .accessibilityLabel(String(localized: "Close"))
            }
            .padding()

            Divider()

            // Image comparison
            HStack(spacing: 0) {
                // Original
                VStack(spacing: 12) {
                    Text(String(localized: "Original"))
                        .font(.headline)
                        .foregroundStyle(.secondaryText)

                    imagePane(
                        image: originalImage,
                        placeholder: String(localized: "The original file is no longer available.")
                    )

                    VStack(spacing: 4) {
                        Text(item.formattedOriginalSize)
                            .font(.body.monospacedDigit())

                        Text("\(Int(item.originalDimensions.width)) x \(Int(item.originalDimensions.height))")
                            .font(.caption)
                            .foregroundStyle(.secondaryText)

                        if let format = item.effectiveFormat {
                            Text(format.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondaryText)
                        }

                        if let colorSpace = item.colorSpaceName {
                            Text(colorSpace)
                                .font(.caption)
                                .foregroundStyle(.secondaryText)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding()

                Divider()

                // Compressed
                VStack(spacing: 12) {
                    Text(String(localized: "Compressed"))
                        .font(.headline)
                        .foregroundStyle(.secondaryText)

                    imagePane(image: compressedImage, placeholder: compressedPlaceholder)

                    VStack(spacing: 4) {
                        if let size = item.formattedCompressedSize {
                            Text(size)
                                .font(.body.monospacedDigit())
                        }

                        if let dims = item.compressedDimensions {
                            Text("\(Int(dims.width)) x \(Int(dims.height))")
                                .font(.caption)
                                .foregroundStyle(.secondaryText)
                        }

                        if let format = item.outputFormatUsed, item.destinationURL != nil {
                            Text(format)
                                .font(.caption)
                                .foregroundStyle(.secondaryText)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding()
            }

            Divider()

            // Footer with savings and actions
            HStack {
                if let savings = item.savingsPercentage, let compressed = item.compressedSize {
                    HStack(spacing: 6) {
                        Image(systemName: savings >= 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                            .foregroundStyle(savings >= 0 ? .success : .failure)

                        let savedBytes = item.originalSize - compressed
                        Text(String(localized: "Savings: \(ByteCountFormatter.string(fromByteCount: abs(savedBytes), countStyle: .file)) (\(SavingsIndicator.percentText(for: savings)))"))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(savings >= 0 ? .success : .failure)
                    }
                }

                Spacer()

                if let destURL = item.destinationURL {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([destURL])
                    } label: {
                        Label(String(localized: "Reveal Output in Finder"), systemImage: "folder")
                    }
                }

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([item.sourceURL])
                } label: {
                    Label(String(localized: "Show Original"), systemImage: "doc")
                }
            }
            .padding()
        }
        .frame(width: 700, height: 500)
        .task(id: item.destinationURL) {
            isLoading = true
            let sourceURL = item.sourceURL
            let destURL = item.destinationURL
            let maxPixelSize = Self.previewPixelSize
            let (original, compressed) = await Task.detached {
                (
                    ThumbnailService.downsampledImage(at: sourceURL, maxPixelSize: maxPixelSize),
                    destURL.flatMap { ThumbnailService.downsampledImage(at: $0, maxPixelSize: maxPixelSize) }
                )
            }.value
            originalImage = original.map { NSImage(cgImage: $0, size: .zero) }
            compressedImage = compressed.map { NSImage(cgImage: $0, size: .zero) }
            isLoading = false
        }
    }

    /// What the compressed pane shows when there is no output to display
    private var compressedPlaceholder: String {
        switch item.status {
        case .queued:
            String(localized: "Not compressed yet. Click Compress to create the output.")
        case .processing:
            String(localized: "Compressing…")
        case .completed:
            String(localized: "The compressed file is no longer available.")
        case .skipped(let reason):
            String(localized: "Skipped: \(reason)")
        case .failed(let error):
            String(localized: "Failed: \(error)")
        }
    }

    @ViewBuilder
    private func imagePane(image: NSImage?, placeholder: String) -> some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 280, maxHeight: 220)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(radius: 2)
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary)
                .frame(width: 280, height: 220)
                .overlay {
                    if isLoading || item.status == .processing {
                        ProgressView()
                    } else {
                        Text(placeholder)
                            .font(.callout)
                            .foregroundStyle(.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                }
        }
    }
}
