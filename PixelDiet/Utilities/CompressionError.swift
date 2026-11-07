import Foundation

nonisolated enum CompressionError: LocalizedError, Equatable, Sendable {
    case cannotReadImage
    case sourceUnavailable
    case resizeFailed
    case invalidDimensions
    case cannotCreateDestination
    case writeFailed
    case outputLargerThanOriginal
    case unsupportedFormat(String)
    case webpTooLarge
    case outputDirectoryNotWritable
    case cancelled
    case inputOutputOverlap

    var errorDescription: String? {
        switch self {
        case .cannotReadImage: String(localized: "Could not read the image file")
        case .sourceUnavailable: String(localized: "The original file was moved or deleted")
        case .resizeFailed: String(localized: "Failed to resize the image")
        case .invalidDimensions: String(localized: "Image has invalid dimensions")
        case .cannotCreateDestination: String(localized: "Could not create output file")
        case .writeFailed: String(localized: "Failed to write the compressed image")
        case .outputLargerThanOriginal: String(localized: "Compressed file is larger than original")
        case .unsupportedFormat(let fmt): String(localized: "Unsupported format: \(fmt)")
        case .webpTooLarge: String(localized: "WebP images can be at most 16,383 pixels wide and tall. Set Max Longest Edge to 16,383 or less.")
        case .outputDirectoryNotWritable: String(localized: "Cannot write to the output folder")
        case .cancelled: String(localized: "Operation cancelled")
        case .inputOutputOverlap: String(localized: "The output folder can't be the folder your images are in, or a folder that contains it. Choose another folder, such as a new folder inside it.")
        }
    }
}
