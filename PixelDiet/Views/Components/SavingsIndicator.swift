import SwiftUI

struct SavingsIndicator: View {
    let percentage: Double

    /// Whole-number magnitude; anything short of 100% shows at most 99%,
    /// so a file that still has bytes never reads as "100% saved".
    private static func displayValue(for percentage: Double) -> Int {
        let magnitude = abs(percentage)
        return magnitude < 100 ? min(99, Int(magnitude.rounded())) : Int(magnitude)
    }

    /// Magnitude for display, e.g. "42%" (direction is shown by the arrow)
    static func percentText(for percentage: Double) -> String {
        "\(displayValue(for: percentage))%"
    }

    /// Spoken description, e.g. "Saved 42 percent" or "Increased by 12 percent"
    static func accessibilityText(for percentage: Double) -> String {
        let value = displayValue(for: percentage)
        return percentage >= 0
            ? String(localized: "Saved \(value) percent")
            : String(localized: "Increased by \(value) percent")
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: percentage >= 0 ? "arrow.down" : "arrow.up")
                .font(.system(size: 9, weight: .bold))
            Text(Self.percentText(for: percentage))
                .font(.caption.monospacedDigit().bold())
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityText(for: percentage))
    }

    private var foregroundColor: Color {
        if percentage < 0 {
            return .failure
        } else if percentage < 20 {
            return .secondaryText
        } else if percentage < 50 {
            return .success
        } else {
            return .highSavings
        }
    }

    private var backgroundColor: Color {
        foregroundColor.opacity(Palette.badgeTintOpacity)
    }
}
