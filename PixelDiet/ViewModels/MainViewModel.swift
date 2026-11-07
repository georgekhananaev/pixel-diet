import AppKit

// @MainActor is implicit under Swift 6.2 default actor isolation (Round 3 Fix)
@Observable
class MainViewModel {
    let batchJob = BatchJob()
    let settings: CompressionSettings
    let batchProcessor: BatchProcessor
    let thumbnailService = ThumbnailService()
    let analyzer: any ImageAnalyzing
    private let feedback: any BatchFeedback

    private var processingTask: Task<Void, Never>?
    var errorMessage: String?
    /// True while dropped or selected files are being loaded, scanned and analyzed
    var isImporting: Bool { activeImports > 0 }
    /// Imports in progress; several can overlap (e.g. two quick drops)
    private var activeImports = 0
    /// True after Cancel until in-flight images finish and the run settles
    private(set) var isCancelling = false

    var hasFailedItems: Bool { batchJob.items.contains(where: \.hasFailed) }

    /// Whether a queued image has transparency that its output format cannot keep (it becomes white)
    var flattensTransparentImages: Bool {
        batchJob.items.contains { item in
            item.pixelLayout.hasAlpha && !ImageFormat.resolvedOutput(requested: settings.outputFormat, source: item.effectiveFormat).supportsAlpha
        }
    }

    /// How to handle file conflicts for the rest of the batch
    enum ConflictPolicy {
        case ask           // Show dialog for each conflict
        case overwriteAll  // Overwrite all remaining conflicts
        case renameAll     // Auto-rename all remaining conflicts
        case skipAll       // Skip all remaining conflicts
    }

    /// User's single-file choice from the conflict dialog
    enum ConflictChoice {
        case overwrite
        case overwriteAll
        case rename
        case renameAll
        case skip
        case skipAll
    }

    var conflictPolicy: ConflictPolicy = .ask

    /// Names the power assertion held while compressing (shown by `pmset -g assertions`)
    static let compressionActivityReason = "Compressing images"

    /// Pending overwrite confirmation - set when a conflict is found while preparing a run
    var pendingOverwriteFile: String?
    var pendingOverwriteContinuation: CheckedContinuation<ConflictChoice, Never>?

    init(
        settings: CompressionSettings = CompressionSettings(),
        batchProcessor: BatchProcessor = BatchProcessor(),
        analyzer: any ImageAnalyzing = ImageAnalyzer(),
        feedback: any BatchFeedback = SystemBatchFeedback()
    ) {
        self.settings = settings
        self.batchProcessor = batchProcessor
        self.analyzer = analyzer
        self.feedback = feedback
    }

    /// Single entry point for resolving a conflict - guarantees continuation is resumed exactly once
    func resolveConflict(_ choice: ConflictChoice) {
        guard let continuation = pendingOverwriteContinuation else { return }
        pendingOverwriteContinuation = nil
        pendingOverwriteFile = nil
        continuation.resume(returning: choice)
    }

    // MARK: - Queue Management

    func addFiles(urls: [URL]) async {
        activeImports += 1
        defer { activeImports -= 1 }
        guard !urls.isEmpty else { return }

        // Reset conflict policy when new files are added
        conflictPolicy = .ask

        let analyzer = analyzer
        let discovered = await Task.detached(priority: .userInitiated) {
            await Self.discoverImages(in: urls, analyzer: analyzer)
        }.value

        guard !discovered.isEmpty else {
            errorMessage = String(localized: "No supported images found. PixelDiet accepts JPEG, PNG, WebP, HEIC, HEIF, AVIF, TIFF, BMP, GIF and PPM files.")
            return
        }

        let items = discovered.map { image in
            ImageItem(
                sourceURL: image.url,
                originalSize: image.info.fileSize,
                originalDimensions: image.info.dimensions,
                frameCount: image.info.frameCount,
                hasGPSData: image.info.hasGPSData,
                pixelLayout: image.info.pixelLayout,
                relativePath: image.inputRoot.flatMap { Self.relativePath(of: image.url, under: $0) },
                colorSpaceName: image.info.colorSpaceName,
                detectedFormat: image.info.detectedFormat
            )
        }

        loadThumbnails(for: batchJob.addItems(items))
    }

    /// Accepts file URLs dragged from Finder (files or folders).
    func addDroppedItems(_ providers: [NSItemProvider]) {
        let fileProviders = providers.filter { $0.canLoadObject(ofClass: URL.self) }
        guard !fileProviders.isEmpty else { return }
        // Counted from the drop, so progress shows while Finder hands over the URLs
        activeImports += 1
        Task {
            defer { activeImports -= 1 }
            var urls: [URL] = []
            for provider in fileProviders {
                if let url = await Self.loadURL(from: provider) {
                    urls.append(url)
                }
            }
            await addFiles(urls: urls)
        }
    }

    private func loadThumbnails(for items: [ImageItem]) {
        Task {
            await withTaskGroup(of: Void.self) { group in
                var launched = 0
                for item in items {
                    if launched >= 8 { await group.next(); launched -= 1 }
                    launched += 1
                    group.addTask { [thumbnailService] in
                        if let cgImage = await thumbnailService.thumbnail(for: item.sourceURL) {
                            await MainActor.run { item.thumbnail = NSImage(cgImage: cgImage, size: .zero) }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Queue Operations with Undo

    /// Removes images from the queue (not while compressing). Undo puts them back in place.
    func removeItems(ids: Set<UUID>, undoManager: UndoManager?) {
        guard !batchJob.isProcessing, !ids.isEmpty else { return }
        registerUndo(of: batchJob.removeItems(withIDs: ids), actionName: String(localized: "Remove"), undoManager: undoManager)
    }

    /// Empties the queue and the run history (not while compressing). Undo restores both.
    func clearAll(undoManager: UndoManager?) {
        guard !batchJob.isProcessing else { return }
        registerUndo(of: batchJob.clear(), actionName: String(localized: "Clear All"), undoManager: undoManager)
    }

    /// Undo puts back what `removal` took out; Redo takes it out again. Both also work while
    /// compressing: the images involved are not part of the run, and Redo leaves the run's alone.
    private func registerUndo(of removal: BatchJob.Removal, actionName: String, undoManager: UndoManager?) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { viewModel in
            MainActor.assumeIsolated {
                viewModel.batchJob.restore(removal)
                undoManager.registerUndo(withTarget: viewModel) { viewModel in
                    MainActor.assumeIsolated {
                        viewModel.registerUndo(of: viewModel.batchJob.reapply(removal), actionName: actionName, undoManager: undoManager)
                    }
                }
                undoManager.setActionName(actionName)
            }
        }
        undoManager.setActionName(actionName)
    }

    // MARK: - Compression

    /// Compresses every queued item; returns when the run has finished or been cancelled.
    func startCompression() async {
        await compress(batchJob.items)
    }

    /// Re-runs only the items whose last attempt failed, as a new run.
    func retryFailed() async {
        await compress(batchJob.items.filter(\.hasFailed))
    }

    func cancelCompression() {
        guard let processingTask else { return }
        if !isCancelling {
            isCancelling = true
            // The processor reports every unfinished item as cancelled; state settles when it returns
            processingTask.cancel()
        }
        // A conflict prompt would hold the run in preparation; Cancel (or Stop Compressing) answers it
        resolveConflict(.skip)
    }

    /// Cancels the running batch and returns once the images being written have finished, so
    /// quitting never leaves a half-written file behind. Gives up after `timeout`, as a write can
    /// hang (a network share that went away); its hidden temp file is removed by a later run.
    func cancelCompressionAndWait(timeout: Duration = .seconds(10)) async {
        guard processingTask != nil else { return }
        cancelCompression()
        // Polled: waiting on the run's task cannot be given a timeout
        let deadline = ContinuousClock.now + timeout
        while processingTask != nil, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    private func compress(_ items: [ImageItem]) async {
        guard !items.isEmpty, !batchJob.isProcessing else { return }
        guard let settingsSnap = settings.snapshot() else {
            errorMessage = String(localized: "Please select an output folder first.")
            return
        }
        let outputDir = settingsSnap.outputDirectory

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: outputDir.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            errorMessage = String(localized: "The output folder \"\(outputDir.lastPathComponent)\" is no longer available. Choose an output folder again.")
            return
        }
        // Read-only folders and volumes would fail every image with the same error
        guard FileManager.default.canCreateFiles(in: outputDir) else {
            errorMessage = String(localized: "PixelDiet can't save to the output folder \"\(outputDir.lastPathComponent)\". Choose a folder you can write to.")
            return
        }

        do {
            try PathSanitizer.validateNoOverlap(inputURLs: items.map(\.sourceURL), outputDir: outputDir)
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        // Reset conflict policy for each new compression run
        conflictPolicy = .ask
        batchJob.isProcessing = true
        batchJob.startRun(format: settingsSnap.outputFormat.displayName, quality: settingsSnap.quality, itemCount: items.count)
        feedback.progressDidChange(0)
        // The images belong to the new run from now on, without last run's results
        for item in items {
            item.batchRunId = batchJob.currentRunId
            item.status = .queued
            item.compressedSize = nil
            item.compressedDimensions = nil
            item.destinationURL = nil
        }

        // One task for preparing and compressing, so Cancel and Quit work in both phases
        let run = Task { await prepareAndProcess(items, settings: settingsSnap) }
        processingTask = run
        await run.value

        let completedCount = batchJob.activeRun?.completedCount ?? 0
        batchJob.finishRun()
        batchJob.isProcessing = false
        isCancelling = false
        processingTask = nil
        feedback.progressDidChange(nil)
        // A run the user stopped is not announced with a sound or notification
        if !run.isCancelled {
            feedback.batchDidFinish(completedCount: completedCount)
        }
    }

    /// Picks each image's destination (asking about existing files), then compresses. After
    /// Cancel, every image not handed to the processor yet is reported as cancelled.
    private func prepareAndProcess(_ items: [ImageItem], settings settingsSnap: SettingsSnapshot) async {
        var planned: [(item: ImageItem, task: ImageTask, proposed: URL)] = []
        for item in items {
            let task = item.toTask(requestedFormat: settingsSnap.outputFormat)
            item.outputFormatUsed = task.outputFormat.displayName
            do {
                let proposed = try PathSanitizer.buildDestinationURL(
                    source: item.sourceURL,
                    outputDir: settingsSnap.outputDirectory,
                    format: task.outputFormat,
                    relativePath: settingsSnap.preserveDirectoryStructure ? item.relativePath : nil
                )
                planned.append((item, task, proposed))
            } catch {
                record(.failed(error: error.localizedDescription), for: item, result: nil)
            }
        }

        let existing = await Self.existingFiles(at: planned.map(\.proposed))
        var reservedPaths = Set<String>()
        var tasks: [ImageTask] = []

        for (index, entry) in planned.enumerated() {
            let destination = await resolveDestination(entry.proposed, existsOnDisk: existing[index], reserved: reservedPaths)
            guard !Task.isCancelled else {
                // Tasks prepared so far are reported as cancelled by the processor
                for remaining in planned[index...] {
                    record(.cancelled, for: remaining.item, result: nil)
                }
                break
            }
            guard let destination else {
                record(.skipped(reason: String(localized: "File already exists")), for: entry.item, result: nil)
                continue
            }
            reservedPaths.insert(Self.reservationKey(for: destination))
            var task = entry.task
            task.precomputedDestination = destination
            tasks.append(task)
        }

        // Leftovers of a crash or forced quit in the folders about to be written to (not after Cancel)
        if !Task.isCancelled {
            let destinationFolders = Set(tasks.compactMap { $0.precomputedDestination?.deletingLastPathComponent() })
            await Task.detached(priority: .utility) {
                TempFileSweeper.removeStaleFiles(in: destinationFolders)
            }.value
        }

        // Full speed while the window is hidden (no App Nap), no idle sleep, and macOS does not
        // quit the app on its own while images are written (not while a dialog waits for an answer)
        let activity = ProcessInfo.processInfo.beginActivity(options: .userInitiated, reason: Self.compressionActivityReason)
        defer { ProcessInfo.processInfo.endActivity(activity) }

        // Build lookup dictionary for O(1) item access in callback
        let itemLookup = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        for task in tasks {
            itemLookup[task.id]?.status = .processing
        }
        await batchProcessor.process(tasks: tasks, settings: settingsSnap) { [self] id, status, result in
            guard let item = itemLookup[id] else { return }
            record(status, for: item, result: result)
        }
    }

    /// Whether a file exists at each URL. Checked off the main actor, as thousands of checks
    /// take a while on a network volume; stops checking once the run is cancelled.
    @concurrent
    private nonisolated static func existingFiles(at urls: [URL]) async -> [Bool] {
        urls.map { !Task.isCancelled && FileManager.default.fileExists(atPath: $0.path) }
    }

    private func record(_ status: ProcessingStatus, for item: ImageItem, result: CompressionResult?) {
        if let result, result.sourceSize != item.originalSize {
            batchJob.updateOriginalSize(of: item, to: result.sourceSize)
        }
        item.status = status
        item.compressedSize = result?.outputSize
        item.compressedDimensions = result?.outputDimensions
        item.destinationURL = result?.outputURL
        batchJob.recordCompletion(status: status, originalSize: item.originalSize, compressedSize: result?.outputSize)
        feedback.progressDidChange(batchJob.progress)
    }

    /// Key for destinations already claimed in this batch. Case- and normalization-insensitive,
    /// because the default macOS volume format treats "Photo.jpg" and "photo.jpg" as one file.
    private nonisolated static func reservationKey(for url: URL) -> String {
        url.standardizedFileURL.path.precomposedStringWithCanonicalMapping.lowercased()
    }

    /// Applies the conflict policy (asking the user when needed) to a proposed destination.
    /// Returns nil when the item should be skipped.
    private func resolveDestination(_ proposed: URL, existsOnDisk: Bool, reserved: Set<String>) async -> URL? {
        // Another image in this run already writes this name: number this one without asking
        // about a file the run itself is about to create. The numbered name may exist from an
        // earlier run, so it then goes through the policy like any other name.
        var destination = proposed
        var exists = existsOnDisk
        if reserved.contains(Self.reservationKey(for: proposed)) {
            destination = Self.firstNumberedName(of: proposed) { reserved.contains(Self.reservationKey(for: $0)) }
            exists = await Self.existingFiles(at: [destination]).first ?? false
        }
        guard exists else {
            return destination
        }

        // Renaming numbers the original name past every taken one: "a-2.jpg", not "a-1-1.jpg"
        let renamed = { await Self.nextFreeName(for: proposed, reserved: reserved) }
        switch conflictPolicy {
        case .ask:
            // Cancelled while existing files were checked: no prompt, the image counts as cancelled
            guard !Task.isCancelled else { return nil }
            switch await askAboutConflict(fileName: destination.lastPathComponent) {
            case .overwrite:
                return destination
            case .overwriteAll:
                conflictPolicy = .overwriteAll
                return destination
            case .rename:
                return await renamed()
            case .renameAll:
                conflictPolicy = .renameAll
                return await renamed()
            case .skip:
                return nil
            case .skipAll:
                conflictPolicy = .skipAll
                return nil
            }
        case .overwriteAll:
            return destination
        case .renameAll:
            return await renamed()
        case .skipAll:
            return nil
        }
    }

    /// "photo.jpg" -> "photo-1.jpg", "photo-2.jpg", ... keeping the user's full name: the first one not taken.
    private nonisolated static func firstNumberedName(of url: URL, skipping isTaken: (URL) -> Bool) -> URL {
        var number = 1
        var candidate = PathSanitizer.numberedVariant(of: url, number: number)
        while isTaken(candidate) {
            number += 1
            candidate = PathSanitizer.numberedVariant(of: url, number: number)
        }
        return candidate
    }

    /// The first numbered name that is neither on disk nor claimed by this run, looked up off
    /// the main actor like `existingFiles`.
    @concurrent
    private nonisolated static func nextFreeName(for url: URL, reserved: Set<String>) async -> URL {
        firstNumberedName(of: url) { FileManager.default.fileExists(atPath: $0.path) || reserved.contains(reservationKey(for: $0)) }
    }

    private func askAboutConflict(fileName: String) async -> ConflictChoice {
        await withCheckedContinuation { continuation in
            pendingOverwriteFile = fileName
            pendingOverwriteContinuation = continuation
        }
    }

    // MARK: - Discovery

    private nonisolated struct DiscoveredImage: Sendable {
        let url: URL
        /// The folder the user added, for files found inside it
        let inputRoot: URL?
        let info: ImageAnalyzer.ImageInfo
    }

    /// Expands folders (recursively) and analyzes every candidate in parallel, off the main actor.
    /// Results are in Finder-style name order: selected items by name, folder contents by path.
    private nonisolated static func discoverImages(in urls: [URL], analyzer: any ImageAnalyzing) async -> [DiscoveredImage] {
        let byName = { (lhs: URL, rhs: URL) in
            lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
        }
        var candidates: [(url: URL, inputRoot: URL?)] = []
        for url in urls.sorted(by: byName) {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                let found = FileManager.default.findImages(in: url)
                    .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
                candidates += found.map { ($0, url) }
            } else {
                candidates.append((url, nil))
            }
        }

        let entries = candidates
        return await withTaskGroup(of: (index: Int, image: DiscoveredImage)?.self) { group in
            for (index, entry) in entries.enumerated() {
                group.addTask {
                    guard let info = try? analyzer.analyze(url: entry.url) else { return nil }
                    return (index, DiscoveredImage(url: entry.url, inputRoot: entry.inputRoot, info: info))
                }
            }

            var results: [(index: Int, image: DiscoveredImage)] = []
            for await result in group {
                if let result { results.append(result) }
            }
            return results.sorted { $0.index < $1.index }.map(\.image)
        }
    }

    /// Path of `url` relative to `root` (e.g. "day1/photo.jpg"), or nil when not inside it.
    private static func relativePath(of url: URL, under root: URL) -> String? {
        let rootComponents = root.standardizedFileURL.pathComponents
        let fileComponents = url.standardizedFileURL.pathComponents
        guard fileComponents.count > rootComponents.count,
              Array(fileComponents.prefix(rootComponents.count)) == rootComponents else { return nil }
        return fileComponents.dropFirst(rootComponents.count).joined(separator: "/")
    }

    private static func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                continuation.resume(returning: url)
            }
        }
    }
}
