import SwiftUI

@main
struct PixelDietApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    /// Scene identifiers for `openWindow(id:)`
    enum WindowID {
        static let main = "main"
        static let about = "about"
        static let help = "help"
    }

    var body: some Scene {
        // A single main window: after it is closed, Window ▸ PixelDiet (or the Dock icon)
        // brings it back with the queue intact.
        Window("PixelDiet", id: WindowID.main) {
            MainView(viewModel: appDelegate.viewModel)
        }
        .defaultSize(width: 1100, height: 750)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            AppCommands(viewModel: appDelegate.viewModel)
        }

        Window("About PixelDiet", id: WindowID.about) {
            AboutView()
        }
        .windowResizability(.contentSize)

        Window("PixelDiet Help", id: WindowID.help) {
            HelpView()
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsWindow(settings: appDelegate.viewModel.settings)
        }
    }
}
