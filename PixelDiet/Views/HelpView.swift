import SwiftUI

/// The PixelDiet Help window (Help ▸ PixelDiet Help).
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text(String(localized: "PixelDiet Help"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(String(localized: "Done")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    helpSection(String(localized: "Getting Started"),
                        String(localized: "Drag and drop images or folders onto the window, or choose **File ▸ Add Images…** (Cmd+O) to pick them."))

                    helpSection(String(localized: "Compression Settings"),
                        String(localized: "Use the sidebar to choose the output format (JPEG, PNG, WebP, HEIC, HEIF, AVIF where supported, TIFF, BMP, GIF, or Original), quality, maximum size and metadata options. Your settings are remembered between launches."))

                    helpSection(String(localized: "Output Folder"),
                        String(localized: "Choose an output folder in the sidebar or with **File ▸ Choose Output Folder…** (Cmd+Shift+O). Compressed images are saved there with their original names and the new file extension; your originals are never changed. If a file already exists, you can overwrite, rename or skip it, or stop compressing."))

                    helpSection(String(localized: "Metadata and Colors"),
                        String(localized: "**Strip EXIF Metadata** (on by default) removes location and camera details and converts colors to sRGB, the safest choice for the web. Turn it off to keep the metadata and the original color profile (CMYK images are converted to sRGB). Either way, photos are saved upright, so they never appear sideways."))

                    helpSection(String(localized: "Preview"),
                        String(localized: "Double-click an image, press Space, or choose **Preview** from its menu to compare the original with the compressed result."))

                    helpSection(String(localized: "Batch Processing"),
                        String(localized: "Click **Compress** (Cmd+R) to process all images. Each run appears in the bottom panel with its results; use **Retry Failed** to run failed images again."))

                    helpSection(String(localized: "Keyboard Shortcuts"),
                        String(localized: "**Cmd+O** - Add Images\n**Cmd+Shift+O** - Choose Output Folder\n**Cmd+R** - Compress\n**Cmd+.** - Cancel\n**Space** - Preview Selected Image\n**Delete** - Remove Selected\n**Cmd+Z** - Undo Remove or Clear All\n**Cmd+,** - Settings"))

                    helpSection(String(localized: "Privacy"),
                        String(localized: "PixelDiet works entirely offline. Images are processed on your Mac and never uploaded."))

                    helpSection(String(localized: "Contact"),
                        String(localized: "Report a problem or ask a question at \(AppLinks.issues.absoluteString), or email \(AppLinks.supportEmailAddress)."))
                }
            }
        }
        .padding(24)
        .frame(width: 520, height: 560)
    }

    private func helpSection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text(.init(body))
                .font(.body)
                .foregroundStyle(.secondaryText)
        }
    }
}
