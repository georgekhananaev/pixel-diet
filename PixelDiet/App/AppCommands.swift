import SwiftUI

/// Menu bar: About, File (add images, output folder) and the standard Help menu.
struct AppCommands: Commands {
    let viewModel: MainViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(String(localized: "About PixelDiet")) {
                openWindow(id: PixelDietApp.WindowID.about)
            }
        }

        CommandGroup(replacing: .newItem) {
            Button(String(localized: "Add Images…")) {
                openWindow(id: PixelDietApp.WindowID.main)
                viewModel.presentAddImagesPanel()
            }
            .keyboardShortcut("o")

            Button(String(localized: "Choose Output Folder…")) {
                openWindow(id: PixelDietApp.WindowID.main)
                viewModel.presentOutputFolderPanel()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            .disabled(viewModel.batchJob.isProcessing)
        }

        CommandGroup(replacing: .help) {
            Button(String(localized: "PixelDiet Help")) {
                openWindow(id: PixelDietApp.WindowID.help)
            }
            .keyboardShortcut("?")

            Divider()

            Link(String(localized: "Contact Support"), destination: AppLinks.supportEmail)
            Link(String(localized: "Report a Bug"), destination: AppLinks.newIssue)
            Link(String(localized: "GitHub Repository"), destination: AppLinks.repository)

            Divider()

            Link(String(localized: "Privacy Policy"), destination: AppLinks.privacyPolicy)
        }
    }
}
