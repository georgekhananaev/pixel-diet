import SwiftUI
import AppKit

/// The About window: version, build, developer, runtime details and acknowledgements.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showAcknowledgements = false

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private var copyright: String {
        Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String ?? ""
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
        let ramGB = ProcessInfo.processInfo.physicalMemory / 1_073_741_824
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
                        .accessibilityHidden(true)

                    Text("PixelDiet")
                        .font(.system(size: 24, weight: .bold, design: .rounded))

                    Text("Version \(version)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondaryText)

                    Text(String(localized: "Batch Image Compression Tool"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondaryText)
                }
                .padding(.top, 20)
                .padding(.bottom, 16)
            }
            .frame(height: 200)

            Divider()

            // Info section
            VStack(alignment: .leading, spacing: 12) {
                InfoSection(title: String(localized: "Build Information"), content: buildInfo)

                InfoSection(title: String(localized: "Developer"), content: "George Khananaev")

                VStack(alignment: .leading, spacing: 4) {
                    InfoSectionTitle(String(localized: "Source Code"))
                    Link("github.com/georgekhananaev/pixel-diet", destination: AppLinks.repository)
                        .font(.system(size: 12, design: .monospaced))
                }

                InfoSection(title: String(localized: "Runtime"), content: systemInfo)

                Text(copyright)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondaryText)
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
                    Label(String(localized: "Copy Info"), systemImage: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(String(localized: "Acknowledgements")) { showAcknowledgements = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                Spacer()

                Button(String(localized: "OK")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 440, height: 520)
        .sheet(isPresented: $showAcknowledgements) {
            AcknowledgementsView()
        }
    }
}

private struct InfoSectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondaryText)
            .textCase(.uppercase)
            .tracking(0.5)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct InfoSection: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            InfoSectionTitle(title)

            Text(content)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }
}
