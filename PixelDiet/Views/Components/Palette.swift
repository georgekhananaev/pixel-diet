import AppKit
import SwiftUI

/// Text and status colors that stay readable: at least 4.5:1 contrast on the window, list and
/// badge backgrounds in Light and Dark Mode (checked by `PaletteTests`). The system colors they
/// stand in for are too light for text in Light Mode (secondary label 3.95:1, green about 2:1).
enum Palette {
    static let secondaryText = dynamic(light: NSColor(white: 0, alpha: 0.62), dark: .secondaryLabelColor)
    static let success = dynamic(light: NSColor(srgbRed: 0.08, green: 0.44, blue: 0.18, alpha: 1), dark: .systemGreen)
    static let highSavings = dynamic(light: NSColor(srgbRed: 0, green: 0.42, blue: 0.38, alpha: 1), dark: .systemMint)
    static let failure = dynamic(
        light: NSColor(srgbRed: 0.70, green: 0.10, blue: 0.08, alpha: 1),
        dark: NSColor(srgbRed: 1, green: 0.42, blue: 0.38, alpha: 1)
    )
    static let caution = dynamic(light: NSColor(srgbRed: 0.60, green: 0.28, blue: 0, alpha: 1), dark: .systemOrange)

    /// Opacity of a badge's background tint, in its text color
    static let badgeTintOpacity: CGFloat = 0.12

    private static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        }
    }
}

extension ShapeStyle where Self == Color {
    /// Secondary text, readable in Light Mode too (use `.secondary` for icons)
    static var secondaryText: Color { Color(nsColor: Palette.secondaryText) }
    static var success: Color { Color(nsColor: Palette.success) }
    static var highSavings: Color { Color(nsColor: Palette.highSavings) }
    static var failure: Color { Color(nsColor: Palette.failure) }
    static var caution: Color { Color(nsColor: Palette.caution) }
}
