import SwiftUI

struct SavingsIndicator: View {
    let percentage: Double

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: percentage >= 0 ? "arrow.down" : "arrow.up")
                .font(.system(size: 9, weight: .bold))
            Text(String(format: "%.0f%%", abs(percentage)))
                .font(.caption.monospacedDigit().bold())
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityLabel("Saved \(Int(percentage)) percent")
    }

    private var foregroundColor: Color {
        if percentage < 0 {
            return .red
        } else if percentage < 20 {
            return .secondary
        } else if percentage < 50 {
            return .green
        } else {
            return .mint
        }
    }

    private var backgroundColor: Color {
        foregroundColor.opacity(0.12)
    }
}
