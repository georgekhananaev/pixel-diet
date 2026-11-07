import Testing
import Foundation
import UniformTypeIdentifiers
import IOKit.pwr_mgt
@testable import PixelDiet

// MARK: - Test Doubles

@MainActor
final class RecordingFeedback: BatchFeedback {
    private(set) var finishedCounts: [Int] = []

    func progressDidChange(_ fraction: Double?) {}

    func batchDidFinish(completedCount: Int) {
        finishedCounts.append(completedCount)
    }
}

/// Real analyzer that pauses on files whose name starts with "slow", to keep an import running.
struct SlowAnalyzer: ImageAnalyzing {
    let delay: TimeInterval
    private let analyzer = ImageAnalyzer()

    func analyze(url: URL) throws -> ImageAnalyzer.ImageInfo {
        if url.lastPathComponent.hasPrefix("slow") { Thread.sleep(forTimeInterval: delay) }
        return try analyzer.analyze(url: url)
    }
}

/// Lets a test flip a fake compressor between failing and succeeding.
final class FailureSwitch: @unchecked Sendable {
    private let lock = NSLock()
    private var on = false

    var isOn: Bool {
        get { lock.withLock { on } }
        set { lock.withLock { on = newValue } }
    }
}

// MARK: - MainViewModel Tests

/// Serialized: every run holds the same named power assertion, which
/// `compressingKeepsTheMacAwakeUntilTheRunEnds` checks process-wide
@MainActor
@Suite(.serialized)
struct MainViewModelTests {
    private struct Fixture {
        let viewModel: MainViewModel
        let feedback: RecordingFeedback
        let input: URL
        let output: URL
    }

    private func makeFixture(
        compressor: any ImageCompressing = ImageCompressor(),
        analyzer: any ImageAnalyzing = ImageAnalyzer()
    ) throws -> Fixture {
        let root = try TestImages.makeDirectory()
        let input = root.appendingPathComponent("in", isDirectory: true)
        let output = root.appendingPathComponent("out", isDirectory: true)
        try FileManager.default.createDirectory(at: input, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        let settings = TestSettings.make()
        settings.chooseOutputDirectory(output)
        settings.setMaxDimension(0)
        settings.skipIfLarger = false
        let feedback = RecordingFeedback()
        let viewModel = MainViewModel(
            settings: settings,
            batchProcessor: BatchProcessor(compressor: compressor),
            analyzer: analyzer,
            feedback: feedback
        )
        return Fixture(viewModel: viewModel, feedback: feedback, input: input, output: output)
    }

    private func makeImages(_ count: Int, in directory: URL) throws -> [URL] {
        try (0..<count).map { index in
            let image = try TestImages.makeImage(width: 16, height: 16, red: CGFloat(index % 10) / 10, green: 0.5, blue: 0.5)
            return try TestImages.write(image, to: directory.appendingPathComponent("photo\(index).png"), type: .png)
        }
    }

    /// Polls until `condition` holds; records an issue instead of hanging forever.
    private func waitUntil(_ description: String, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(10)
        while !condition() {
            guard Date() < deadline else {
                Issue.record("Timed out waiting for \(description)")
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    @Test func compressWritesOutputsAndRecordsDestination() async throws {
        let fixture = try makeFixture()
        let viewModel = fixture.viewModel
        await viewModel.addFiles(urls: try makeImages(2, in: fixture.input))
        #expect(viewModel.batchJob.items.count == 2)

        await viewModel.startCompression()

        for item in viewModel.batchJob.items {
            #expect(item.status == .completed)
            let destination = try #require(item.destinationURL)
            #expect(FileManager.default.fileExists(atPath: destination.path))
            #expect(destination.deletingLastPathComponent().standardizedFileURL == fixture.output.standardizedFileURL)
        }
        let run = try #require(viewModel.batchJob.runHistory.last)
        #expect(run.completedCount == 2)
        #expect(run.failedCount == 0)
        #expect(run.skippedCount == 0)
        #expect(run.isComplete)
        #expect(fixture.feedback.finishedCounts == [2])
        #expect(!viewModel.batchJob.isProcessing)
    }

    @Test func retryFailedStartsNewRunAndClearsFailures() async throws {
        let failure = FailureSwitch()
        failure.isOn = true
        let fixture = try makeFixture(compressor: FakeCompressor { _ in failure.isOn ? .failure : .success })
        let viewModel = fixture.viewModel
        await viewModel.addFiles(urls: try makeImages(2, in: fixture.input))

        await viewModel.startCompression()
        #expect(viewModel.hasFailedItems)

        failure.isOn = false
        await viewModel.retryFailed()

        #expect(!viewModel.hasFailedItems)
        #expect(viewModel.batchJob.runHistory.count == 2)
        #expect(viewModel.batchJob.runHistory.first?.failedCount == 2)
        #expect(viewModel.batchJob.runHistory.last?.completedCount == 2)
        #expect(viewModel.batchJob.runHistory.last?.itemCount == 2)
    }

    @Test func conflictSkipIsCountedInRun() async throws {
        let fixture = try makeFixture()
        let viewModel = fixture.viewModel
        await viewModel.addFiles(urls: try makeImages(2, in: fixture.input))
        let existing = fixture.output.appendingPathComponent("photo0.jpg")
        try Data("OLD".utf8).write(to: existing)

        let compression = Task { await viewModel.startCompression() }
        try await waitUntil("conflict dialog") { viewModel.pendingOverwriteFile != nil }
        #expect(viewModel.pendingOverwriteFile == "photo0.jpg")
        viewModel.resolveConflict(.skip)
        await compression.value

        let run = try #require(viewModel.batchJob.runHistory.last)
        #expect(run.skippedCount == 1)
        #expect(run.completedCount == 1)
        #expect(viewModel.batchJob.items.allSatisfy { $0.batchRunId == run.id })
        #expect(try Data(contentsOf: existing) == Data("OLD".utf8))
    }

    @Test func missingOutputFolderShowsError() async throws {
        let fixture = try makeFixture()
        let viewModel = fixture.viewModel
        await viewModel.addFiles(urls: try makeImages(1, in: fixture.input))
        try FileManager.default.removeItem(at: fixture.output)

        await viewModel.startCompression()

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.batchJob.runHistory.isEmpty)
        #expect(viewModel.batchJob.items.allSatisfy { $0.status == .queued })
    }

    @Test func outputFolderMayBeInsideTheImagesFolderButNotContainIt() async throws {
        let fixture = try makeFixture()
        let viewModel = fixture.viewModel
        await viewModel.addFiles(urls: try makeImages(1, in: fixture.input))

        // The folder that holds the images' folder is refused, and the message states the rule
        viewModel.settings.chooseOutputDirectory(fixture.input.deletingLastPathComponent())
        await viewModel.startCompression()
        #expect(viewModel.errorMessage == CompressionError.inputOutputOverlap.errorDescription)
        #expect(viewModel.batchJob.runHistory.isEmpty)

        // A new folder inside the images' folder is fine
        viewModel.errorMessage = nil
        let inside = fixture.input.appendingPathComponent("compressed", isDirectory: true)
        try FileManager.default.createDirectory(at: inside, withIntermediateDirectories: true)
        viewModel.settings.chooseOutputDirectory(inside)
        await viewModel.startCompression()
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.batchJob.runHistory.last?.completedCount == 1)
    }

    @Test func missingSourceFailsOnlyThatItem() async throws {
        let fixture = try makeFixture()
        let viewModel = fixture.viewModel
        let sources = try makeImages(3, in: fixture.input)
        await viewModel.addFiles(urls: sources)
        try FileManager.default.removeItem(at: sources[1])

        await viewModel.startCompression()

        let run = try #require(viewModel.batchJob.runHistory.last)
        #expect(run.completedCount == 2)
        #expect(run.failedCount == 1)
        #expect(run.processedCount == 3)
        #expect(!viewModel.batchJob.items.contains { $0.status == .processing })
    }

    @Test func cancelLeavesConsistentCounts() async throws {
        let fixture = try makeFixture(compressor: FakeCompressor(delay: 0.05))
        let viewModel = fixture.viewModel
        // More images than cores, so some are still waiting when Cancel arrives
        let count = max(30, ProcessInfo.processInfo.activeProcessorCount * 3)
        await viewModel.addFiles(urls: try makeImages(count, in: fixture.input))

        let compression = Task { await viewModel.startCompression() }
        try await waitUntil("first completion") { (viewModel.batchJob.activeRun?.completedCount ?? 0) > 0 }
        viewModel.cancelCompression()
        #expect(viewModel.isCancelling)
        await compression.value

        let run = try #require(viewModel.batchJob.runHistory.last)
        #expect(run.processedCount == count)
        #expect(run.failedCount > 0)
        #expect(!viewModel.batchJob.items.contains { $0.status == .processing })
        #expect(!viewModel.isCancelling)
        #expect(!viewModel.batchJob.isProcessing)
    }

    @Test func cancelWhileAConflictPromptWaitsStopsTheRun() async throws {
        let fixture = try makeFixture()
        let viewModel = fixture.viewModel
        await viewModel.addFiles(urls: try makeImages(5, in: fixture.input))
        let existing = fixture.output.appendingPathComponent("photo0.jpg")
        try Data("OLD".utf8).write(to: existing)

        let compression = Task { await viewModel.startCompression() }
        try await waitUntil("conflict prompt") { viewModel.pendingOverwriteFile != nil }
        viewModel.cancelCompression()
        try await waitUntil("run to stop") { !viewModel.batchJob.isProcessing }
        #expect(viewModel.pendingOverwriteFile == nil, "Cancel closes the prompt")
        viewModel.resolveConflict(.skip)  // Lets a run that ignored Cancel finish
        await compression.value

        let run = try #require(viewModel.batchJob.runHistory.last)
        #expect(run.processedCount == 5)
        #expect(run.completedCount == 0, "Nothing is written after Cancel")
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.output.path) == ["photo0.jpg"])
        #expect(try Data(contentsOf: existing) == Data("OLD".utf8))
        #expect(fixture.feedback.finishedCounts.isEmpty)
    }

    @Test func noConflictPromptAppearsAfterCancel() async throws {
        let fixture = try makeFixture(compressor: FakeCompressor())
        let viewModel = fixture.viewModel
        try Data("OLD".utf8).write(to: fixture.output.appendingPathComponent("photo0.jpg"))
        // Sources need not exist to plan destinations; many images keep the existence check busy
        viewModel.batchJob.addItems((0..<80_000).map {
            ImageItem(sourceURL: fixture.input.appendingPathComponent("photo\($0).png"), originalSize: 10,
                      originalDimensions: CGSize(width: 10, height: 10), detectedFormat: .png)
        })

        let compression = Task { await viewModel.startCompression() }
        // Planning is done once the last image knows its output format; existing files are checked now
        try await waitUntil("existence check") { viewModel.batchJob.items.last?.outputFormatUsed != nil }
        viewModel.cancelCompression()
        try await waitUntil("run to stop") { !viewModel.batchJob.isProcessing || viewModel.pendingOverwriteFile != nil }
        #expect(viewModel.pendingOverwriteFile == nil, "No conflict prompt after Cancel")
        viewModel.cancelCompression()  // What Stop Compressing in the prompt calls
        #expect(viewModel.pendingOverwriteFile == nil, "Stop Compressing closes the prompt while cancelling")
        viewModel.resolveConflict(.skip)  // Lets a run that prompted anyway finish
        await compression.value

        let run = try #require(viewModel.batchJob.runHistory.last)
        #expect(run.processedCount == 80_000)
        #expect(run.completedCount == 0)
    }

    @Test func imagesInANewRunShowNoOldResultsWhilePreparing() async throws {
        let fixture = try makeFixture()
        let viewModel = fixture.viewModel
        await viewModel.addFiles(urls: try makeImages(3, in: fixture.input))
        await viewModel.startCompression()

        // The outputs exist now, so the second run asks about the first one
        let compression = Task { await viewModel.startCompression() }
        try await waitUntil("conflict prompt") { viewModel.pendingOverwriteFile != nil }
        #expect(viewModel.batchJob.items.allSatisfy { $0.status == .queued && $0.compressedSize == nil },
                "Last run's checkmarks and sizes do not count for the new run")
        viewModel.cancelCompression()
        await compression.value
    }

    @Test func quitWaitGivesUpWhenAWriteHangs() async throws {
        let compressor = FakeCompressor(delay: 2)
        let fixture = try makeFixture(compressor: compressor)
        let viewModel = fixture.viewModel
        await viewModel.addFiles(urls: try makeImages(1, in: fixture.input))

        let compression = Task { await viewModel.startCompression() }
        try await waitUntil("image to be written") { compressor.probe.peak == 1 }
        let start = ContinuousClock.now
        await viewModel.cancelCompressionAndWait(timeout: .milliseconds(200))
        #expect(ContinuousClock.now - start < .seconds(1), "A write that hangs (e.g. on a lost network share) must not block quitting")

        await compression.value
    }

    @Test func readOnlyOutputFolderShowsOneErrorInsteadOfFailingEveryImage() async throws {
        let fixture = try makeFixture()
        let viewModel = fixture.viewModel
        await viewModel.addFiles(urls: try makeImages(3, in: fixture.input))
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: fixture.output.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fixture.output.path) }

        await viewModel.startCompression()

        #expect(viewModel.errorMessage?.contains("\"out\"") == true, "The message names the folder")
        #expect(viewModel.batchJob.runHistory.isEmpty)
        #expect(viewModel.batchJob.items.allSatisfy { $0.status == .queued })
    }

    @Test func sizesFollowASourceReplacedAfterItWasAdded() async throws {
        let fixture = try makeFixture()
        let viewModel = fixture.viewModel
        let source = try #require(try makeImages(1, in: fixture.input).first)
        await viewModel.addFiles(urls: [source])
        // Edited and saved again under the same name
        let bigger = try TestImages.makeImage(width: 256, height: 256, red: 0.3, green: 0.6, blue: 0.9)
        try TestImages.write(bigger, to: source, type: .png)
        let newSize = try TestImages.fileSize(of: source)

        await viewModel.startCompression()

        let item = try #require(viewModel.batchJob.items.first)
        #expect(item.originalSize == newSize)
        #expect(viewModel.batchJob.totalOriginalSize == newSize)
        #expect(viewModel.batchJob.runHistory.last?.completedOriginalSize == newSize)
    }

    @Test func addFilesImportsManyFilesAndReportsEmptySelections() async throws {
        let fixture = try makeFixture()
        let viewModel = fixture.viewModel
        let folder = fixture.input.appendingPathComponent("shoot", isDirectory: true)
        for index in 0..<4 {
            let sub = folder.appendingPathComponent("day\(index)", isDirectory: true)
            try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
            _ = try makeImages(50, in: sub)
        }

        await viewModel.addFiles(urls: [folder])
        #expect(viewModel.batchJob.items.count == 200)
        #expect(viewModel.batchJob.items.allSatisfy { $0.relativePath?.hasPrefix("day") == true })
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isImporting)

        let text = fixture.input.appendingPathComponent("notes.txt")
        try Data("not an image".utf8).write(to: text)
        await viewModel.addFiles(urls: [text])
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.batchJob.items.count == 200)

        viewModel.errorMessage = nil
        await viewModel.addFiles(urls: [folder])
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.batchJob.items.count == 200)
    }

    @Test func pixelLayoutIsKnownFromImportToCompression() async throws {
        let fixture = try makeFixture()
        let viewModel = fixture.viewModel
        let image = try TestImages.makeImage(width: 8, height: 8, red: 1, green: 0, blue: 0, alpha: 0.5)
        let logo = try TestImages.write(image, to: fixture.input.appendingPathComponent("logo.png"), type: .png)

        await viewModel.addFiles(urls: [logo])

        let item = try #require(viewModel.batchJob.items.first)
        #expect(item.pixelLayout.hasAlpha)
        #expect(item.toTask(requestedFormat: .webp).pixelLayout.hasAlpha, "WebP with alpha takes about twice the memory")
    }

    /// Folder scans pick only the listed formats; a file chosen directly is accepted whenever
    /// ImageIO can read it, and "Original" then falls back to JPEG
    @Test func otherImageFilesChosenDirectlyAreSavedAsJPEG() async throws {
        let fixture = try makeFixture()
        let viewModel = fixture.viewModel
        viewModel.settings.outputFormat = .original
        let image = try TestImages.makeImage(width: 16, height: 16, red: 0.4, green: 0.4, blue: 0.8)
        let psd = try TestImages.write(image, to: fixture.input.appendingPathComponent("layers.psd"), type: try #require(UTType("com.adobe.photoshop-image")))

        await viewModel.addFiles(urls: [psd])
        await viewModel.startCompression()

        let item = try #require(viewModel.batchJob.items.first)
        #expect(item.status == .completed)
        #expect(item.destinationURL?.pathExtension == "jpg")
    }

    @Test func addFilesListsImagesInNameOrder() async throws {
        let fixture = try makeFixture()
        let viewModel = fixture.viewModel
        let folder = fixture.input.appendingPathComponent("album", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        _ = try makeImages(12, in: folder)
        let loose = try makeImages(3, in: fixture.input)

        // The open panel and Finder hand over selections in arbitrary order
        await viewModel.addFiles(urls: [loose[2], folder, loose[0], loose[1]])

        let names = viewModel.batchJob.items.map(\.fileName)
        #expect(names == (0..<12).map { "photo\($0).png" } + ["photo0.png", "photo1.png", "photo2.png"])
    }

    @Test func renameKeepsUserNumberSuffix() async throws {
        let fixture = try makeFixture()
        let viewModel = fixture.viewModel
        let image = try TestImages.makeImage(width: 16, height: 16, red: 0.2, green: 0.4, blue: 0.6)
        let source = try TestImages.write(image, to: fixture.input.appendingPathComponent("Vacation-12.png"), type: .png)
        await viewModel.addFiles(urls: [source])
        let existing = fixture.output.appendingPathComponent("Vacation-12.jpg")
        try Data("OLD".utf8).write(to: existing)

        let compression = Task { await viewModel.startCompression() }
        try await waitUntil("conflict dialog") { viewModel.pendingOverwriteFile != nil }
        viewModel.resolveConflict(.rename)
        await compression.value

        #expect(viewModel.batchJob.items.first?.destinationURL?.lastPathComponent == "Vacation-12-1.jpg")
        #expect(try Data(contentsOf: existing) == Data("OLD".utf8))
    }

    @Test func caseVariantNamesDoNotOverwriteEachOther() async throws {
        let fixture = try makeFixture()
        let viewModel = fixture.viewModel
        let first = fixture.input.appendingPathComponent("a", isDirectory: true)
        let second = fixture.input.appendingPathComponent("b", isDirectory: true)
        try FileManager.default.createDirectory(at: first, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: second, withIntermediateDirectories: true)
        let image = try TestImages.makeImage(width: 16, height: 16, red: 0.9, green: 0.4, blue: 0.1)
        let upper = try TestImages.write(image, to: first.appendingPathComponent("Photo.png"), type: .png)
        let lower = try TestImages.write(image, to: second.appendingPathComponent("photo.png"), type: .png)
        await viewModel.addFiles(urls: [upper, lower])

        await viewModel.startCompression()

        let destinations = viewModel.batchJob.items.compactMap(\.destinationURL)
        #expect(destinations.count == 2)
        #expect(Set(destinations.map { $0.lastPathComponent.lowercased() }).count == 2)
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.output.path).count == 2)
    }

    @Test func removeItemsUpdatesTotalSize() async throws {
        let fixture = try makeFixture()
        let viewModel = fixture.viewModel
        await viewModel.addFiles(urls: try makeImages(3, in: fixture.input))
        let removed = try #require(viewModel.batchJob.items.first)
        let expected = viewModel.batchJob.totalOriginalSize - removed.originalSize

        viewModel.removeItems(ids: [removed.id], undoManager: nil)

        #expect(viewModel.batchJob.items.count == 2)
        #expect(viewModel.batchJob.totalOriginalSize == expected)
    }

    // MARK: Undo and run integrity

    /// An undo manager that groups explicitly, as there is no event loop in tests.
    private func makeUndoManager() -> UndoManager {
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        return undoManager
    }

    private func perform(_ undoManager: UndoManager, _ action: () -> Void) {
        undoManager.beginUndoGrouping()
        action()
        undoManager.endUndoGrouping()
    }

    @Test func removeCanBeUndoneInOriginalOrderAndRedone() async throws {
        let fixture = try makeFixture()
        let viewModel = fixture.viewModel
        await viewModel.addFiles(urls: try makeImages(4, in: fixture.input))
        let names = viewModel.batchJob.items.map(\.fileName)
        let size = viewModel.batchJob.totalOriginalSize
        let undoManager = makeUndoManager()

        perform(undoManager) {
            viewModel.removeItems(ids: Set(viewModel.batchJob.items[1...2].map(\.id)), undoManager: undoManager)
        }
        #expect(viewModel.batchJob.items.map(\.fileName) == [names[0], names[3]])

        undoManager.undo()
        #expect(viewModel.batchJob.items.map(\.fileName) == names)
        #expect(viewModel.batchJob.totalOriginalSize == size)

        undoManager.redo()
        #expect(viewModel.batchJob.items.map(\.fileName) == [names[0], names[3]])
    }

    @Test func clearAllUndoRestoresItemsAndRunHistory() async throws {
        let fixture = try makeFixture()
        let viewModel = fixture.viewModel
        await viewModel.addFiles(urls: try makeImages(2, in: fixture.input))
        await viewModel.startCompression()
        let undoManager = makeUndoManager()

        perform(undoManager) { viewModel.clearAll(undoManager: undoManager) }
        #expect(viewModel.batchJob.items.isEmpty)
        #expect(viewModel.batchJob.runHistory.isEmpty)

        undoManager.undo()
        let run = try #require(viewModel.batchJob.runHistory.first)
        #expect(viewModel.batchJob.items.count == 2)
        #expect(viewModel.batchJob.runHistory.count == 1)
        #expect(viewModel.batchJob.items.allSatisfy { $0.batchRunId == run.id && $0.status == .completed })
    }

    @Test func runIdsAreNeverReused() async throws {
        let fixture = try makeFixture()
        let viewModel = fixture.viewModel
        let sources = try makeImages(1, in: fixture.input)
        await viewModel.addFiles(urls: sources)
        await viewModel.startCompression()
        viewModel.clearAll(undoManager: nil)

        // Same image again into an empty output folder, so no conflict prompt appears
        try FileManager.default.removeItem(at: fixture.output)
        try FileManager.default.createDirectory(at: fixture.output, withIntermediateDirectories: true)
        await viewModel.addFiles(urls: sources)
        await viewModel.startCompression()

        #expect(viewModel.batchJob.runHistory.map(\.id) == [2], "A run after Clear All gets a new ID")
    }

    @Test func removalIsIgnoredWhileCompressing() async throws {
        let fixture = try makeFixture(compressor: FakeCompressor(delay: 0.05))
        let viewModel = fixture.viewModel
        await viewModel.addFiles(urls: try makeImages(10, in: fixture.input))

        let compression = Task { await viewModel.startCompression() }
        try await waitUntil("run to start") { viewModel.batchJob.isProcessing }
        viewModel.removeItems(ids: Set(viewModel.batchJob.items.map(\.id)), undoManager: nil)
        viewModel.clearAll(undoManager: nil)
        #expect(viewModel.batchJob.items.count == 10)

        await compression.value
        #expect(viewModel.batchJob.runHistory.last?.completedCount == 10)
    }

    @Test func undoAndRedoWorkWhileCompressingWithoutTouchingTheRun() async throws {
        let fixture = try makeFixture(compressor: FakeCompressor(delay: 0.05))
        let viewModel = fixture.viewModel
        let count = max(40, ProcessInfo.processInfo.activeProcessorCount * 4)
        await viewModel.addFiles(urls: try makeImages(count + 2, in: fixture.input))
        let undoManager = makeUndoManager()
        let removed = Set(viewModel.batchJob.items.prefix(2).map(\.id))
        perform(undoManager) { viewModel.removeItems(ids: removed, undoManager: undoManager) }

        let compression = Task { await viewModel.startCompression() }
        try await waitUntil("first completion") { (viewModel.batchJob.activeRun?.completedCount ?? 0) > 0 }
        undoManager.undo()
        #expect(viewModel.batchJob.items.count == count + 2, "Undo puts the removed images back, outside the run")
        undoManager.redo()
        #expect(viewModel.batchJob.items.count == count, "Redo takes them out again")
        #expect(viewModel.batchJob.isProcessing)
        await compression.value

        #expect(viewModel.batchJob.runHistory.last?.completedCount == count)
        undoManager.undo()
        #expect(viewModel.batchJob.items.count == count + 2, "The removal can still be undone after the run")
    }

    @Test func redoNeverRemovesImagesTheRunIsWriting() async throws {
        let fixture = try makeFixture(compressor: FakeCompressor(delay: 0.05))
        let viewModel = fixture.viewModel
        let count = max(40, ProcessInfo.processInfo.activeProcessorCount * 4)
        await viewModel.addFiles(urls: try makeImages(count, in: fixture.input))
        let undoManager = makeUndoManager()
        perform(undoManager) { viewModel.removeItems(ids: Set(viewModel.batchJob.items.prefix(2).map(\.id)), undoManager: undoManager) }
        undoManager.undo()

        let compression = Task { await viewModel.startCompression() }
        try await waitUntil("first completion") { (viewModel.batchJob.activeRun?.completedCount ?? 0) > 0 }
        undoManager.redo()
        #expect(viewModel.batchJob.items.count == count)
        await compression.value

        #expect(viewModel.batchJob.runHistory.last?.completedCount == count)
    }

    @Test func sameOutputNameInOneRunIsRenamedWithoutAsking() async throws {
        let fixture = try makeFixture()
        let viewModel = fixture.viewModel
        let image = try TestImages.makeImage(width: 16, height: 16, red: 0.1, green: 0.6, blue: 0.3)
        var sources: [URL] = []
        for folder in ["x", "y"] {
            let dir = fixture.input.appendingPathComponent(folder, isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            sources.append(try TestImages.write(image, to: dir.appendingPathComponent("a.png"), type: .png))
        }
        await viewModel.addFiles(urls: sources)
        let existing = fixture.output.appendingPathComponent("a.jpg")
        try Data("OLD".utf8).write(to: existing)

        // Answer every prompt with Overwrite, counting them
        var prompts = 0
        let compression = Task { await viewModel.startCompression() }
        while viewModel.batchJob.runHistory.last?.isComplete != true {
            if viewModel.pendingOverwriteFile != nil {
                prompts += 1
                viewModel.resolveConflict(.overwrite)
            }
            try await Task.sleep(for: .milliseconds(5))
        }
        await compression.value

        #expect(prompts == 1, "Only the file that existed before the run is asked about")
        let outputs = try FileManager.default.contentsOfDirectory(atPath: fixture.output.path).sorted()
        #expect(outputs == ["a-1.jpg", "a.jpg"])
        #expect(try Data(contentsOf: existing) != Data("OLD".utf8))
    }

    @Test func repeatedRunsWithOverwriteAllReuseNumberedNames() async throws {
        let fixture = try makeFixture()
        let viewModel = fixture.viewModel
        let image = try TestImages.makeImage(width: 16, height: 16, red: 0.1, green: 0.6, blue: 0.3)
        var sources: [URL] = []
        for folder in ["x", "y"] {
            let dir = fixture.input.appendingPathComponent(folder, isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            sources.append(try TestImages.write(image, to: dir.appendingPathComponent("a.png"), type: .png))
        }
        await viewModel.addFiles(urls: sources)
        await viewModel.startCompression()
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.output.path).sorted() == ["a-1.jpg", "a.jpg"])

        let compression = Task { await viewModel.startCompression() }
        try await waitUntil("conflict prompt") { viewModel.pendingOverwriteFile != nil }
        viewModel.resolveConflict(.overwriteAll)
        await compression.value

        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.output.path).sorted() == ["a-1.jpg", "a.jpg"],
                "Overwrite All replaces last run's numbered file instead of adding a-2.jpg")
        #expect(viewModel.batchJob.runHistory.last?.completedCount == 2)
    }

    @Test func renamingANumberedNamePicksTheNextNumber() async throws {
        let fixture = try makeFixture()
        let viewModel = fixture.viewModel
        let image = try TestImages.makeImage(width: 16, height: 16, red: 0.1, green: 0.6, blue: 0.3)
        var sources: [URL] = []
        for folder in ["x", "y"] {
            let dir = fixture.input.appendingPathComponent(folder, isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            sources.append(try TestImages.write(image, to: dir.appendingPathComponent("a.png"), type: .png))
        }
        await viewModel.addFiles(urls: sources)
        await viewModel.startCompression()

        var answers: [MainViewModel.ConflictChoice] = [.overwrite, .rename]
        var asked: [String] = []
        let compression = Task { await viewModel.startCompression() }
        while viewModel.batchJob.runHistory.count < 2 || viewModel.batchJob.isProcessing {
            if let file = viewModel.pendingOverwriteFile, !answers.isEmpty {
                asked.append(file)
                viewModel.resolveConflict(answers.removeFirst())
            }
            try await Task.sleep(for: .milliseconds(5))
        }
        await compression.value

        #expect(asked == ["a.jpg", "a-1.jpg"])
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.output.path).sorted() == ["a-1.jpg", "a-2.jpg", "a.jpg"],
                "Rename numbers the original name again (a-2.jpg), not the numbered one (a-1-1.jpg)")
    }

    @Test func transparencyNoteFollowsTheFormatEachImageIsSavedIn() async throws {
        let fixture = try makeFixture()
        let viewModel = fixture.viewModel
        let image = try TestImages.makeImage(width: 8, height: 8, red: 1, green: 0, blue: 0, alpha: 0.5)
        let cutout = try TestImages.write(image, to: fixture.input.appendingPathComponent("cutout.heic"), type: .heic)
        await viewModel.addFiles(urls: [cutout])
        try #require(viewModel.batchJob.items.first?.pixelLayout.hasAlpha == true)

        viewModel.settings.outputFormat = .png
        #expect(!viewModel.flattensTransparentImages)
        viewModel.settings.outputFormat = .original  // Stays HEIC, which is saved without transparency
        #expect(viewModel.flattensTransparentImages)
        viewModel.settings.outputFormat = .jpeg
        #expect(viewModel.flattensTransparentImages)
    }

    @Test func staleTempFilesInTheOutputFolderAreRemovedBeforeARun() async throws {
        let fixture = try makeFixture()
        let viewModel = fixture.viewModel
        await viewModel.addFiles(urls: try makeImages(1, in: fixture.input))
        let leftover = fixture.output.appendingPathComponent(".pixeldiet-DEADBEEF.jpg")
        try Data("partial".utf8).write(to: leftover)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-7200)], ofItemAtPath: leftover.path)

        await viewModel.startCompression()

        #expect(!FileManager.default.fileExists(atPath: leftover.path))
        #expect(viewModel.batchJob.runHistory.last?.completedCount == 1)
    }

    @Test func cancelledRunDoesNotAnnounceCompletion() async throws {
        let fixture = try makeFixture(compressor: FakeCompressor(delay: 0.05))
        let viewModel = fixture.viewModel
        await viewModel.addFiles(urls: try makeImages(20, in: fixture.input))

        let compression = Task { await viewModel.startCompression() }
        try await waitUntil("first completion") { (viewModel.batchJob.activeRun?.completedCount ?? 0) > 0 }
        viewModel.cancelCompression()
        await compression.value

        #expect(fixture.feedback.finishedCounts.isEmpty, "No completion sound or notification for a cancelled run")
    }

    @Test func cancelCompressionAndWaitReturnsOnceInFlightImagesFinish() async throws {
        let fixture = try makeFixture(compressor: FakeCompressor(delay: 0.05))
        let viewModel = fixture.viewModel
        await viewModel.addFiles(urls: try makeImages(20, in: fixture.input))

        let compression = Task { await viewModel.startCompression() }
        try await waitUntil("first completion") { (viewModel.batchJob.activeRun?.completedCount ?? 0) > 0 }
        await viewModel.cancelCompressionAndWait()

        #expect(!viewModel.batchJob.items.contains { $0.status == .processing })
        await compression.value
    }

    /// Names of the power assertions this process holds (what `pmset -g assertions` lists).
    private func powerAssertionNames() -> [String] {
        var byProcess: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&byProcess) == kIOReturnSuccess,
              let all = byProcess?.takeRetainedValue() as? [Int: [[String: Any]]] else { return [] }
        return (all[Int(getpid())] ?? []).compactMap { $0[kIOPMAssertionNameKey] as? String }
    }

    @Test func compressingKeepsTheMacAwakeUntilTheRunEnds() async throws {
        let fixture = try makeFixture(compressor: FakeCompressor(delay: 0.05))
        let viewModel = fixture.viewModel
        await viewModel.addFiles(urls: try makeImages(10, in: fixture.input))

        let compression = Task { await viewModel.startCompression() }
        try await waitUntil("first completion") { (viewModel.batchJob.activeRun?.completedCount ?? 0) > 0 }
        #expect(powerAssertionNames().contains(MainViewModel.compressionActivityReason),
                "No App Nap, idle sleep or automatic termination in the middle of a batch")

        await compression.value
        #expect(!powerAssertionNames().contains(MainViewModel.compressionActivityReason))
    }

    @Test func waitingForAConflictAnswerLetsTheMacSleep() async throws {
        let fixture = try makeFixture()
        let viewModel = fixture.viewModel
        await viewModel.addFiles(urls: try makeImages(1, in: fixture.input))
        try Data("OLD".utf8).write(to: fixture.output.appendingPathComponent("photo0.jpg"))

        let compression = Task { await viewModel.startCompression() }
        try await waitUntil("conflict prompt") { viewModel.pendingOverwriteFile != nil }
        #expect(!powerAssertionNames().contains(MainViewModel.compressionActivityReason),
                "Nothing is being compressed while the dialog waits for an answer")

        viewModel.resolveConflict(.skip)
        await compression.value
    }

    // MARK: Importing state

    @Test func overlappingImportsStayImportingUntilAllFinish() async throws {
        let fixture = try makeFixture(analyzer: SlowAnalyzer(delay: 0.5))
        let viewModel = fixture.viewModel
        let image = try TestImages.makeImage(width: 8, height: 8, red: 0.5, green: 0.5, blue: 0.5)
        let slow = try TestImages.write(image, to: fixture.input.appendingPathComponent("slow.png"), type: .png)
        let fast = try TestImages.write(image, to: fixture.input.appendingPathComponent("fast.png"), type: .png)

        let slowImport = Task { await viewModel.addFiles(urls: [slow]) }
        try await waitUntil("slow import to start") { viewModel.isImporting }
        await viewModel.addFiles(urls: [fast])
        #expect(viewModel.isImporting, "The slow import is still running")

        await slowImport.value
        #expect(!viewModel.isImporting)
        #expect(viewModel.batchJob.items.count == 2)
    }

    @Test func droppedFilesShowImportingWhileTheyLoad() async throws {
        let fixture = try makeFixture()
        let viewModel = fixture.viewModel
        let urls = try makeImages(2, in: fixture.input)

        viewModel.addDroppedItems(urls.map { NSItemProvider(object: $0 as NSURL) })
        #expect(viewModel.isImporting)

        try await waitUntil("dropped images") { viewModel.batchJob.items.count == 2 }
        try await waitUntil("import to finish") { !viewModel.isImporting }
    }
}
