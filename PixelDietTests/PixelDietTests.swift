import Testing
import AppKit
import UniformTypeIdentifiers
@testable import PixelDiet

// MARK: - ImageFormat Tests

struct ImageFormatTests {
    @Test func extensionDetection() {
        #expect(ImageFormat.from(extension: "jpg") == .jpeg)
        #expect(ImageFormat.from(extension: "jpeg") == .jpeg)
        #expect(ImageFormat.from(extension: "PNG") == .png)
        #expect(ImageFormat.from(extension: "HEIC") == .heic)
        #expect(ImageFormat.from(extension: "tif") == .tiff)
        #expect(ImageFormat.from(extension: "unknown") == nil)
        #expect(ImageFormat.from(extension: "") == nil)
    }

    @Test func typeIdentifierDetection() {
        #expect(ImageFormat.from(typeIdentifier: "public.jpeg") == .jpeg)
        #expect(ImageFormat.from(typeIdentifier: "public.png") == .png)
        #expect(ImageFormat.from(typeIdentifier: "org.webmproject.webp") == .webp)
        #expect(ImageFormat.from(typeIdentifier: "unknown.type") == nil)
    }

    @Test func canBeOutput() {
        #expect(ImageFormat.jpeg.canBeOutput == true)
        #expect(ImageFormat.png.canBeOutput == true)
        #expect(ImageFormat.ppm.canBeOutput == false)
    }

    @Test func supportsQuality() {
        #expect(ImageFormat.jpeg.supportsQuality == true)
        #expect(ImageFormat.webp.supportsQuality == true)
        #expect(ImageFormat.png.supportsQuality == false)
        #expect(ImageFormat.bmp.supportsQuality == false)
    }

    @Test func fileExtension() {
        #expect(ImageFormat.jpeg.fileExtension == "jpg")
        #expect(ImageFormat.png.fileExtension == "png")
        #expect(ImageFormat.heif.fileExtension == "heif")
        #expect(ImageFormat.original.fileExtension == "")
    }

    @Test func allInputExtensions() {
        let exts = ImageFormat.allInputExtensions
        #expect(exts.contains("jpg"))
        #expect(exts.contains("jpeg"))
        #expect(exts.contains("png"))
        #expect(exts.contains("heic"))
        #expect(exts.contains("webp"))
        #expect(!exts.contains("txt"))
    }
}

// MARK: - ProcessingStatus Tests

struct ProcessingStatusTests {
    @Test func equality() {
        #expect(ProcessingStatus.queued == ProcessingStatus.queued)
        #expect(ProcessingStatus.completed == ProcessingStatus.completed)
        #expect(ProcessingStatus.skipped(reason: "test") == ProcessingStatus.skipped(reason: "test"))
        #expect(ProcessingStatus.skipped(reason: "a") != ProcessingStatus.skipped(reason: "b"))
    }
}

// MARK: - CompressionSettings Tests

@MainActor
struct CompressionSettingsTests {
    @Test func defaultValues() {
        let settings = TestSettings.make()
        #expect(settings.quality == 80)
        #expect(settings.maxDimension == 1920)
        #expect(settings.outputFormat == .jpeg)
        #expect(settings.stripMetadata == true)
        #expect(settings.skipIfLarger == true)
        #expect(settings.preserveDirectoryStructure == false)
        #expect(settings.outputDirectory == nil)
    }

    @Test func qualityClamping() {
        let settings = TestSettings.make()
        settings.setQuality(5)
        #expect(settings.quality == 10)
        settings.setQuality(150)
        #expect(settings.quality == 100)
        settings.setQuality(50)
        #expect(settings.quality == 50)
    }

    @Test func maxDimensionClamping() {
        let settings = TestSettings.make()
        settings.setMaxDimension(0)
        #expect(settings.maxDimension == 0) // 0 = no resize
        settings.setMaxDimension(10)
        #expect(settings.maxDimension == 64) // min
        settings.setMaxDimension(99999)
        #expect(settings.maxDimension == 16383) // max: the largest WebP size
        settings.setMaxDimension(1920)
        #expect(settings.maxDimension == 1920)
    }

    @Test func snapshot() {
        let settings = TestSettings.make()
        #expect(settings.snapshot() == nil) // nil when no output directory

        settings.chooseOutputDirectory(URL(fileURLWithPath: "/tmp/test"))
        let snap = settings.snapshot()
        #expect(snap != nil)
        #expect(snap?.quality == 80)
        #expect(snap?.maxDimension == 1920)
        #expect(snap?.outputFormat == .jpeg)
        #expect(snap?.outputDirectory.path == "/tmp/test")
    }
}

// MARK: - PathSanitizer Tests

struct PathSanitizerTests {
    @Test func buildDestinationURL() throws {
        let source = URL(fileURLWithPath: "/input/photo.jpg")
        let outputDir = URL(fileURLWithPath: "/output")
        let url = try PathSanitizer.buildDestinationURL(
            source: source,
            outputDir: outputDir,
            format: .webp,
            relativePath: nil
        )
        #expect(url.lastPathComponent == "photo.webp")
        #expect(url.deletingLastPathComponent().path == "/output")
    }

    @Test func filenameWithPathSeparator() throws {
        let source = URL(fileURLWithPath: "/input/photo/evil.jpg")
        let outputDir = URL(fileURLWithPath: "/output")
        let url = try PathSanitizer.buildDestinationURL(
            source: source,
            outputDir: outputDir,
            format: .png,
            relativePath: nil
        )
        // The filename should not contain path separators
        #expect(!url.lastPathComponent.contains("/"))
    }

    @Test func numberedVariantKeepsTheOriginalStem() {
        let url = URL(fileURLWithPath: "/output/photo.jpg")
        #expect(PathSanitizer.numberedVariant(of: url, number: 1).lastPathComponent == "photo-1.jpg")
        #expect(PathSanitizer.numberedVariant(of: url, number: 2).lastPathComponent == "photo-2.jpg")
        // A user's own trailing number is part of the name, not a counter
        let dated = URL(fileURLWithPath: "/output/2024-05-01.jpg")
        #expect(PathSanitizer.numberedVariant(of: dated, number: 1).lastPathComponent == "2024-05-01-1.jpg")
    }

    @Test func destinationKeepsMultiDotAndUnicodeNames() throws {
        let outputDir = URL(fileURLWithPath: "/output")
        let multiDot = try PathSanitizer.buildDestinationURL(
            source: URL(fileURLWithPath: "/input/my.photo.v2.jpg"), outputDir: outputDir, format: .webp, relativePath: nil
        )
        #expect(multiDot.lastPathComponent == "my.photo.v2.webp")

        let unicode = try PathSanitizer.buildDestinationURL(
            source: URL(fileURLWithPath: "/input/фото 1.png"), outputDir: outputDir, format: .jpeg, relativePath: nil
        )
        #expect(unicode.lastPathComponent == "фото 1.jpg")

        #expect(PathSanitizer.numberedVariant(of: URL(fileURLWithPath: "/output/img-3.jpg"), number: 1).lastPathComponent == "img-3-1.jpg")
    }

    @Test func relativePathCannotEscapeOutputDirectory() {
        let source = URL(fileURLWithPath: "/input/x.jpg")
        #expect(throws: CompressionError.self) {
            try PathSanitizer.buildDestinationURL(
                source: source, outputDir: URL(fileURLWithPath: "/out"), format: .jpeg, relativePath: "../out2/x.jpg"
            )
        }
        #expect(throws: CompressionError.self) {
            try PathSanitizer.buildDestinationURL(
                source: source, outputDir: URL(fileURLWithPath: "/out"), format: .jpeg, relativePath: "../../etc/x.jpg"
            )
        }
    }

    @Test func overlapValidation() throws {
        let inputURLs = [URL(fileURLWithPath: "/photos/img1.jpg")]
        let outputDir = URL(fileURLWithPath: "/output")
        // Different dirs — should not throw
        try PathSanitizer.validateNoOverlap(inputURLs: inputURLs, outputDir: outputDir)

        // Same dir — should throw
        let sameDir = URL(fileURLWithPath: "/photos")
        #expect(throws: CompressionError.self) {
            try PathSanitizer.validateNoOverlap(inputURLs: inputURLs, outputDir: sameDir)
        }
    }
}

// MARK: - BatchJob Tests

@MainActor
struct BatchJobTests {
    @Test func addItemsDeduplication() {
        let job = BatchJob()
        let url = URL(fileURLWithPath: "/test/img.jpg")
        let item1 = ImageItem(
            sourceURL: url, originalSize: 1000,
            originalDimensions: CGSize(width: 100, height: 100)
        )
        let item2 = ImageItem(
            sourceURL: url, originalSize: 1000,
            originalDimensions: CGSize(width: 100, height: 100)
        )
        job.addItems([item1])
        #expect(job.items.count == 1)
        job.addItems([item2])
        #expect(job.items.count == 1) // Deduplicated
    }

    @Test func addItemsDeduplicatesWithinOneImport() {
        let job = BatchJob()
        let url = URL(fileURLWithPath: "/test/img.jpg")
        let items = (0..<2).map { _ in
            ImageItem(sourceURL: url, originalSize: 1000, originalDimensions: CGSize(width: 100, height: 100))
        }
        #expect(job.addItems(items).count == 1)
        #expect(job.items.count == 1)
        #expect(job.totalOriginalSize == 1000)
    }

    @Test func incrementalCounters() {
        let job = BatchJob()
        let item = ImageItem(
            sourceURL: URL(fileURLWithPath: "/test/img.jpg"),
            originalSize: 1000,
            originalDimensions: CGSize(width: 100, height: 100)
        )
        job.addItems([item])
        job.startRun(format: "JPEG", quality: 80, itemCount: 2)

        job.recordCompletion(status: .completed, originalSize: 1000, compressedSize: 500)
        #expect(job.activeRun?.completedCount == 1)
        #expect(job.activeRun?.processedCount == 1)
        #expect(job.progress == 0.5)

        job.recordCompletion(status: .failed(error: "test"), originalSize: 1000, compressedSize: nil)
        #expect(job.activeRun?.failedCount == 1)
        #expect(job.activeRun?.processedCount == 2)
        #expect(job.activeRun?.totalSavings == 500)
    }

    @Test func clear() {
        let job = BatchJob()
        let item = ImageItem(
            sourceURL: URL(fileURLWithPath: "/test/img.jpg"),
            originalSize: 1000,
            originalDimensions: CGSize(width: 100, height: 100)
        )
        job.addItems([item])
        job.startRun(format: "JPEG", quality: 80, itemCount: 1)
        job.recordCompletion(status: .completed, originalSize: 1000, compressedSize: 500)
        job.clear()
        #expect(job.items.isEmpty)
        #expect(job.runHistory.isEmpty)
        #expect(job.totalOriginalSize == 0)
    }
}

// MARK: - CompressionError Tests

struct CompressionErrorTests {
    @Test func localizedDescription() {
        let error = CompressionError.cannotReadImage
        #expect(error.errorDescription != nil)
        #expect(!error.errorDescription!.isEmpty)
    }

    @Test func unsupportedFormatIncludesName() {
        let error = CompressionError.unsupportedFormat("TARGA")
        #expect(error.errorDescription?.contains("TARGA") == true)
    }
}

// MARK: - SettingsStore Tests

@MainActor
struct SettingsStoreTests {
    @Test func saveAndLoad() throws {
        try TestSettings.withScratchDefaults { defaults in
            let store = SettingsStore(defaults: defaults)

            let data = SettingsData(
                outputFormat: "png",
                quality: 60,
                maxDimension: 1280,
                preserveDirectoryStructure: true,
                stripMetadata: false,
                skipIfLarger: false
            )
            try store.save(data)

            let loaded = store.load()
            #expect(loaded?.outputFormat == "png")
            #expect(loaded?.quality == 60)
            #expect(loaded?.maxDimension == 1280)
            #expect(loaded?.preserveDirectoryStructure == true)
            #expect(loaded?.stripMetadata == false)
        }
    }
}

// MARK: - Savings Display Tests

@MainActor
struct SavingsDisplayTests {
    @Test func nearlyCompleteSavingsNeverReadAsHundredPercent() {
        #expect(SavingsIndicator.percentText(for: 99.6) == "99%")
        #expect(SavingsIndicator.percentText(for: 100) == "100%")
        #expect(SavingsIndicator.percentText(for: 42.5) == "43%")
        #expect(SavingsIndicator.percentText(for: -12.4) == "12%")
    }

    @Test func accessibilityTextDescribesDirection() {
        #expect(SavingsIndicator.accessibilityText(for: 99.6) == "Saved 99 percent")
        #expect(SavingsIndicator.accessibilityText(for: -12.4) == "Increased by 12 percent")
    }
}

// MARK: - Counted Text Tests

struct CountTextTests {
    @Test func countedPhrasesUseTheSingularForOne() {
        #expect(CountText.images(1) == "1 image")
        #expect(CountText.images(2) == "2 images")
        #expect(CountText.compressImages(1) == "Compress 1 Image")
        #expect(CountText.compressImages(12) == "Compress 12 Images")
        #expect(CountText.items(1) == "1 item")
        #expect(CountText.items(3) == "3 items")
        #expect(CountText.imagesCompressed(1) == "Batch complete - 1 image compressed")
        #expect(CountText.imagesCompressed(5) == "Batch complete - 5 images compressed")
    }
}

// MARK: - Open Panel Tests

@MainActor
struct OpenPanelsTests {
    /// Apps built with the macOS 27 SDK derive `canChooseFiles`/`canChooseDirectories`
    /// from `allowedContentTypes`, so an image-only list would make folders unselectable
    @Test func addImagesPanelAcceptsImagesAndFolders() {
        let panel = OpenPanels.makeAddImagesPanel()
        #expect(panel.canChooseFiles)
        #expect(panel.canChooseDirectories)
        #expect(panel.allowsMultipleSelection)
        #expect(panel.allowedContentTypes.contains(.image))
        #expect(panel.allowedContentTypes.contains(.folder), "Folders stay selectable however AppKit derives the flags")
    }
}
