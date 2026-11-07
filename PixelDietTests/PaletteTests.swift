import Testing
import AppKit
@testable import PixelDiet

/// Text and status colors stay readable in Light and Dark Mode: at least 4.5:1 (WCAG contrast
/// ratio, the minimum for text; icons need 3:1) on the window, list and text backgrounds, and
/// on the tinted background of the badges that use them.
@MainActor
struct PaletteTests {
    private static let colors: [(name: String, color: NSColor)] = [
        ("secondaryText", Palette.secondaryText),
        ("success", Palette.success),
        ("highSavings", Palette.highSavings),
        ("failure", Palette.failure),
        ("caution", Palette.caution),
    ]

    /// The color as it is drawn in `appearance`, in sRGB.
    private func resolved(_ color: NSColor, in appearance: NSAppearance.Name) -> NSColor {
        var result = color
        NSAppearance(named: appearance)?.performAsCurrentDrawingAppearance {
            result = color.usingColorSpace(.sRGB) ?? color
        }
        return result
    }

    /// `color` drawn over the opaque `background`, with the given extra opacity.
    private func composited(_ color: NSColor, over background: NSColor, opacity: CGFloat = 1) -> NSColor {
        let alpha = color.alphaComponent * opacity
        return NSColor(
            srgbRed: color.redComponent * alpha + background.redComponent * (1 - alpha),
            green: color.greenComponent * alpha + background.greenComponent * (1 - alpha),
            blue: color.blueComponent * alpha + background.blueComponent * (1 - alpha),
            alpha: 1
        )
    }

    private func luminance(_ color: NSColor) -> Double {
        let linear = { (component: CGFloat) -> Double in
            let value = Double(component)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(color.redComponent) + 0.7152 * linear(color.greenComponent) + 0.0722 * linear(color.blueComponent)
    }

    private func contrast(_ foreground: NSColor, on background: NSColor) -> Double {
        let (lighter, darker) = (luminance(foreground), luminance(background))
        return (max(lighter, darker) + 0.05) / (min(lighter, darker) + 0.05)
    }

    @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
    func textColorsAreReadableOnEveryBackground(appearance: NSAppearance.Name) {
        let backgrounds: [NSColor] = [.windowBackgroundColor, .controlBackgroundColor, .textBackgroundColor]
        for background in backgrounds.map({ resolved($0, in: appearance) }) {
            for (name, color) in Self.colors {
                let drawn = composited(resolved(color, in: appearance), over: background)
                #expect(contrast(drawn, on: background) >= 4.5, "\(name) on \(background) in \(appearance.rawValue)")
            }
        }
    }

    @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
    func badgeTextIsReadableOnItsOwnTint(appearance: NSAppearance.Name) {
        for row in [NSColor.windowBackgroundColor, .controlBackgroundColor].map({ resolved($0, in: appearance) }) {
            for (name, color) in Self.colors.dropFirst() {
                let text = resolved(color, in: appearance)
                let tint = composited(text, over: row, opacity: Palette.badgeTintOpacity)
                #expect(contrast(composited(text, over: tint), on: tint) >= 4.5, "\(name) badge in \(appearance.rawValue)")
            }
        }
    }
}
