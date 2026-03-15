import SwiftUI

struct ConflictSheet: View {
    let fileName: String
    let onChoice: (MainViewModel.ConflictChoice) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.yellow)

                Text(String(localized: "File Already Exists"))
                    .font(.headline)

                Text(String(localized: "\"\(fileName)\" already exists in the output folder."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                    actionButton("Overwrite", icon: "arrow.triangle.2.circlepath", color: .orange) {
                        onChoice(.overwrite)
                    }
                    actionButton("Overwrite All", icon: "arrow.triangle.2.circlepath.circle.fill", color: .orange) {
                        onChoice(.overwriteAll)
                    }
                }

                // Rename group
                HStack(spacing: 8) {
                    actionButton("Rename", icon: "doc.on.doc", color: .blue) {
                        onChoice(.rename)
                    }
                    actionButton("Rename All", icon: "doc.on.doc.fill", color: .blue) {
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
                .foregroundStyle(.tertiary)
                .padding(.bottom, 16)
        }
        .frame(width: 380, height: 340)
    }

    private func actionButton(
        _ title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 16)
                Text(String(localized: "\(title)"))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(color)
        .controlSize(.large)
    }
}
