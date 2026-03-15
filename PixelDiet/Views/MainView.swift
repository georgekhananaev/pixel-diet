import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MainView: View {
    @Bindable var viewModel: MainViewModel
    @Environment(\.undoManager) private var undoManager
    @State private var selectedItems: Set<UUID> = []
    @State private var previewItem: ImageItem?
    @State private var showOverlapAlert = false
    @State private var showBatchResults = true

    var body: some View {
        NavigationSplitView {
            SettingsPanel(settings: viewModel.settings, batchJob: viewModel.batchJob)
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
        } detail: {
            VStack(spacing: 0) {
                if viewModel.batchJob.items.isEmpty {
                    DropZoneView(viewModel: viewModel)
                } else {
                    VStack(spacing: 0) {
                        ImageListView(
                            viewModel: viewModel,
                            selectedItems: $selectedItems,
                            previewItem: $previewItem
                        )

                        if viewModel.batchJob.isProcessing || (!viewModel.batchJob.runHistory.isEmpty && showBatchResults) {
                            Divider()
                            BatchProgressView(batchJob: viewModel.batchJob, onDismiss: {
                                showBatchResults = false
                            })
                                .padding()
                        }
                    }
                }
            }
            .frame(minWidth: 600, minHeight: 450)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    presentOpenPanel()
                } label: {
                    Label(String(localized: "Add Files"), systemImage: "plus")
                }
                .keyboardShortcut("o")

                if viewModel.batchJob.isProcessing {
                    Button {
                        viewModel.cancelCompression()
                    } label: {
                        Label(String(localized: "Cancel"), systemImage: "stop.fill")
                    }
                    .keyboardShortcut(".", modifiers: .command)
                } else {
                    Button {
                        showBatchResults = true
                        Task {
                            await viewModel.startCompression()
                        }
                    } label: {
                        let count = viewModel.batchJob.items.count
                        Label(
                            count > 0
                                ? String(localized: "Compress \(count) Images")
                                : String(localized: "Compress"),
                            systemImage: "arrow.down.circle.fill"
                        )
                    }
                    .keyboardShortcut("r")
                    .disabled(viewModel.batchJob.items.isEmpty || viewModel.settings.outputDirectory == nil)
                }

                if !selectedItems.isEmpty {
                    Button {
                        withAnimation {
                            viewModel.batchJob.items.removeAll { selectedItems.contains($0.id) }
                        }
                        selectedItems.removeAll()
                    } label: {
                        Label(String(localized: "Remove \(selectedItems.count)"), systemImage: "minus.circle")
                    }
                    .keyboardShortcut(.delete, modifiers: [])
                }

                if !viewModel.batchJob.items.isEmpty {
                    Button {
                        viewModel.clearAll(undoManager: undoManager)
                    } label: {
                        Label(String(localized: "Clear All"), systemImage: "trash")
                    }
                }

                if viewModel.batchJob.failedCount > 0 && !viewModel.batchJob.isProcessing {
                    Button {
                        Task {
                            await viewModel.retryFailed()
                        }
                    } label: {
                        Label(String(localized: "Retry Failed"), systemImage: "arrow.clockwise")
                    }
                }
            }
        }
        .sheet(item: $previewItem) { item in
            ImagePreviewView(item: item)
        }
        .alert(
            String(localized: "Error"),
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button(String(localized: "OK")) {
                viewModel.errorMessage = nil
            }
        } message: {
            if let msg = viewModel.errorMessage {
                Text(msg)
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.pendingOverwriteFile != nil },
            set: { if !$0 { viewModel.resolveConflict(.skip) } }
        )) {
            ConflictSheet(
                fileName: viewModel.pendingOverwriteFile ?? "",
                onChoice: { choice in viewModel.resolveConflict(choice) }
            )
        }
        .frame(minWidth: 900, minHeight: 600)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 6) {
                    Image("AppIconClean")
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                    Text(dynamicTitle)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .allowsHitTesting(false)
            }
        }
        .navigationTitle("")
        .onReceive(NotificationCenter.default.publisher(for: .addImages)) { _ in
            presentOpenPanel()
        }
    }

    private var dynamicTitle: String {
        let batchJob = viewModel.batchJob
        if batchJob.isProcessing {
            let pct = Int(batchJob.progress * 100)
            return "PixelDiet - Compressing... \(pct)%"
        } else if !batchJob.items.isEmpty {
            let count = batchJob.items.count
            let totalSize = batchJob.totalOriginalSize
            let formattedSize = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
            return "PixelDiet - \(count) images (\(formattedSize))"
        } else {
            return "PixelDiet"
        }
    }

    private func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Add Images")
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]

        guard panel.runModal() == .OK else { return }

        Task {
            await viewModel.addFiles(urls: panel.urls)
        }
    }
}
