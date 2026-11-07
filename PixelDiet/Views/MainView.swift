import SwiftUI
import AppKit

struct MainView: View {
    @Bindable var viewModel: MainViewModel
    @Environment(\.undoManager) private var undoManager
    @State private var selectedItems: Set<UUID> = []
    @State private var previewItem: ImageItem?
    @State private var showBatchResults = true

    var body: some View {
        NavigationSplitView {
            SettingsPanel(viewModel: viewModel)
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
                            BatchProgressView(batchJob: viewModel.batchJob, outputDirectory: viewModel.settings.outputDirectory, onDismiss: {
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
                // Cmd+O is the File ▸ Add Images… menu item
                Button {
                    viewModel.presentAddImagesPanel()
                } label: {
                    Label(String(localized: "Add Files"), systemImage: "plus")
                }

                if viewModel.batchJob.isProcessing {
                    Button {
                        viewModel.cancelCompression()
                    } label: {
                        Label(
                            viewModel.isCancelling ? String(localized: "Cancelling…") : String(localized: "Cancel"),
                            systemImage: "stop.fill"
                        )
                    }
                    .keyboardShortcut(".", modifiers: .command)
                    .disabled(viewModel.isCancelling)
                } else {
                    Button {
                        showBatchResults = true
                        Task {
                            await viewModel.startCompression()
                        }
                    } label: {
                        let count = viewModel.batchJob.items.count
                        Label(
                            count > 0 ? CountText.compressImages(count) : String(localized: "Compress"),
                            systemImage: "arrow.down.circle.fill"
                        )
                    }
                    .keyboardShortcut("r")
                    .disabled(viewModel.batchJob.items.isEmpty || viewModel.settings.outputDirectory == nil)
                }

                // The Delete key is handled by the list (onDeleteCommand), so text fields keep Backspace
                if !selectedItems.isEmpty {
                    Button {
                        withAnimation {
                            viewModel.removeItems(ids: selectedItems, undoManager: undoManager)
                        }
                        selectedItems.removeAll()
                    } label: {
                        Label(String(localized: "Remove \(selectedItems.count)"), systemImage: "minus.circle")
                    }
                    .disabled(viewModel.batchJob.isProcessing)
                }

                if !viewModel.batchJob.items.isEmpty {
                    Button {
                        selectedItems.removeAll()
                        viewModel.clearAll(undoManager: undoManager)
                    } label: {
                        Label(String(localized: "Clear All"), systemImage: "trash")
                    }
                    .disabled(viewModel.batchJob.isProcessing)
                }

                if viewModel.hasFailedItems && !viewModel.batchJob.isProcessing {
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
                onChoice: { choice in viewModel.resolveConflict(choice) },
                onStop: { viewModel.cancelCompression() }
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
        // The window keeps its name for the Window menu, Mission Control and VoiceOver;
        // the scene hides the plain title so the toolbar shows the icon and live title
        .navigationTitle("PixelDiet")
    }

    private var dynamicTitle: String {
        let batchJob = viewModel.batchJob
        if batchJob.isProcessing {
            let pct = Int(batchJob.progress * 100)
            return String(localized: "PixelDiet - Compressing… \(pct)%")
        } else if !batchJob.items.isEmpty {
            let count = batchJob.items.count
            let totalSize = batchJob.totalOriginalSize
            let formattedSize = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
            return String(localized: "PixelDiet - \(CountText.images(count)) (\(formattedSize))")
        } else {
            return "PixelDiet"
        }
    }
}
