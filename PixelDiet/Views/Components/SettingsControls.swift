import SwiftUI

// Compression controls shared by the sidebar and the Settings window.

struct OutputFormatPicker: View {
    @Bindable var settings: CompressionSettings

    var body: some View {
        Picker(String(localized: "Output Format"), selection: $settings.outputFormat) {
            // AVIF is listed only where ImageIO can encode it
            ForEach(ImageFormat.availableOutputFormats) { format in
                Text(format.displayName).tag(format)
            }
        }
        // The pop-up itself is named too, not only the row's text beside it
        .accessibilityLabel(String(localized: "Output Format"))
    }
}

/// Quality in whole steps, with the current value and what each end of the slider means.
struct QualitySlider: View {
    @Bindable var settings: CompressionSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(String(localized: "Quality"))
                Spacer()
                Text("\(settings.quality)")
                    .monospacedDigit()
                    .foregroundStyle(.secondaryText)
            }
            // The slider announces its own name and value
            .accessibilityHidden(true)

            Slider(
                value: Binding(
                    get: { Double(settings.quality) },
                    set: { settings.setQuality(Int($0.rounded())) }
                ),
                in: Double(Constants.qualityRange.lowerBound)...Double(Constants.qualityRange.upperBound),
                step: 1
            ) {
                Text(String(localized: "Quality"))
            }
            .labelsHidden()
            .accessibilityValue(Text("\(settings.quality)"))

            HStack {
                Text(String(localized: "Smaller file"))
                Spacer()
                Text(String(localized: "Higher quality"))
            }
            .font(.caption2)
            .foregroundStyle(.secondaryText)
            .accessibilityHidden(true)
        }
    }
}

/// Longest edge in pixels that images are scaled down to; 0 keeps the original size.
struct MaxDimensionField: View {
    @Bindable var settings: CompressionSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(String(localized: "Max Longest Edge"))
                    .accessibilityHidden(true)
                Spacer()
                TextField(
                    String(localized: "Max Longest Edge"),
                    value: Binding(
                        get: { settings.maxDimension },
                        set: { settings.setMaxDimension($0) }
                    ),
                    format: .number
                )
                .labelsHidden()
                .frame(width: 70)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .accessibilityLabel(String(localized: "Max longest edge in pixels"))
                Text(String(localized: "px"))
                    .foregroundStyle(.secondaryText)
                    .accessibilityHidden(true)
            }

            Text(String(localized: "0 = keep original dimensions"))
                .font(.caption)
                .foregroundStyle(.secondaryText)
        }
    }
}
