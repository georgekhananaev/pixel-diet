import Foundation
import CoreGraphics
import ImageIO
import Accelerate
import libwebp

/// Encodes images to WebP with libwebp (ImageIO reads WebP but cannot write it).
nonisolated enum WebPEncoder {
    /// Largest width or height a WebP image can have (`WEBP_MAX_DIMENSION`).
    static let maxDimension = 16_383

    /// - Parameter metadata: When given, the image keeps its own RGB color profile (ICCP chunk)
    ///   and this metadata as XMP; otherwise colors are converted to sRGB and nothing else is
    ///   stored. Either way the pixels must already be in display orientation.
    static func encode(_ image: CGImage, quality: Int, metadata: CGImageMetadata?) throws -> Data {
        guard image.width <= maxDimension, image.height <= maxDimension else {
            throw CompressionError.webpTooLarge
        }
        guard let sRGB = CGColorSpace(name: CGColorSpace.sRGB) else { throw CompressionError.writeFailed }
        let keepsProfile = metadata != nil && image.colorSpace?.model == .rgb && !image.usesExtendedRange
        let colorSpace = keepsProfile ? image.colorSpace ?? sRGB : sRGB

        let bitstream = try encodePixels(of: image, in: colorSpace, quality: quality)
        guard let metadata else { return bitstream }

        // sRGB is what WebP viewers assume, so its profile is not worth the bytes
        let profile = colorSpace.name == CGColorSpace.sRGB ? nil : colorSpace.copyICCData() as Data?
        return try mux(bitstream, chunks: [("ICCP", profile), ("XMP ", xmpData(from: metadata))])
    }

    // MARK: - Pixels

    /// Lossy encode with libwebp's advanced API.
    private static func encodePixels(of image: CGImage, in colorSpace: CGColorSpace, quality: Int) throws -> Data {
        var config = WebPConfig()
        guard WebPConfigInit(&config) != 0 else { throw CompressionError.writeFailed }
        config.quality = Float(quality)
        // 0 = fastest ... 6 = smallest. libwebp's default 4 gives ~4% smaller photos than 2
        // for about 45 ms more per 1920 px image
        config.method = 4
        config.thread_level = 1  // Multi-threaded encoding
        guard WebPValidateConfig(&config) != 0 else { throw CompressionError.writeFailed }

        var picture = WebPPicture()
        guard WebPPictureInit(&picture) != 0 else { throw CompressionError.writeFailed }
        picture.width = Int32(image.width)
        picture.height = Int32(image.height)
        // YUV from the start (what lossy encoding uses): no extra ARGB copy of the image
        picture.use_argb = 0
        defer { WebPPictureFree(&picture) }
        try importPixels(of: image, in: colorSpace, into: &picture)

        // Heap-allocated: its address is handed to libwebp as custom_ptr
        let writer = UnsafeMutablePointer<WebPMemoryWriter>.allocate(capacity: 1)
        WebPMemoryWriterInit(writer)
        defer {
            WebPMemoryWriterClear(writer)
            writer.deallocate()
        }
        picture.writer = WebPMemoryWrite
        picture.custom_ptr = UnsafeMutableRawPointer(writer)

        guard WebPEncode(&config, &picture) != 0, let encoded = writer.pointee.mem, writer.pointee.size > 0 else {
            throw CompressionError.writeFailed
        }
        return Data(bytes: encoded, count: writer.pointee.size)
    }

    /// Draws the image as RGBA and converts it into the picture. Images with alpha are drawn
    /// premultiplied (a CGContext requirement), then un-premultiplied, as WebPPictureImportRGBA
    /// expects straight alpha. The RGBA buffer is freed before encoding starts.
    private static func importPixels(of image: CGImage, in colorSpace: CGColorSpace, into picture: inout WebPPicture) throws {
        let width = image.width
        let height = image.height
        let hasAlpha = image.hasAlpha
        let bytesPerRow = width * 4
        // Cleared first: drawing blends over the buffer, so reused memory would show
        // through transparent areas
        let pixels = UnsafeMutablePointer<UInt8>.allocate(capacity: bytesPerRow * height)
        pixels.initialize(repeating: 0, count: bytesPerRow * height)
        defer { pixels.deallocate() }

        // Opaque images skip the 4th byte (RGBX import, no alpha processing)
        let alphaInfo: CGImageAlphaInfo = hasAlpha ? .premultipliedLast : .noneSkipLast
        guard let context = CGContext(
            data: pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow,
            space: colorSpace, bitmapInfo: alphaInfo.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            throw CompressionError.writeFailed
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let imported: Int32
        if hasAlpha {
            var buffer = vImage_Buffer(
                data: pixels, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: bytesPerRow
            )
            guard vImageUnpremultiplyData_RGBA8888(&buffer, &buffer, vImage_Flags(kvImageNoFlags)) == kvImageNoError else {
                throw CompressionError.writeFailed
            }
            imported = WebPPictureImportRGBA(&picture, pixels, Int32(bytesPerRow))
        } else {
            imported = WebPPictureImportRGBX(&picture, pixels, Int32(bytesPerRow))
        }
        guard imported != 0 else { throw CompressionError.writeFailed }
    }

    // MARK: - Metadata

    /// The source metadata as XMP, without the tags that no longer describe the output:
    /// the orientation (already applied to the pixels) and the original pixel size.
    private static func xmpData(from metadata: CGImageMetadata) -> Data? {
        guard let editable = CGImageMetadataCreateMutableCopy(metadata) else { return nil }
        for path in ["tiff:Orientation", "tiff:ImageWidth", "tiff:ImageLength", "exif:PixelXDimension", "exif:PixelYDimension"] {
            CGImageMetadataRemoveTagWithPath(editable, nil, path as CFString)
        }
        return CGImageMetadataCreateXMPData(editable, nil) as Data?
    }

    /// Wraps a WebP bitstream in an extended (VP8X) container with the given chunks.
    private static func mux(_ bitstream: Data, chunks: [(fourCC: String, payload: Data?)]) throws -> Data {
        let present = chunks.compactMap { chunk in chunk.payload.map { (chunk.fourCC, $0) } }
        guard !present.isEmpty else { return bitstream }
        guard let mux = WebPMuxNew() else { throw CompressionError.writeFailed }
        defer { WebPMuxDelete(mux) }

        // copy_data = 1: the mux keeps its own copies, so the buffers need only live for each call
        try bitstream.withUnsafeBytes { raw in
            var image = WebPData(bytes: raw.bindMemory(to: UInt8.self).baseAddress, size: raw.count)
            guard WebPMuxSetImage(mux, &image, 1) == WEBP_MUX_OK else { throw CompressionError.writeFailed }
        }
        for (fourCC, payload) in present {
            try payload.withUnsafeBytes { raw in
                var chunk = WebPData(bytes: raw.bindMemory(to: UInt8.self).baseAddress, size: raw.count)
                guard WebPMuxSetChunk(mux, fourCC, &chunk, 1) == WEBP_MUX_OK else { throw CompressionError.writeFailed }
            }
        }

        var assembled = WebPData()
        guard WebPMuxAssemble(mux, &assembled) == WEBP_MUX_OK, let bytes = assembled.bytes else {
            throw CompressionError.writeFailed
        }
        defer { WebPDataClear(&assembled) }
        return Data(bytes: bytes, count: assembled.size)
    }
}
