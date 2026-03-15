import Foundation

nonisolated enum CompressionError: LocalizedError, Sendable {
    case cannotReadImage
    case resizeFailed
    case invalidDimensions
    case cannotCreateDestination
    case writeFailed
    case outputLargerThanOriginal
    case unsupportedFormat(String)
    case outputDirectoryNotWritable
    case diskFull
    case cancelled
    case inputOutputOverlap

    var errorDescription: String? {
        switch self {
        case .cannotReadImage: String(localized: "Could not read the image file")
        case .resizeFailed: String(localized: "Failed to resize the image")
        case .invalidDimensions: String(localized: "Image has invalid dimensions")
        case .cannotCreateDestination: String(localized: "Could not create output file")
        case .writeFailed: String(localized: "Failed to write the compressed image")
        case .outputLargerThanOriginal: String(localized: "Compressed file is larger than original")
        case .unsupportedFormat(let fmt): String(localized: "Unsupported format: \(fmt)")
        case .outputDirectoryNotWritable: String(localized: "Cannot write to the output folder")
        case .diskFull: String(localized: "Not enough disk space")
        case .cancelled: String(localized: "Operation cancelled")
        case .inputOutputOverlap: String(localized: "Output folder cannot be inside input folder")
        }
    }
}
