import SwiftUI
import UserNotifications
import AppKit

@main
struct PixelDietApp: App {
    @State private var viewModel = MainViewModel()
    @State private var showCustomAbout = false
    @State private var showHelp = false

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: viewModel)
                .onAppear {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
                }
                .sheet(isPresented: $showCustomAbout) {
                    CustomAboutView()
                }
                .sheet(isPresented: $showHelp) {
                    HelpView()
                }
                .onReceive(NotificationCenter.default.publisher(for: .showHelp)) { _ in
                    showHelp = true
                }
        }
        .defaultSize(width: 1100, height: 750)
        .commands {
            // Replace default About
            CommandGroup(replacing: .appInfo) {
                Button("About PixelDiet") {
                    showCustomAbout = true
                }
            }

            CommandGroup(replacing: .newItem) {
                Button("Add Images...") {
                    NotificationCenter.default.post(name: .addImages, object: nil)
                }
                .keyboardShortcut("o")
            }

            // Support menu
            CommandMenu("Support") {
                Button("PixelDiet Help") {
                    NotificationCenter.default.post(name: .showHelp, object: nil)
                }
                .keyboardShortcut("?", modifiers: [.command])

                Divider()

                Button("Contact Support") {
                    if let url = URL(string: "https://github.com/georgekhananaev/pixeldiet/issues") {
                        NSWorkspace.shared.open(url)
                    }
                }

                Button("Report a Bug") {
                    if let url = URL(string: "https://github.com/georgekhananaev/pixeldiet/issues") {
                        NSWorkspace.shared.open(url)
                    }
                }

                Button("GitHub Repository") {
                    if let url = URL(string: "https://github.com/georgekhananaev/pixeldiet") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }

            // Remove default Help to avoid "Help isn't available"
            CommandGroup(replacing: .help) { }
        }

        Settings {
            SettingsWindow(settings: viewModel.settings)
        }
    }
}

// MARK: - Custom About View

struct CustomAboutView: View {
    @Environment(\.dismiss) private var dismiss
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private var systemInfo: String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let arch = {
            #if arch(arm64)
            return "Apple Silicon (arm64)"
            #elseif arch(x86_64)
            return "Intel (x86_64)"
            #else
            return "Unknown"
            #endif
        }()
        let ram = ProcessInfo.processInfo.physicalMemory
        let ramGB = String(format: "%.0f", Double(ram) / 1_073_741_824)
        return """
        macOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion) \(arch)
        Memory: \(ramGB) GB
        Processors: \(ProcessInfo.processInfo.activeProcessorCount) cores
        """
    }

    private var buildInfo: String {
        "Build #PD-\(buildNumber), \(version)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with gradient background
            ZStack {
                LinearGradient(
                    colors: [
                        Color.red.opacity(0.12),
                        Color.orange.opacity(0.08),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: 10) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .shadow(color: .orange.opacity(0.3), radius: 10)

                    Text("PixelDiet")
                        .font(.system(size: 24, weight: .bold, design: .rounded))

                    Text("Version \(version)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text("Batch Image Compression Tool")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 20)
                .padding(.bottom, 16)
            }
            .frame(height: 200)

            Divider()

            // Info section
            VStack(alignment: .leading, spacing: 12) {
                InfoSection(title: "Build Information", content: buildInfo)

                InfoSection(title: "Developer", content: "George Khananaev")

                HStack(spacing: 4) {
                    Text("SOURCE CODE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                    Spacer()
                }
                Link("github.com/georgekhananaev/pixeldiet", destination: URL(string: "https://github.com/georgekhananaev/pixeldiet")!)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.blue)

                InfoSection(title: "Runtime", content: systemInfo)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Footer
            HStack {
                Button {
                    let info = """
                    PixelDiet \(version)
                    \(buildInfo)

                    \(systemInfo)
                    """
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(info, forType: .string)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                        Text("Copy Info")
                            .font(.system(size: 11))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Text("Copyright © 2026 George Khananaev")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                Spacer()

                Button("OK") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 400, height: 440)
    }
}

struct InfoSection: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            Text(content)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Help View

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("PixelDiet Help")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    helpSection("Getting Started",
                        "Drag and drop images onto the window, or click **Add Files** to select images for compression.")

                    helpSection("Compression Settings",
                        "Use the sidebar to configure output format (WebP, JPEG, PNG, HEIF), quality level, maximum dimensions, and metadata options.")

                    helpSection("Output Folder",
                        "Select an output folder in the sidebar before compressing. Compressed images will be saved there with the same filenames.")

                    helpSection("Batch Processing",
                        "Add multiple images, then click **Compress** to process them all. Progress is shown in the bottom panel with per-file status.")

                    helpSection("Keyboard Shortcuts",
                        "**Cmd+O** \u{2014} Add Images\n**Cmd+R** \u{2014} Compress All\n**Cmd+.** \u{2014} Cancel\n**Delete** \u{2014} Remove Selected\n**Cmd+,** \u{2014} Settings")

                    helpSection("Contact",
                        "Email: george@khananaev.com")
                }
            }
        }
        .padding(24)
        .frame(width: 500, height: 480)
    }

    private func helpSection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(.init(body))
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let showHelp = Notification.Name("showHelp")
    static let addImages = Notification.Name("addImages")
}
