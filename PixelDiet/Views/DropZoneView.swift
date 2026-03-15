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

            Text(String(localized: "Drop images or folders here"))
                .font(.title3.weight(.medium))
                .foregroundStyle(.primary)

            Text(String(localized: "or"))
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button {
                presentOpenPanel()
            } label: {
                Text(String(localized: "Browse Files"))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text(String(localized: "JPEG, PNG, WebP, HEIC, AVIF, TIFF, BMP, GIF"))
                .font(.caption2)
                .foregroundStyle(.quaternary)

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
            handleDrop(providers: providers)
            return true
        }
    }

    private func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Add Images")
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]

        guard panel.runModal() == .OK else { return }

        Task {
            await viewModel.addFiles(urls: panel.urls)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            guard provider.canLoadObject(ofClass: URL.self) else { continue }
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    urls.append(url)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            guard !urls.isEmpty else { return }
            Task {
                await viewModel.addFiles(urls: urls)
            }
        }
    }
}
