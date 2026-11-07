import SwiftUI

struct SettingsPanel: View {
    var viewModel: MainViewModel

    private var batchJob: BatchJob { viewModel.batchJob }

    var body: some View {
        @Bindable var settings = viewModel.settings
        Form {
            Section {
                OutputFormatPicker(settings: settings)
                    .help(String(localized: "Choose the output image format"))

                if viewModel.flattensTransparentImages {
                    WarningNote(text: String(localized: "Transparent areas become white in this format"))
                }
            } header: {
                Text(String(localized: "Format"))
            }

            if settings.outputFormat.supportsQuality {
                Section {
                    QualitySlider(settings: settings)
                        .help(String(localized: "Higher quality = larger file size. 80 is recommended for most uses."))
                } header: {
                    Text(String(localized: "Quality"))
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    MaxDimensionField(settings: settings)
                        .help(String(localized: "Images larger than this will be scaled down. 0 keeps original size."))

                    // Preset buttons
                    HStack(spacing: 6) {
                        ForEach([640, 1280, 1920, 2560, 3840], id: \.self) { size in
                            Button("\(size)") {
                                settings.setMaxDimension(size)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .foregroundStyle(
                                settings.maxDimension == size ? Color.primary : .secondaryText
                            )
                            .accessibilityLabel(String(localized: "\(size) pixels"))
                            .accessibilityAddTraits(settings.maxDimension == size ? .isSelected : [])
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
                        Text(String(localized: "Removes camera info, GPS location, and other embedded data, and converts colors to sRGB. Photos stay upright."))
                            .font(.caption)
                            .foregroundStyle(.secondaryText)
                    }
                }
                .help(String(localized: "Removes camera info, GPS location and timestamps. Turn off to keep them and the original color profile (CMYK becomes sRGB)."))

                if !settings.stripMetadata && batchJob.items.contains(where: \.hasGPSData) {
                    WarningNote(text: String(localized: "Some images contain GPS location data"))
                }

                Toggle(isOn: $settings.skipIfLarger) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Skip If Larger"))
                        Text(String(localized: "Skip files where compression increases file size"))
                            .font(.caption)
                            .foregroundStyle(.secondaryText)
                    }
                }
                .help(String(localized: "If compression makes the file bigger, keep the original instead."))

                Toggle(isOn: $settings.preserveDirectoryStructure) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Preserve Directory Structure"))
                        Text(String(localized: "Maintain folder hierarchy in output"))
                            .font(.caption)
                            .foregroundStyle(.secondaryText)
                    }
                }
                .help(String(localized: "Recreate the input folder hierarchy in the output folder."))
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
                            .foregroundStyle(.secondaryText)
                    }

                    Button {
                        viewModel.presentOutputFolderPanel()
                    } label: {
                        Label(String(localized: "Choose Output Folder..."), systemImage: "folder.badge.plus")
                    }
                    // Changing it mid-run would revoke access to the folder being written to
                    .disabled(batchJob.isProcessing)
                    .help(String(localized: "Where compressed images will be saved."))
                }
            } header: {
                Text(String(localized: "Output"))
            }
        }
        .formStyle(.grouped)
        .scrollIndicators(.automatic)
        .scrollContentBackground(.hidden)
    }
}

/// A caption with a warning sign, for settings that may surprise people.
private struct WarningNote: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.secondaryText)
            .symbolRenderingMode(.multicolor)
    }
}
