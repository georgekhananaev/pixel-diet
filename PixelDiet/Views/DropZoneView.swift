import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    var viewModel: MainViewModel
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)  // Decorative: the text below says what to do

            Text(String(localized: "Drop images or folders here"))
                .font(.title3.weight(.medium))
                .foregroundStyle(.primary)

            Text(String(localized: "or"))
                .font(.caption)
                .foregroundStyle(.secondaryText)

            if viewModel.isImporting {
                ProgressView(String(localized: "Adding images…"))
                    .controlSize(.large)
            } else {
                Button {
                    viewModel.presentAddImagesPanel()
                } label: {
                    Text(String(localized: "Browse Files"))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Text(String(localized: "JPEG, PNG, WebP, HEIC, HEIF, AVIF, TIFF, BMP, GIF, PPM"))
                .font(.caption2)
                .foregroundStyle(.secondaryText)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(
                        lineWidth: isTargeted ? 3 : 2,
                        dash: isTargeted ? [] : [8, 4]
                    )
                )
                .padding(20)
        }
        .background(isTargeted ? Color.accentColor.opacity(0.05) : Color.clear)
        .animation(.easeInOut(duration: 0.2), value: isTargeted)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            viewModel.addDroppedItems(providers)
            return true
        }
    }
}
