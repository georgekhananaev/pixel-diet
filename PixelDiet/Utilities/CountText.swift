import Foundation

/// Phrases with a count, pluralized by the String Catalog ("1 image", "2 images").
nonisolated enum CountText {
    static func images(_ count: Int) -> String {
        String(localized: "\(count) images")
    }

    static func compressImages(_ count: Int) -> String {
        String(localized: "Compress \(count) Images")
    }

    static func items(_ count: Int) -> String {
        String(localized: "\(count) items")
    }

    static func imagesCompressed(_ count: Int) -> String {
        String(localized: "Batch complete - \(count) images compressed")
    }
}
