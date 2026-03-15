import SwiftUI
import AppKit

struct ImagePreviewView: View, Equatable {
    let item: ImageItem

    @Environment(\.dismiss) private var dismiss
    @State private var originalImage: NSImage?
    @State private var compressedImage: NSImage?

    static func == (lhs: ImagePreviewView, rhs: ImagePreviewView) -> Bool {
        lhs.item.id == rhs.item.id
    }

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
            }
            .padding()

            Divider()

            // Image comparison
            HStack(spacing: 0) {
                // Original
                VStack(spacing: 12) {
                    Text(String(localized: "Original"))
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    imagePreview(image: originalImage)

                    VStack(spacing: 4) {
                        Text(item.formattedOriginalSize)
                            .font(.body.monospacedDigit())

                        Text("\(Int(item.originalDimensions.width)) x \(Int(item.originalDimensions.height))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let format = item.effectiveFormat {
                            Text(format.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let colorSpace = item.colorSpaceName {
                            Text(colorSpace)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()

                Divider()

                // Compressed
                VStack(spacing: 12) {
                    Text(String(localized: "Compressed"))
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    imagePreview(image: compressedImage)

                    VStack(spacing: 4) {
                        if let size = item.formattedCompressedSize {
                            Text(size)
                                .font(.body.monospacedDigit())
                        }

                        if let dims = item.compressedDimensions {
                            Text("\(Int(dims.width)) x \(Int(dims.height))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }

            Divider()

            // Footer with savings and actions
            HStack {
                if let savings = item.savingsPercentage {
                    HStack(spacing: 6) {
                        Image(systemName: savings >= 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                            .foregroundStyle(savings >= 0 ? .green : .red)

                        if let compressed = item.compressedSize {
                            let savedBytes = item.originalSize - compressed
                            Text(String(localized: "Savings: \(ByteCountFormatter.string(fromByteCount: abs(savedBytes), countStyle: .file)) (\(String(format: "%.0f", savings))%)"))
                                .font(.body.monospacedDigit())
                                .foregroundStyle(savings >= 0 ? .green : .red)
                        }
                    }
                }

                Spacer()

                if let destURL = item.destinationURL {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([destURL])
                    } label: {
                        Label(String(localized: "Reveal in Finder"), systemImage: "folder")
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
        .task {
            let sourceURL = item.sourceURL
            let destURL = item.destinationURL
            let (orig, comp) = await Task.detached {
                let orig = NSImage(contentsOf: sourceURL)
                let comp = destURL.flatMap { NSImage(contentsOf: $0) }
                return (orig, comp)
            }.value
            originalImage = orig
            compressedImage = comp
        }
    }

    @ViewBuilder
    private func imagePreview(image: NSImage?) -> some View {
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
                    ProgressView()
                }
        }
    }
}
