import SwiftUI

struct SettingsWindow: View {
    @Bindable var settings: CompressionSettings

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label(String(localized: "General"), systemImage: "gearshape")
                }
        }
        .frame(width: 450, height: 380)
    }

    private var generalTab: some View {
        Form {
            Section {
                Picker(String(localized: "Default Output Format"), selection: $settings.outputFormat) {
                    ForEach(ImageFormat.availableOutputFormats) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .onChange(of: settings.outputFormat) { _, _ in persistSettings() }
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(String(localized: "Default Quality"))
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
                    .onChange(of: settings.quality) { _, _ in persistSettings() }

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

            Section {
                HStack {
                    Text(String(localized: "Default Max Dimension"))
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
                    .onChange(of: settings.maxDimension) { _, _ in persistSettings() }
                    Text(String(localized: "px"))
                        .foregroundStyle(.secondary)
                }

                Text(String(localized: "0 = keep original dimensions"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Section {
                Toggle(String(localized: "Strip EXIF Metadata by default"), isOn: $settings.stripMetadata)
                    .onChange(of: settings.stripMetadata) { _, _ in persistSettings() }

                Toggle(String(localized: "Skip if larger by default"), isOn: $settings.skipIfLarger)
                    .onChange(of: settings.skipIfLarger) { _, _ in persistSettings() }
            }
        }
        .formStyle(.grouped)
    }

    private func persistSettings() {
        let data = SettingsData(
            outputFormat: settings.outputFormat.rawValue,
            quality: settings.quality,
            maxDimension: settings.maxDimension,
            preserveDirectoryStructure: settings.preserveDirectoryStructure,
            stripMetadata: settings.stripMetadata,
            skipIfLarger: settings.skipIfLarger
        )
        try? SettingsStore().save(data)
    }
}
