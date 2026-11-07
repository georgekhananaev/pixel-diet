import Testing
import Foundation
import ImageIO
import UniformTypeIdentifiers
@testable import PixelDiet

// MARK: - ImageCompressor Tests

struct ImageCompressorTests {
    let compressor = ImageCompressor()

    @Test func webpPreservesSemiTransparentColor() throws {
        let dir = try TestImages.makeDirectory()
        let image = try TestImages.makeImage(width: 8, height: 8, red: 1, green: 0, blue: 0, alpha: 128.0 / 255.0)
        let source = try TestImages.write(image, to: dir.appendingPathComponent("alpha.png"), type: .png)
        let output = dir.appendingPathComponent("out")

        let result = try compressor.compress(
            task: TestImages.task(source: source, outputFormat: .webp),
            settings: TestImages.settings(outputDirectory: output, outputFormat: .webp, quality: 100)
        )

        let pixel = try TestImages.premultipliedCenterPixel(of: result.outputURL)
        #expect(abs(Int(pixel.alpha) - 128) <= 4)
        // Straight red 255 at alpha 128 premultiplies to ~128; feeding premultiplied
        // data to libwebp as straight alpha would darken it to ~64.
        #expect(abs(Int(pixel.red) - 128) <= 12)
    }

    @Test func webpAppliesExifOrientationWhenKeepingMetadata() throws {
        let dir = try TestImages.makeDirectory()
        let image = try TestImages.makeImage(width: 40, height: 20, red: 0, green: 0.5, blue: 1)
        let source = try TestImages.write(
            image, to: dir.appendingPathComponent("rotated.jpg"), type: .jpeg,
            properties: [kCGImagePropertyOrientation: 6]
        )

        let result = try compressor.compress(
            task: TestImages.task(source: source, outputFormat: .webp),
            settings: TestImages.settings(outputDirectory: dir.appendingPathComponent("out"), outputFormat: .webp, stripMetadata: false)
        )

        // WebP stores metadata as XMP without the orientation tag, so the rotation must be baked into the pixels.
        #expect(TestImages.pixelSize(of: result.outputURL) == CGSize(width: 20, height: 40))
    }

    /// Every format is written upright: BMP, AVIF and GIF cannot carry the orientation tag
    /// reliably, and a tag left next to already rotated pixels would turn the photo twice.
    @Test(arguments: [ImageFormat.jpeg, .png, .heic, .tiff, .bmp, .gif, .avif].filter(\.canBeOutput), [0, 1920])
    func photosAreSavedUprightWhenKeepingMetadata(format: ImageFormat, maxDimension: Int) throws {
        let dir = try TestImages.makeDirectory()
        let image = try TestImages.makeImage(width: 40, height: 20, red: 0, green: 0.5, blue: 1)
        let source = try TestImages.write(
            image, to: dir.appendingPathComponent("rotated.jpg"), type: .jpeg,
            properties: [kCGImagePropertyOrientation: 6]
        )

        let result = try compressor.compress(
            task: TestImages.task(source: source, outputFormat: format),
            settings: TestImages.settings(
                outputDirectory: dir.appendingPathComponent("out"), outputFormat: format,
                maxDimension: maxDimension, stripMetadata: false
            )
        )

        #expect(TestImages.pixelSize(of: result.outputURL) == CGSize(width: 20, height: 40))
        #expect((TestImages.orientation(of: result.outputURL) ?? 1) == 1)
    }

    @Test func keptMetadataDescribesTheResizedImage() throws {
        let dir = try TestImages.makeDirectory()
        let image = try TestImages.makeImage(width: 80, height: 40, red: 0.3, green: 0.6, blue: 0.9)
        let source = try TestImages.write(
            image, to: dir.appendingPathComponent("camera.jpg"), type: .jpeg,
            properties: [kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2026:10:20 09:41:00"]]
        )

        let result = try compressor.compress(
            task: TestImages.task(source: source, outputFormat: .heic),
            settings: TestImages.settings(
                outputDirectory: dir.appendingPathComponent("out"), outputFormat: .heic,
                maxDimension: 40, stripMetadata: false
            )
        )

        let exif = TestImages.properties(of: result.outputURL)[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        #expect(exif[kCGImagePropertyExifDateTimeOriginal] as? String == "2026:10:20 09:41:00")
        // The source's 80 x 40 would be wrong for the 40 x 20 output
        #expect([nil, 40].contains(exif[kCGImagePropertyExifPixelXDimension] as? Int))
        #expect([nil, 20].contains(exif[kCGImagePropertyExifPixelYDimension] as? Int))
    }

    @Test func skipIfLargerLeavesExistingDestinationUntouched() throws {
        let dir = try TestImages.makeDirectory()
        let image = try TestImages.makeImage(width: 64, height: 64, red: 0.2, green: 0.4, blue: 0.6)
        let source = try TestImages.write(image, to: dir.appendingPathComponent("tiny.png"), type: .png)
        let output = dir.appendingPathComponent("out", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let destination = output.appendingPathComponent("tiny.tiff")
        try Data("OLD".utf8).write(to: destination)

        // Uncompressed TIFF is far larger than a solid-color PNG.
        #expect(throws: CompressionError.outputLargerThanOriginal) {
            try compressor.compress(
                task: TestImages.task(source: source, outputFormat: .tiff, destination: destination),
                settings: TestImages.settings(outputDirectory: output, outputFormat: .tiff, skipIfLarger: true)
            )
        }

        #expect(try Data(contentsOf: destination) == Data("OLD".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: output.path) == ["tiny.tiff"])
    }

    @Test func overwriteReplacesExistingFile() throws {
        try assertOverwriteReplacesFile(in: TestImages.makeDirectory())
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["PIXELDIET_XVOL_DIR"] != nil,
                   "Set PIXELDIET_XVOL_DIR to a folder on a different volume than the temp directory"))
    func overwriteAcrossVolumesReplacesFile() throws {
        let base = URL(fileURLWithPath: ProcessInfo.processInfo.environment["PIXELDIET_XVOL_DIR"] ?? "")
        let dir = base.appendingPathComponent("PixelDietTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        // Source lives in the system temp directory, output on the other volume.
        let sourceDir = try TestImages.makeDirectory()
        try assertOverwriteReplacesFile(sourceDirectory: sourceDir, in: dir)
    }

    @Test func resizeScalesDownLongestEdgeAndNeverUpscales() throws {
        let dir = try TestImages.makeDirectory()
        let large = try TestImages.write(
            TestImages.makeImage(width: 400, height: 200, red: 0.3, green: 0.6, blue: 0.9),
            to: dir.appendingPathComponent("large.png"), type: .png
        )
        let small = try TestImages.write(
            TestImages.makeImage(width: 100, height: 50, red: 0.3, green: 0.6, blue: 0.9),
            to: dir.appendingPathComponent("small.png"), type: .png
        )
        let settings = TestImages.settings(outputDirectory: dir.appendingPathComponent("out"), maxDimension: 200)

        let scaled = try compressor.compress(task: TestImages.task(source: large, outputFormat: .png), settings: settings)
        let untouched = try compressor.compress(task: TestImages.task(source: small, outputFormat: .png), settings: settings)

        #expect(TestImages.pixelSize(of: scaled.outputURL) == CGSize(width: 200, height: 100))
        #expect(TestImages.pixelSize(of: untouched.outputURL) == CGSize(width: 100, height: 50))
    }

    @Test func missingSourceReportsThatTheFileIsGone() throws {
        let dir = try TestImages.makeDirectory()
        let source = try TestImages.write(
            TestImages.makeImage(width: 8, height: 8, red: 1, green: 1, blue: 1),
            to: dir.appendingPathComponent("gone.png"), type: .png
        )
        let task = try TestImages.task(source: source, outputFormat: .jpeg)
        try FileManager.default.removeItem(at: source)

        #expect(throws: CompressionError.sourceUnavailable) {
            try compressor.compress(task: task, settings: TestImages.settings(outputDirectory: dir.appendingPathComponent("out")))
        }
    }

    @Test func ppmSourceWithOriginalFormatProducesJPEG() throws {
        let dir = try TestImages.makeDirectory()
        let source = try TestImages.writePPM(width: 16, height: 16, to: dir.appendingPathComponent("scan.ppm"))
        let format = ImageFormat.resolvedOutput(requested: .original, source: .ppm)

        let result = try compressor.compress(
            task: TestImages.task(source: source, outputFormat: format),
            settings: TestImages.settings(outputDirectory: dir.appendingPathComponent("out"), outputFormat: .original)
        )

        #expect(result.outputURL.pathExtension == "jpg")
        #expect(TestImages.pixelSize(of: result.outputURL) == CGSize(width: 16, height: 16))
    }

    @Test(arguments: [ImageFormat.jpeg, .heic, .bmp])
    func transparentImageIsFlattenedOnWhite(format: ImageFormat) throws {
        let dir = try TestImages.makeDirectory()
        let image = try TestImages.makeImage(width: 8, height: 8, red: 0, green: 0, blue: 0, alpha: 0)
        let source = try TestImages.write(image, to: dir.appendingPathComponent("logo.png"), type: .png)

        let result = try compressor.compress(
            task: TestImages.task(source: source, outputFormat: format),
            settings: TestImages.settings(outputDirectory: dir.appendingPathComponent("out"), outputFormat: format, quality: 100)
        )

        // Opaque formats have no transparency; a white background matches what people expect
        let pixel = try TestImages.premultipliedCenterPixel(of: result.outputURL)
        #expect(pixel.red >= 250 && pixel.green >= 250 && pixel.blue >= 250)
    }

    @Test func grayscaleImageWithAlphaConvertsToJPEG() throws {
        let dir = try TestImages.makeDirectory()
        let source = try TestImages.write(
            TestImages.makeGrayAlphaImage(width: 12, height: 10), to: dir.appendingPathComponent("gray.png"), type: .png
        )

        let result = try compressor.compress(
            task: TestImages.task(source: source, outputFormat: .jpeg),
            settings: TestImages.settings(outputDirectory: dir.appendingPathComponent("out"))
        )

        #expect(TestImages.pixelSize(of: result.outputURL) == CGSize(width: 12, height: 10))
        // 50% gray at 50% alpha over white
        let pixel = try TestImages.premultipliedCenterPixel(of: result.outputURL)
        #expect(pixel.red > 150 && pixel.red < 250)
    }

    @Test(arguments: [ImageFormat.jpeg, .png, .webp])
    func colorProfileFollowsTheMetadataSetting(format: ImageFormat) throws {
        let dir = try TestImages.makeDirectory()
        let image = try TestImages.makeImage(width: 16, height: 16, red: 1, green: 0.2, blue: 0.1, colorSpace: CGColorSpace.displayP3)
        let source = try TestImages.write(image, to: dir.appendingPathComponent("wide.png"), type: .png)
        #expect(TestImages.profileName(of: source) == "Display P3")

        let kept = try compressor.compress(
            task: TestImages.task(source: source, outputFormat: format),
            settings: TestImages.settings(outputDirectory: dir.appendingPathComponent("kept"), outputFormat: format, stripMetadata: false)
        )
        let stripped = try compressor.compress(
            task: TestImages.task(source: source, outputFormat: format),
            settings: TestImages.settings(outputDirectory: dir.appendingPathComponent("stripped"), outputFormat: format)
        )

        // Keeping metadata keeps the wide-gamut profile; stripping converts to sRGB for the web
        #expect(TestImages.profileName(of: kept.outputURL) == "Display P3")
        if format == .webp {
            // WebP without a profile means sRGB, so none is stored
            #expect(try TestImages.webpChunks(of: stripped.outputURL)["ICCP"] == nil)
        } else {
            #expect(TestImages.profileName(of: stripped.outputURL)?.contains("sRGB") == true)
        }
    }

    @Test func webpKeepsColorProfileAndMetadataWhenAsked() throws {
        let dir = try TestImages.makeDirectory()
        let image = try TestImages.makeImage(width: 40, height: 20, red: 0.9, green: 0.3, blue: 0.1, colorSpace: CGColorSpace.displayP3)
        let source = try TestImages.write(
            image, to: dir.appendingPathComponent("camera.jpg"), type: .jpeg,
            properties: [
                kCGImagePropertyOrientation: 6,
                kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2026:10:20 09:41:00"],
            ]
        )

        let kept = try compressor.compress(
            task: TestImages.task(source: source, outputFormat: .webp),
            settings: TestImages.settings(outputDirectory: dir.appendingPathComponent("kept"), outputFormat: .webp, stripMetadata: false)
        )
        let stripped = try compressor.compress(
            task: TestImages.task(source: source, outputFormat: .webp),
            settings: TestImages.settings(outputDirectory: dir.appendingPathComponent("stripped"), outputFormat: .webp)
        )

        let keptChunks = try TestImages.webpChunks(of: kept.outputURL)
        let xmp = try #require(keptChunks["XMP "].map { String(decoding: $0, as: UTF8.self) })
        #expect(keptChunks["ICCP"] != nil)
        #expect(xmp.contains("2026-10-20T09:41:00"))
        // The rotation is applied to the pixels, so the tag must not rotate them again
        #expect(!xmp.contains("Orientation"))
        #expect(TestImages.displaySize(of: kept.outputURL) == CGSize(width: 20, height: 40))
        #expect(TestImages.profileName(of: kept.outputURL) == "Display P3")

        let strippedChunks = try TestImages.webpChunks(of: stripped.outputURL)
        #expect(strippedChunks["ICCP"] == nil && strippedChunks["XMP "] == nil && strippedChunks["EXIF"] == nil)
    }

    @Test func webpExplainsItsSizeLimit() throws {
        let dir = try TestImages.makeDirectory()
        let image = try TestImages.makeImage(width: WebPEncoder.maxDimension + 1, height: 2, red: 0.5, green: 0.5, blue: 0.5)
        let source = try TestImages.write(image, to: dir.appendingPathComponent("panorama.png"), type: .png)

        #expect(throws: CompressionError.webpTooLarge) {
            try compressor.compress(
                task: TestImages.task(source: source, outputFormat: .webp),
                settings: TestImages.settings(outputDirectory: dir.appendingPathComponent("out"), outputFormat: .webp)
            )
        }
    }

    /// 8-bit bitmaps cannot use extended-range color spaces, so such images are drawn in sRGB
    @Test(arguments: [ImageFormat.jpeg, .webp])
    func extendedRangeImageWithTransparencyConverts(format: ImageFormat) throws {
        let dir = try TestImages.makeDirectory()
        let source = try TestImages.write(
            TestImages.makeExtendedRangeImage(width: 16, height: 16, alpha: 0),
            to: dir.appendingPathComponent("hdr.tiff"), type: .tiff
        )

        let result = try compressor.compress(
            task: TestImages.task(source: source, outputFormat: format),
            settings: TestImages.settings(outputDirectory: dir.appendingPathComponent("out"), outputFormat: format, stripMetadata: false)
        )

        let pixel = try TestImages.premultipliedCenterPixel(of: result.outputURL)
        if format.supportsAlpha {
            #expect(pixel.alpha == 0)
        } else {
            #expect(pixel.red >= 250 && pixel.green >= 250 && pixel.blue >= 250, "Placed on white")
        }
    }

    /// The pixel buffer is reused memory: an earlier image must never show through transparent areas
    @Test func webpTransparentAreasStayClearAfterAnOpaqueImage() throws {
        let dir = try TestImages.makeDirectory()
        let opaque = try TestImages.write(
            TestImages.makeImage(width: 256, height: 256, red: 1, green: 0, blue: 0),
            to: dir.appendingPathComponent("opaque.png"), type: .png
        )
        let clear = try TestImages.write(
            TestImages.makeImage(width: 256, height: 256, red: 0, green: 0, blue: 0, alpha: 0),
            to: dir.appendingPathComponent("clear.png"), type: .png
        )

        for source in [opaque, clear] {
            _ = try compressor.compress(
                task: TestImages.task(source: source, outputFormat: .webp),
                settings: TestImages.settings(outputDirectory: dir.appendingPathComponent("out"), outputFormat: .webp, quality: 100)
            )
        }

        let pixel = try TestImages.premultipliedCenterPixel(of: dir.appendingPathComponent("out/clear.webp"))
        #expect(pixel.alpha == 0 && pixel.red == 0)
    }

    @Test func webpWithAlphaKeepsTransparencyWhenKeepingMetadata() throws {
        let dir = try TestImages.makeDirectory()
        let image = try TestImages.makeImage(width: 8, height: 8, red: 1, green: 0, blue: 0, alpha: 128.0 / 255.0)
        let source = try TestImages.write(image, to: dir.appendingPathComponent("alpha.png"), type: .png)

        let result = try compressor.compress(
            task: TestImages.task(source: source, outputFormat: .webp),
            settings: TestImages.settings(outputDirectory: dir.appendingPathComponent("out"), outputFormat: .webp, quality: 100, stripMetadata: false)
        )

        let pixel = try TestImages.premultipliedCenterPixel(of: result.outputURL)
        #expect(abs(Int(pixel.alpha) - 128) <= 4)
        #expect(abs(Int(pixel.red) - 128) <= 12)
    }

    private func assertOverwriteReplacesFile(sourceDirectory: URL? = nil, in outputDirectory: URL) throws {
        let image = try TestImages.makeImage(width: 32, height: 32, red: 1, green: 0.5, blue: 0)
        let source = try TestImages.write(
            image, to: (sourceDirectory ?? outputDirectory).appendingPathComponent("source.png"), type: .png
        )
        let output = outputDirectory.appendingPathComponent("out", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let destination = output.appendingPathComponent("source.jpg")
        try Data("OLD".utf8).write(to: destination)

        let result = try compressor.compress(
            task: TestImages.task(source: source, outputFormat: .jpeg, destination: destination),
            settings: TestImages.settings(outputDirectory: output)
        )

        #expect(result.outputURL.standardizedFileURL == destination.standardizedFileURL)
        #expect(TestImages.pixelSize(of: destination) == CGSize(width: 32, height: 32))
        #expect(try FileManager.default.contentsOfDirectory(atPath: output.path) == ["source.jpg"])
    }
}

// MARK: - Output Format Resolution Tests

struct OutputFormatResolutionTests {
    @Test func originalFormatFallsBackToJPEGForUnwritableSource() {
        #expect(ImageFormat.resolvedOutput(requested: .original, source: .ppm) == .jpeg)
        #expect(ImageFormat.resolvedOutput(requested: .original, source: nil) == .jpeg)
        #expect(ImageFormat.resolvedOutput(requested: .original, source: .png) == .png)
        #expect(ImageFormat.resolvedOutput(requested: .webp, source: .png) == .webp)
    }
}

// MARK: - ImageAnalyzer Tests

struct ImageAnalyzerTests {
    @Test func analyzeRejectsNonImageFiles() throws {
        let dir = try TestImages.makeDirectory()
        let text = dir.appendingPathComponent("notes.txt")
        try Data("not an image".utf8).write(to: text)

        #expect(throws: CompressionError.cannotReadImage) {
            try ImageAnalyzer().analyze(url: text)
        }
    }

    @Test func analyzeReadsImageInfo() throws {
        let dir = try TestImages.makeDirectory()
        let image = try TestImages.makeImage(width: 30, height: 20, red: 1, green: 1, blue: 0)
        let url = try TestImages.write(image, to: dir.appendingPathComponent("photo"), type: .png)

        let info = try ImageAnalyzer().analyze(url: url)
        #expect(info.dimensions == CGSize(width: 30, height: 20))
        #expect(info.detectedFormat == .png)
        #expect(info.fileSize == (try TestImages.fileSize(of: url)))
    }

    @Test func analyzeReportsHowPixelsAreStored() throws {
        let dir = try TestImages.makeDirectory()
        let image = try TestImages.makeImage(width: 8, height: 8, red: 1, green: 0, blue: 0, alpha: 0.5)
        let logo = try TestImages.write(image, to: dir.appendingPathComponent("logo.png"), type: .png)
        let photo = try TestImages.write(image, to: dir.appendingPathComponent("photo.jpg"), type: .jpeg)
        let web = try TestImages.write(
            image, to: dir.appendingPathComponent("web.png"), type: .png,
            properties: [kCGImagePropertyPNGDictionary: [kCGImagePropertyPNGInterlaceType: 1]]
        )
        let print = try TestImages.write(
            TestImages.makeHighBitDepthImage(width: 8, height: 8), to: dir.appendingPathComponent("print.tiff"), type: .tiff
        )

        #expect(try ImageAnalyzer().analyze(url: logo).pixelLayout == PixelLayout(hasAlpha: true))
        #expect(try ImageAnalyzer().analyze(url: photo).pixelLayout == PixelLayout())
        #expect(try ImageAnalyzer().analyze(url: web).pixelLayout == PixelLayout(hasAlpha: true, isInterlaced: true))
        #expect(try ImageAnalyzer().analyze(url: print).pixelLayout == PixelLayout(isHighBitDepth: true))
    }

    @Test func symbolicLinksReportTheSizeOfTheirImage() throws {
        let dir = try TestImages.makeDirectory()
        let image = try TestImages.makeImage(width: 30, height: 20, red: 1, green: 0, blue: 0)
        let target = try TestImages.write(image, to: dir.appendingPathComponent("photo.png"), type: .png)
        let link = dir.appendingPathComponent("link.png")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        let size = try TestImages.fileSize(of: target)

        #expect(try ImageAnalyzer().analyze(url: link).fileSize == size)
        let result = try ImageCompressor().compress(
            task: TestImages.task(source: link, outputFormat: .jpeg),
            settings: TestImages.settings(outputDirectory: dir.appendingPathComponent("out"))
        )
        #expect(result.sourceSize == size)
    }

    @Test func analyzeReportsDisplayedDimensionsOfRotatedPhotos() throws {
        let dir = try TestImages.makeDirectory()
        let image = try TestImages.makeImage(width: 40, height: 20, red: 0, green: 0.5, blue: 1)
        let url = try TestImages.write(
            image, to: dir.appendingPathComponent("portrait.jpg"), type: .jpeg,
            properties: [kCGImagePropertyOrientation: 6]
        )

        #expect(try ImageAnalyzer().analyze(url: url).dimensions == CGSize(width: 20, height: 40))
    }

    @Test func analyzeReportsColorProfileName() throws {
        let dir = try TestImages.makeDirectory()
        let image = try TestImages.makeImage(width: 8, height: 8, red: 1, green: 0, blue: 0, colorSpace: CGColorSpace.displayP3)
        let url = try TestImages.write(image, to: dir.appendingPathComponent("wide.png"), type: .png)

        #expect(try ImageAnalyzer().analyze(url: url).colorSpaceName == "Display P3")
    }
}

// MARK: - Temp File Sweeper Tests

struct TempFileSweeperTests {
    @Test func removesOnlyStaleTempFiles() throws {
        let dir = try TestImages.makeDirectory()
        let now = Date()
        func makeFile(_ name: String, age: TimeInterval) throws -> URL {
            let url = dir.appendingPathComponent(name)
            try Data("x".utf8).write(to: url)
            try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(-age)], ofItemAtPath: url.path)
            return url
        }
        let stale = try makeFile(".pixeldiet-0A1B.jpg", age: 7200)
        let inFlight = try makeFile(".pixeldiet-2C3D.webp", age: 5)
        let photo = try makeFile("photo.jpg", age: 7200)
        let otherHidden = try makeFile(".hidden-notes", age: 7200)

        TempFileSweeper.removeStaleFiles(in: [dir, dir.appendingPathComponent("missing")], now: now)

        #expect(!FileManager.default.fileExists(atPath: stale.path))
        for kept in [inFlight, photo, otherHidden] {
            #expect(FileManager.default.fileExists(atPath: kept.path))
        }
    }
}
