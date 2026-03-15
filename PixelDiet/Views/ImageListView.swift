import SwiftUI
import UniformTypeIdentifiers

struct ImageListView: View {
    var viewModel: MainViewModel
    @Binding var selectedItems: Set<UUID>
    @Binding var previewItem: ImageItem?
    @State private var isDropTargeted = false
    @State private var sortAscending = true

    var body: some View {
        VStack(spacing: 0) {
            // Drop target banner for adding more files
            if !viewModel.batchJob.isProcessing {
                HStack {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.secondary)
                    Text(String(localized: "Drop more images here to add them"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(isDropTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
                .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                    handleDrop(providers: providers)
                    return true
                }

                Divider()
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sortedItems) { item in
                        ImageRow(item: item)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                            .background(
                                selectedItems.contains(item.id)
                                    ? Color.accentColor.opacity(0.15)
                                    : Color.clear
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                handleSelection(item: item)
                            }
                            .onTapGesture(count: 2) {
                                if case .completed = item.status {
                                    previewItem = item
                                }
                            }
                            .contextMenu {
                                contextMenuItems(for: item)
                            }
                            .onDrag {
                                if case .completed = item.status, let destURL = item.destinationURL {
                                    return NSItemProvider(object: destURL as NSURL)
                                }
                                return NSItemProvider(object: item.sourceURL as NSURL)
                            }

                        Divider()
                            .padding(.leading, 52)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: viewModel.batchJob.items.map(\.id))
            }

            // Summary bar at bottom
            HStack {
                Text(String(localized: "\(viewModel.batchJob.items.count) images"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(String(localized: "Total: \(ByteCountFormatter.string(fromByteCount: viewModel.batchJob.totalOriginalSize, countStyle: .file))"))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(.bar)
        }
    }

    @ViewBuilder
    private func contextMenuItems(for item: ImageItem) -> some View {
        Button {
            NSWorkspace.shared.activateFileViewerSelecting([item.sourceURL])
        } label: {
            Label(String(localized: "Reveal in Finder"), systemImage: "folder")
        }

        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.sourceURL.path, forType: .string)
        } label: {
            Label(String(localized: "Copy Path"), systemImage: "doc.on.doc")
        }

        if case .completed = item.status, let destURL = item.destinationURL {
            Divider()

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([destURL])
            } label: {
                Label(String(localized: "Reveal Output in Finder"), systemImage: "folder.badge.checkmark")
            }

            Text("Drag row to export compressed file")
                .foregroundStyle(.secondary)
        }

        Divider()

        Button(role: .destructive) {
            withAnimation(.easeInOut(duration: 0.25)) {
                viewModel.batchJob.items.removeAll { $0.id == item.id }
            }
        } label: {
            Label(String(localized: "Remove from Queue"), systemImage: "trash")
        }
    }

    private var sortedItems: [ImageItem] {
        if sortAscending {
            return viewModel.batchJob.items.sorted { $0.fileName.localizedCompare($1.fileName) == .orderedAscending }
        } else {
            return viewModel.batchJob.items.sorted { $0.fileName.localizedCompare($1.fileName) == .orderedDescending }
        }
    }

    private func handleSelection(item: ImageItem) {
        if NSEvent.modifierFlags.contains(.command) {
            if selectedItems.contains(item.id) {
                selectedItems.remove(item.id)
            } else {
                selectedItems.insert(item.id)
            }
        } else {
            selectedItems = [item.id]
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            guard provider.canLoadObject(ofClass: URL.self) else { continue }
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    urls.append(url)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            guard !urls.isEmpty else { return }
            Task {
                await viewModel.addFiles(urls: urls)
            }
        }
    }
}

// MARK: - Image Row

struct ImageRow: View {
    var item: ImageItem

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let thumbnail = item.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
            }

            // File info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(item.fileName)
                        .font(.body)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if item.isAnimated {
                        WarningBadge(text: String(localized: "Animated"))
                    }

                    if item.hasGPSData {
                        WarningBadge(text: String(localized: "GPS"))
                    }
                }

                HStack(spacing: 8) {
                    FileSizeLabel(bytes: item.originalSize)

                    if let format = item.effectiveFormat {
                        Text(format.displayName)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Text("\(Int(item.originalDimensions.width)) x \(Int(item.originalDimensions.height))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Savings
            if let savings = item.savingsPercentage {
                SavingsIndicator(percentage: savings)
            }

            if let compressedSize = item.formattedCompressedSize {
                Text(compressedSize)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .trailing)
            }

            // Status badge
            StatusBadge(status: item.status)
                .frame(width: 24)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts = [item.fileName, item.formattedOriginalSize]
        if let savings = item.savingsPercentage {
            parts.append(String(localized: "\(Int(savings)) percent saved"))
        }
        switch item.status {
        case .queued: parts.append(String(localized: "Queued"))
        case .processing: parts.append(String(localized: "Processing"))
        case .completed: parts.append(String(localized: "Completed"))
        case .skipped(let reason): parts.append(String(localized: "Skipped: \(reason)"))
        case .failed(let error): parts.append(String(localized: "Failed: \(error)"))
        case .warning(let message): parts.append(String(localized: "Warning: \(message)"))
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Warning Badge

struct WarningBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Color.yellow.opacity(0.2))
            .foregroundStyle(.yellow)
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}
