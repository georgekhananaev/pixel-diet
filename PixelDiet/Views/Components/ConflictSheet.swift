import SwiftUI

struct ConflictSheet: View {
    let fileName: String
    let onChoice: (MainViewModel.ConflictChoice) -> Void
    /// Stops the whole batch: nothing more is written
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .symbolRenderingMode(.multicolor)
                    .accessibilityHidden(true)  // The title says it

                Text(String(localized: "File Already Exists"))
                    .font(.headline)

                Text(String(localized: "\"\(fileName)\" already exists in the output folder."))
                    .font(.subheadline)
                    .foregroundStyle(.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)
            .padding(.horizontal, 24)

            Divider()
                .padding(.vertical, 16)

            // Buttons in 3 groups
            VStack(spacing: 8) {
                // Overwrite group
                HStack(spacing: 8) {
                    actionButton("Overwrite", icon: "arrow.triangle.2.circlepath", color: .caution) {
                        onChoice(.overwrite)
                    }
                    actionButton("Overwrite All", icon: "arrow.triangle.2.circlepath.circle.fill", color: .caution) {
                        onChoice(.overwriteAll)
                    }
                }

                // Rename group
                HStack(spacing: 8) {
                    actionButton("Rename", icon: "doc.on.doc", color: .accentColor) {
                        onChoice(.rename)
                    }
                    actionButton("Rename All", icon: "doc.on.doc.fill", color: .accentColor) {
                        onChoice(.renameAll)
                    }
                }

                // Skip group
                HStack(spacing: 8) {
                    actionButton("Skip", icon: "forward.fill", color: .secondary) {
                        onChoice(.skip)
                    }
                    actionButton("Skip All", icon: "forward.end.fill", color: .secondary) {
                        onChoice(.skipAll)
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
                .frame(height: 16)

            Text(String(localized: "\"All\" options apply to remaining conflicts in this batch."))
                .font(.caption)
                .foregroundStyle(.secondaryText)

            Button(String(localized: "Stop Compressing"), action: onStop)
                .keyboardShortcut(".", modifiers: .command)
                .padding(.vertical, 16)
        }
        .frame(width: 380, height: 380)
        .onExitCommand {
            onChoice(.skip)
        }
    }

    private func actionButton(
        _ title: LocalizedStringKey,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        // Only the icon is colored: tinted button text would be too light to read in Light Mode
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 16)
                Text(title)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}
