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
                OutputFormatPicker(settings: settings)
            }

            if settings.outputFormat.supportsQuality {
                Section {
                    QualitySlider(settings: settings)
                }
            }

            Section {
                MaxDimensionField(settings: settings)
            }

            Section {
                Toggle(String(localized: "Strip EXIF Metadata"), isOn: $settings.stripMetadata)

                Toggle(String(localized: "Skip If Larger"), isOn: $settings.skipIfLarger)

                Toggle(String(localized: "Preserve Directory Structure"), isOn: $settings.preserveDirectoryStructure)
            } footer: {
                Text(String(localized: "Settings are saved automatically and restored the next time you open PixelDiet."))
                    .font(.caption)
                    .foregroundStyle(.secondaryText)
            }
        }
        .formStyle(.grouped)
    }
}
