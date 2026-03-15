import SwiftUI
import UserNotifications

@main
struct PixelDietApp: App {
    @State private var viewModel = MainViewModel()

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: viewModel)
                .onAppear {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Images...") {
                    // Handled by MainView
                }
                .keyboardShortcut("o")
            }
        }

        Settings {
            SettingsWindow(settings: viewModel.settings)
        }
    }
}
