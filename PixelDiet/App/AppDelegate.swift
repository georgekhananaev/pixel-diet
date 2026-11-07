import AppKit

/// Owns the app-wide view model, keeps the main window available, and asks before
/// quitting in the middle of a batch.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let viewModel = MainViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The queue lives only in memory, so macOS must not quit PixelDiet on its own
        // while the window is closed
        ProcessInfo.processInfo.automaticTerminationSupportEnabled = false

        // Window restoration can come back with no window at all, and macOS 14 has no
        // `defaultLaunchBehavior(.presented)`: open the main window the way a Dock click would
        Task {
            guard !NSApp.windows.contains(where: \.isVisible) else { return }
            _ = NSApp.delegate?.applicationOpenUntitledFile?(NSApp)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard viewModel.batchJob.isProcessing else { return .terminateNow }

        let alert = NSAlert()
        alert.messageText = String(localized: "Stop compressing and quit?")
        alert.informativeText = String(localized: "Images that aren't finished yet won't be saved. Images already compressed are kept.")
        alert.addButton(withTitle: String(localized: "Quit"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return .terminateCancel }

        // Let images that are being written finish (within a time limit), so no partial files are left behind
        Task {
            await viewModel.cancelCompressionAndWait()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
