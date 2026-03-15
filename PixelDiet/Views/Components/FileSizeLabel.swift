import SwiftUI

struct FileSizeLabel: View {
    let bytes: Int64

    var body: some View {
        Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
    }
}
