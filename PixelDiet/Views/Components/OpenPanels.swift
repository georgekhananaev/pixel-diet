import AppKit
import UniformTypeIdentifiers

/// The app's file pickers. Selecting through these panels is what grants the
/// sandboxed app access to the chosen files and folders.
enum OpenPanels {
    /// Images and/or folders to add; nil when cancelled.
    static func chooseImages() -> [URL]? {
        let panel = makeAddImagesPanel()
        return panel.runModal() == .OK ? panel.urls : nil
    }

    static func makeAddImagesPanel() -> NSOpenPanel {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Add Images")
        // With the macOS 27 SDK, setting the content types also sets canChooseFiles and
        // canChooseDirectories, so folders are listed as a type and the flags are set afterwards
        panel.allowedContentTypes = [.image, .folder]
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        return panel
    }

    /// A folder to write compressed images into; nil when cancelled.
    static func chooseOutputFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Choose Output Folder")
        panel.prompt = String(localized: "Choose")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }
}

extension MainViewModel {
    /// Shows the Add Images panel and queues the chosen images and folders.
    func presentAddImagesPanel() {
        guard let urls = OpenPanels.chooseImages() else { return }
        Task { await addFiles(urls: urls) }
    }

    /// Shows the output folder panel. Not while compressing: switching folders
    /// mid-run would revoke access to the folder being written to.
    func presentOutputFolderPanel() {
        guard !batchJob.isProcessing, let url = OpenPanels.chooseOutputFolder() else { return }
        settings.chooseOutputDirectory(url)
    }
}
