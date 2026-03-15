import SwiftUI
import UniformTypeIdentifiers

struct ImageListView: View {
    var viewModel: MainViewModel
    @Binding var selectedItems: Set<UUID>
    @Binding var previewItem: ImageItem?
    @State private var isDropTargeted = false

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

            List(selection: $selectedItems) {
                ForEach(groupedSections) { section in
                    Section {
                        ForEach(section.items) { item in
                            ImageRow(
                                item: item,
                                onMenuAction: { action in
                                    handleMenuAction(action, for: item)
                                }
                            )
                            .tag(item.id)
                            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                            .contextMenu {
                                contextMenuItems(for: item)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    withAnimation {
                                        viewModel.batchJob.items.removeAll { $0.id == item.id }
                                    }
                                } label: {
                                    Label(String(localized: "Remove"), systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        if let header = section.header {
                            Text(header)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .onDeleteCommand {
                guard !selectedItems.isEmpty else { return }
                withAnimation {
                    viewModel.batchJob.items.removeAll { selectedItems.contains($0.id) }
                }
                selectedItems.removeAll()
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

    // MARK: - Sections

    private struct ListSection: Identifiable {
        let id: Int // run ID, or -1 for pending
        let header: String?
        let items: [ImageItem]
    }

    private var groupedSections: [ListSection] {
        // Group items by batchRunId in a single pass
        var pending: [ImageItem] = []
        var runGroups: [Int: (items: [ImageItem], completedCount: Int)] = [:]

        for item in viewModel.batchJob.items {
            if let runId = item.batchRunId {
                var group = runGroups[runId] ?? (items: [], completedCount: 0)
                group.items.append(item)
                if case .completed = item.status { group.completedCount += 1 }
                runGroups[runId] = group
            } else {
                pending.append(item)
            }
        }

        var sections: [ListSection] = []

        // Pending items first with no header
        if !pending.isEmpty {
            sections.append(ListSection(id: -1, header: nil, items: pending))
        }

        // Completed runs, newest first
        for runId in runGroups.keys.sorted(by: >) {
            let group = runGroups[runId]!
            let format = group.items.first?.outputFormatUsed ?? "-"
            let header = "Run #\(runId) - \(format) - \(group.completedCount)/\(group.items.count) completed"
            sections.append(ListSection(id: runId, header: header, items: group.items))
        }

        return sections
    }

    // MARK: - Menu Actions

    enum MenuAction {
        case revealSource
        case revealOutput
        case copyPath
        case remove
    }

    private func handleMenuAction(_ action: MenuAction, for item: ImageItem) {
        switch action {
        case .revealSource:
            NSWorkspace.shared.activateFileViewerSelecting([item.sourceURL])
        case .revealOutput:
            if let destURL = item.destinationURL {
                NSWorkspace.shared.activateFileViewerSelecting([destURL])
            }
        case .copyPath:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.sourceURL.path, forType: .string)
        case .remove:
            withAnimation {
                viewModel.batchJob.items.removeAll { $0.id == item.id }
            }
        }
    }

    @ViewBuilder
    private func contextMenuItems(for item: ImageItem) -> some View {
        Button {
            handleMenuAction(.revealSource, for: item)
        } label: {
            Label(String(localized: "Reveal in Finder"), systemImage: "folder")
        }

        Button {
            handleMenuAction(.copyPath, for: item)
        } label: {
            Label(String(localized: "Copy Path"), systemImage: "doc.on.doc")
        }

        if case .completed = item.status, item.destinationURL != nil {
            Divider()

            Button {
                handleMenuAction(.revealOutput, for: item)
            } label: {
                Label(String(localized: "Reveal Output in Finder"), systemImage: "folder.badge.checkmark")
            }
        }

        Divider()

        Button(role: .destructive) {
            handleMenuAction(.remove, for: item)
        } label: {
            Label(String(localized: "Remove from Queue"), systemImage: "trash")
        }
    }

    // MARK: - Drop

    private func handleDrop(providers: [NSItemProvider]) {
        let queue = DispatchQueue(label: "com.georgekhananaev.PixelDiet.drop")
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            guard provider.canLoadObject(ofClass: URL.self) else { continue }
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    queue.sync { urls.append(url) }
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
    var onMenuAction: ((ImageListView.MenuAction) -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            // Thumbnail
            if let thumbnail = item.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
            }

            // File info
            VStack(alignment: .leading, spacing: 1) {
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

                HStack(spacing: 6) {
                    FileSizeLabel(bytes: item.originalSize)

                    if let format = item.effectiveFormat {
                        Text(format.displayName)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Text("\(Int(item.originalDimensions.width))×\(Int(item.originalDimensions.height))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Savings
            if let savings = item.savingsPercentage {
                SavingsIndicator(percentage: savings)
                    .accessibilityLabel(String(localized: "\(Int(savings)) percent savings"))
            }

            if let compressedSize = item.formattedCompressedSize {
                Text(compressedSize)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 65, alignment: .trailing)
                    .accessibilityLabel(String(localized: "Compressed size \(compressedSize)"))
            }

            // Status badge
            StatusBadge(status: item.status)
                .frame(width: 20)

            // Menu button
            Menu {
                if let onMenuAction {
                    Button {
                        onMenuAction(.revealSource)
                    } label: {
                        Label(String(localized: "Reveal in Finder"), systemImage: "folder")
                    }

                    Button {
                        onMenuAction(.copyPath)
                    } label: {
                        Label(String(localized: "Copy Path"), systemImage: "doc.on.doc")
                    }

                    if case .completed = item.status, item.destinationURL != nil {
                        Divider()
                        Button {
                            onMenuAction(.revealOutput)
                        } label: {
                            Label(String(localized: "Reveal Output"), systemImage: "folder.badge.checkmark")
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        onMenuAction(.remove)
                    } label: {
                        Label(String(localized: "Remove"), systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 22)
            .help(String(localized: "Actions"))
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
