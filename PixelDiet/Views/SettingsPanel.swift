import SwiftUI

struct SettingsPanel: View {
    @Bindable var settings: CompressionSettings
    var batchJob: BatchJob

    var body: some View {
        Form {
            Section {
                Picker(String(localized: "Output Format"), selection: $settings.outputFormat) {
                    ForEach(ImageFormat.availableOutputFormats) { format in
                        if format == .avif && !ImageFormat.isAVIFEncodingAvailable {
                            Text("\(format.displayName) (Requires macOS 14.1+)")
                                .tag(format)
                                .disabled(true)
                        } else {
                            Text(format.displayName)
                                .tag(format)
                        }
                    }
                }
                .help("Choose the output image format")

                if !settings.outputFormat.supportsAlpha && settings.outputFormat != .original {
                    Text(String(localized: "This format does not support transparency"))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text(String(localized: "Format"))
            }

            Section {
                if settings.outputFormat.supportsQuality || settings.outputFormat == .original {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(String(localized: "Quality"))
                            Spacer()
                            Text("\(settings.quality)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }

                        Slider(
                            value: Binding(
                                get: { Double(settings.quality) },
                                set: { settings.setQuality(Int($0)) }
                            ),
                            in: 10...100,
                            step: 1
                        )
                        .help("Higher quality = larger file size. 80 is recommended for most uses.")

                        HStack {
                            Text(String(localized: "Smaller file"))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Text(String(localized: "Higher quality"))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            } header: {
                Text(String(localized: "Quality"))
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(String(localized: "Max longest edge"))
                        Spacer()
                        TextField(
                            "",
                            value: Binding(
                                get: { settings.maxDimension },
                                set: { settings.setMaxDimension($0) }
                            ),
                            format: .number
                        )
                        .frame(width: 70)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        Text(String(localized: "px"))
                            .foregroundStyle(.secondary)
                    }
                    .help("Images larger than this will be scaled down. 0 keeps original size.")

                    Text(String(localized: "0 = keep original dimensions"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    // Preset buttons
                    HStack(spacing: 6) {
                        ForEach([640, 1280, 1920, 2560, 3840], id: \.self) { size in
                            Button("\(size)") {
                                settings.setMaxDimension(size)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .foregroundStyle(
                                settings.maxDimension == size ? .primary : .secondary
                            )
                        }
                    }
                }
            } header: {
                Text(String(localized: "Resize"))
            }

            Section {
                Toggle(isOn: $settings.stripMetadata) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Strip EXIF Metadata"))
                        Text(String(localized: "Removes camera info, GPS location, and other embedded data. Image orientation is preserved."))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .help("Removes camera info, GPS location, timestamps. Orientation is preserved.")

                if !settings.stripMetadata {
                    let hasGPSItems = batchJob.items.contains { $0.hasGPSData }
                    if hasGPSItems {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                            Text(String(localized: "Some images contain GPS location data"))
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Toggle(isOn: $settings.skipIfLarger) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Skip If Larger"))
                        Text(String(localized: "Skip files where compression increases file size"))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .help("If compression makes the file bigger, keep the original instead.")

                Toggle(isOn: $settings.preserveDirectoryStructure) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Preserve Directory Structure"))
                        Text(String(localized: "Maintain folder hierarchy in output"))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .help("Recreate the input folder hierarchy in the output folder.")
            } header: {
                Text(String(localized: "Options"))
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    if let outputDir = settings.outputDirectory {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(.secondary)
                            Text(outputDir.lastPathComponent)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .help(outputDir.path)
                        }
                        .font(.caption)
                    } else {
                        Text(String(localized: "No output folder selected"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        chooseOutputFolder()
                    } label: {
                        Label(String(localized: "Choose Output Folder..."), systemImage: "folder.badge.plus")
                    }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                    .help("Where compressed images will be saved.")
                }
            } header: {
                Text(String(localized: "Output"))
            }
        }
        .formStyle(.grouped)
    }

    private func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Choose Output Folder")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        settings.outputDirectory = url
        try? BookmarkManager.saveBookmark(for: url)
    }
}
