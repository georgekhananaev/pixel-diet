import SwiftUI
import UniformTypeIdentifiers

struct ImageListView: View {
    var viewModel: MainViewModel
    @Binding var selectedItems: Set<UUID>
    @Binding var previewItem: ImageItem?
    @Environment(\.undoManager) private var undoManager
    @State private var isDropTargeted = false

    /// Images can't be removed while a run is writing them
    private var canRemove: Bool { !viewModel.batchJob.isProcessing }

    var body: some View {
        VStack(spacing: 0) {
            // Drop target banner for adding more files
            if !viewModel.batchJob.isProcessing {
                HStack {
                    if viewModel.isImporting {
                        ProgressView()
                            .controlSize(.small)
                        Text(String(localized: "Adding images…"))
                            .font(.caption)
                            .foregroundStyle(.secondaryText)
                    } else {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.secondary)
                        Text(String(localized: "Drop more images here to add them"))
                            .font(.caption)
                            .foregroundStyle(.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(isDropTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
                .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                    viewModel.addDroppedItems(providers)
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
                                canRemove: canRemove,
                                onMenuAction: { action in
                                    handleMenuAction(action, for: item)
                                }
                            )
                            .tag(item.id)
                            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                            .swipeActions(edge: .trailing) {
                                if canRemove {
                                    Button(role: .destructive) {
                                        handleMenuAction(.remove, for: item)
                                    } label: {
                                        Label(String(localized: "Remove"), systemImage: "trash")
                                    }
                                }
                            }
                        }
                    } header: {
                        if let runId = section.runId {
                            RunSectionHeader(runId: runId, items: section.items)
                        }
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .accessibilityLabel(String(localized: "Images"))
            // Right-click menu for the clicked or selected rows; double-click / Return previews
            .contextMenu(forSelectionType: UUID.self) { ids in
                let targets = items(withIDs: ids)
                if let item = targets.first, targets.count == 1 {
                    ImageActions(item: item, canRemove: canRemove, perform: { handleMenuAction($0, for: item) })
                } else if !targets.isEmpty {
                    Button(role: .destructive) {
                        remove(ids)
                    } label: {
                        Label(String(localized: "Remove \(targets.count) from Queue"), systemImage: "trash")
                    }
                    .disabled(!canRemove)
                }
            } primaryAction: { ids in
                previewItem = items(withIDs: ids).first
            }
            .onDeleteCommand {
                remove(selectedItems)
            }
            // Space previews the selected image, like Quick Look in Finder
            .onKeyPress(.space) {
                guard selectedItems.count == 1, let item = items(withIDs: selectedItems).first else {
                    return .ignored
                }
                previewItem = item
                return .handled
            }

            // Summary bar at bottom
            HStack {
                Text(CountText.images(viewModel.batchJob.items.count))
                    .font(.caption)
                    .foregroundStyle(.secondaryText)

                Spacer()

                Text(String(localized: "Total: \(ByteCountFormatter.string(fromByteCount: viewModel.batchJob.totalOriginalSize, countStyle: .file))"))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(.bar)
        }
    }

    // MARK: - Sections

    private struct ListSection: Identifiable {
        /// nil for the images not compressed yet
        let runId: Int?
        let items: [ImageItem]

        var id: Int { runId ?? -1 }
    }

    /// Images not compressed yet first, then one section per run, newest first. Reads only which
    /// run each image belongs to, so a finished image redraws its row and header, not the whole list.
    private var groupedSections: [ListSection] {
        var pending: [ImageItem] = []
        var runGroups: [Int: [ImageItem]] = [:]
        for item in viewModel.batchJob.items {
            if let runId = item.batchRunId {
                runGroups[runId, default: []].append(item)
            } else {
                pending.append(item)
            }
        }
        let runs = runGroups.keys.sorted(by: >).map { ListSection(runId: $0, items: runGroups[$0] ?? []) }
        return pending.isEmpty ? runs : [ListSection(runId: nil, items: pending)] + runs
    }

    private func items(withIDs ids: Set<UUID>) -> [ImageItem] {
        viewModel.batchJob.items.filter { ids.contains($0.id) }
    }

    /// Removes images (undoable with Cmd+Z); does nothing while compressing.
    private func remove(_ ids: Set<UUID>) {
        guard canRemove, !ids.isEmpty else { return }
        withAnimation {
            viewModel.removeItems(ids: ids, undoManager: undoManager)
        }
        selectedItems.subtract(ids)
    }

    // MARK: - Menu Actions

    enum MenuAction {
        case preview
        case revealSource
        case revealOutput
        case copyPath
        case remove
    }

    private func handleMenuAction(_ action: MenuAction, for item: ImageItem) {
        switch action {
        case .preview:
            previewItem = item
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
            remove([item.id])
        }
    }
}

// MARK: - Run Section Header

/// "Run #2 - WebP - 8/10 completed". Counted here, so a status change redraws only the header.
private struct RunSectionHeader: View {
    let runId: Int
    let items: [ImageItem]

    var body: some View {
        let format = items.first?.outputFormatUsed ?? "-"
        let completed = items.count(where: { $0.status == .completed })
        Text(String(localized: "Run #\(runId) - \(format) - \(completed)/\(items.count) completed"))
            .font(.caption)
            .foregroundStyle(.secondaryText)
    }
}

// MARK: - Image Actions

/// Per-image actions, shared by the row's context menu and its ellipsis menu.
private struct ImageActions: View {
    let item: ImageItem
    let canRemove: Bool
    let perform: (ImageListView.MenuAction) -> Void

    var body: some View {
        Button {
            perform(.preview)
        } label: {
            Label(String(localized: "Preview"), systemImage: "eye")
        }

        Divider()

        Button {
            perform(.revealSource)
        } label: {
            Label(String(localized: "Reveal in Finder"), systemImage: "folder")
        }

        Button {
            perform(.copyPath)
        } label: {
            Label(String(localized: "Copy Path"), systemImage: "doc.on.doc")
        }

        if case .completed = item.status, item.destinationURL != nil {
            Button {
                perform(.revealOutput)
            } label: {
                Label(String(localized: "Reveal Output in Finder"), systemImage: "folder.badge.checkmark")
            }
        }

        Divider()

        Button(role: .destructive) {
            perform(.remove)
        } label: {
            Label(String(localized: "Remove from Queue"), systemImage: "trash")
        }
        .disabled(!canRemove)
    }
}

// MARK: - Image Row

struct ImageRow: View {
    var item: ImageItem
    var canRemove: Bool
    var onMenuAction: (ImageListView.MenuAction) -> Void

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
                            .help(String(localized: "Only the first frame is compressed"))
                    }

                    if item.hasGPSData {
                        WarningBadge(text: String(localized: "GPS"))
                            .help(String(localized: "Contains GPS location data"))
                    }
                }

                HStack(spacing: 6) {
                    FileSizeLabel(bytes: item.originalSize)

                    if let format = item.effectiveFormat {
                        Text(format.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondaryText)
                    }

                    Text("\(Int(item.originalDimensions.width))×\(Int(item.originalDimensions.height))")
                        .font(.caption)
                        .foregroundStyle(.secondaryText)
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
                    .foregroundStyle(.secondaryText)
                    .frame(width: 65, alignment: .trailing)
            }

            // Status badge
            StatusBadge(status: item.status)
                .frame(width: 20)

            // Menu button
            Menu {
                ImageActions(item: item, canRemove: canRemove, perform: onMenuAction)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 22)
            .help(String(localized: "Actions"))
            .accessibilityLabel(String(localized: "Actions"))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts = [item.fileName, item.formattedOriginalSize]
        if let savings = item.savingsPercentage {
            parts.append(SavingsIndicator.accessibilityText(for: savings))
        }
        switch item.status {
        case .queued: parts.append(String(localized: "Queued"))
        case .processing: parts.append(String(localized: "Processing"))
        case .completed: parts.append(String(localized: "Completed"))
        case .skipped(let reason): parts.append(String(localized: "Skipped: \(reason)"))
        case .failed(let error): parts.append(String(localized: "Failed: \(error)"))
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
            .background(Color.caution.opacity(Palette.badgeTintOpacity))
            .foregroundStyle(.caution)
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}
