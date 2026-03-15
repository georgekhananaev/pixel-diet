import SwiftUI
import AppKit
import UserNotifications

// @MainActor is implicit under Swift 6.2 default actor isolation (Round 3 Fix)
@Observable
class MainViewModel {
    let batchJob = BatchJob()
    let settings = CompressionSettings()
    let batchProcessor = BatchProcessor()
    let thumbnailService = ThumbnailService()
    let analyzer: any ImageAnalyzing = ImageAnalyzer()

    private var processingTask: Task<Void, Never>?
    var errorMessage: String?

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

    /// Pending overwrite confirmation - set when a conflict is found during startCompression
    var pendingOverwriteFile: String?
    var pendingOverwriteContinuation: CheckedContinuation<ConflictChoice, Never>?

    /// Single entry point for resolving a conflict - guarantees continuation is resumed exactly once
    func resolveConflict(_ choice: ConflictChoice) {
        guard let continuation = pendingOverwriteContinuation else { return }
        pendingOverwriteContinuation = nil
        pendingOverwriteFile = nil
        continuation.resume(returning: choice)
    }

    // MARK: - Queue Management

    func addFiles(urls: [URL]) async {
        // Reset conflict policy when new files are added
        conflictPolicy = .ask

        // Create security-scoped bookmarks for dropped URLs (Round 2 Fix: H-4)
        for url in urls {
            try? BookmarkManager.saveBookmark(for: url)
        }

        // Discover images and track input root for relative path computation
        var imageEntries: [(url: URL, inputRoot: URL?)] = []
        for url in urls {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                let images = FileManager.default.findImages(in: url)
                for imageURL in images {
                    imageEntries.append((url: imageURL, inputRoot: url))
                }
            } else {
                imageEntries.append((url: url, inputRoot: nil))
            }
        }

        let entries = imageEntries
        let infos = await withTaskGroup(of: (URL, URL?, ImageAnalyzer.ImageInfo)?.self) { group in
            for entry in entries {
                group.addTask { [analyzer] in
                    guard let info = try? analyzer.analyze(url: entry.url) else { return nil }
                    return (entry.url, entry.inputRoot, info)
                }
            }

            var results: [(URL, URL?, ImageAnalyzer.ImageInfo)] = []
            for await result in group {
                if let result { results.append(result) }
            }
            return results
        }

        // Batch-create ImageItems on MainActor
        let items = infos.map { url, inputRoot, info in
            // Compute relative path from input root directory
            var relativePath: String? = nil
            if let inputRoot {
                let rootPath = inputRoot.standardizedFileURL.path
                let filePath = url.standardizedFileURL.path
                if filePath.hasPrefix(rootPath) {
                    let relative = String(filePath.dropFirst(rootPath.count))
                        .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    if !relative.isEmpty {
                        relativePath = relative
                    }
                }
            }

            return ImageItem(
                sourceURL: url,
                originalSize: info.fileSize,
                originalDimensions: info.dimensions,
                frameCount: info.frameCount,
                hasGPSData: info.hasGPSData,
                relativePath: relativePath,
                bitDepth: info.bitDepth,
                colorSpaceName: info.colorSpaceName,
                detectedFormat: info.detectedFormat
            )
        }

        batchJob.addItems(items)

        // Load thumbnails async with bounded concurrency
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

    // MARK: - Compression

    func startCompression() async {
        // Reset conflict policy for each new compression run
        conflictPolicy = .ask

        guard let outputDir = settings.outputDirectory else {
            errorMessage = String(localized: "Please select an output folder first.")
            return
        }

        // Validate no overlap
        let inputURLs = batchJob.items.map(\.sourceURL)
        do {
            try PathSanitizer.validateNoOverlap(inputURLs: inputURLs, outputDir: outputDir)
        } catch {
            errorMessage = String(localized: "Output folder cannot be the same as or inside the input folder.")
            return
        }

        // Pre-compute destination paths with collision resolution
        guard let settingsSnap = settings.snapshot() else {
            errorMessage = String(localized: "Please select an output folder first.")
            return
        }
        var reservedPaths = Set<String>()
        var tasks: [ImageTask] = []

        for item in batchJob.items {
            let outputFormat = settingsSnap.outputFormat == .original
                ? (item.effectiveFormat.flatMap { $0.canBeOutput ? $0 : nil } ?? .jpeg)
                : settingsSnap.outputFormat

            var destURL: URL
            do {
                destURL = try PathSanitizer.buildDestinationURL(
                    source: item.sourceURL,
                    outputDir: outputDir,
                    format: outputFormat,
                    relativePath: settingsSnap.preserveDirectoryStructure ? item.relativePath : nil
                )
            } catch {
                errorMessage = String(localized: "Failed to build output path: \(error.localizedDescription)")
                return
            }

            // Check for existing file on disk or in-memory batch collision
            let existsOnDisk = FileManager.default.fileExists(atPath: destURL.path)
            let existsInBatch = reservedPaths.contains(destURL.path)

            if existsOnDisk || existsInBatch {
                switch conflictPolicy {
                case .ask:
                    if existsOnDisk {
                        // Ask user what to do
                        let choice = await withCheckedContinuation { continuation in
                            self.pendingOverwriteFile = destURL.lastPathComponent
                            self.pendingOverwriteContinuation = continuation
                        }
                        pendingOverwriteFile = nil
                        pendingOverwriteContinuation = nil

                        switch choice {
                        case .overwrite:
                            break // keep destURL, atomic write will replace
                        case .overwriteAll:
                            conflictPolicy = .overwriteAll
                        case .rename:
                            while FileManager.default.fileExists(atPath: destURL.path) || reservedPaths.contains(destURL.path) {
                                destURL = PathSanitizer.appendCounter(destURL)
                            }
                        case .renameAll:
                            conflictPolicy = .renameAll
                            while FileManager.default.fileExists(atPath: destURL.path) || reservedPaths.contains(destURL.path) {
                                destURL = PathSanitizer.appendCounter(destURL)
                            }
                        case .skip:
                            item.status = .skipped(reason: "File exists")
                            batchJob.recordCompletion(status: .skipped(reason: "File exists"), originalSize: item.originalSize, compressedSize: nil)
                            continue
                        case .skipAll:
                            conflictPolicy = .skipAll
                            item.status = .skipped(reason: "File exists")
                            batchJob.recordCompletion(status: .skipped(reason: "File exists"), originalSize: item.originalSize, compressedSize: nil)
                            continue
                        }
                    } else {
                        // In-batch collision only - auto-rename
                        while reservedPaths.contains(destURL.path) {
                            destURL = PathSanitizer.appendCounter(destURL)
                        }
                    }

                case .overwriteAll:
                    // Just use destURL as-is for disk conflicts, rename for batch collisions
                    while reservedPaths.contains(destURL.path) {
                        destURL = PathSanitizer.appendCounter(destURL)
                    }

                case .renameAll:
                    while FileManager.default.fileExists(atPath: destURL.path) || reservedPaths.contains(destURL.path) {
                        destURL = PathSanitizer.appendCounter(destURL)
                    }

                case .skipAll:
                    if existsOnDisk {
                        item.status = .skipped(reason: "File exists")
                        batchJob.recordCompletion(status: .skipped(reason: "File exists"), originalSize: item.originalSize, compressedSize: nil)
                        continue
                    }
                    // In-batch collision - rename
                    while reservedPaths.contains(destURL.path) {
                        destURL = PathSanitizer.appendCounter(destURL)
                    }
                }
            }
            reservedPaths.insert(destURL.path)

            var task = item.toTask()
            task.precomputedDestination = destURL
            tasks.append(task)

            item.status = .processing
            item.outputFormatUsed = outputFormat.displayName
        }

        // Start a new run with its own counters
        let formatName = settingsSnap.outputFormat.displayName
        batchJob.startRun(format: formatName, quality: settingsSnap.quality, itemCount: tasks.count)

        // Stamp items with current run ID
        for item in batchJob.items where item.status == .processing {
            item.batchRunId = batchJob.currentRunId
        }

        batchJob.isProcessing = true
        NSApp.dockTile.badgeLabel = "0%"

        // Build lookup dictionary for O(1) item access in callback
        let itemLookup = Dictionary(uniqueKeysWithValues: batchJob.items.map { ($0.id, $0) })

        processingTask = Task {
            await batchProcessor.process(
                tasks: tasks,
                settings: settingsSnap
            ) { [weak self] id, status, size, dims in
                guard let self, let item = itemLookup[id] else { return }
                item.status = status
                item.compressedSize = size
                item.compressedDimensions = dims
                self.batchJob.recordCompletion(status: status, originalSize: item.originalSize, compressedSize: size)

                // Update dock badge with progress percentage
                let pct = Int(self.batchJob.progress * 100)
                NSApp.dockTile.badgeLabel = pct < 100 ? "\(pct)%" : nil
            }

            batchJob.isProcessing = false
            batchJob.finishRun()

            // Clear dock badge
            NSApp.dockTile.badgeLabel = nil

            // Haptic feedback
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)

            // System notification when app is in background
            if !NSApp.isActive {
                // Request permission lazily, only when we actually need to send
                try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                let content = UNMutableNotificationContent()
                content.title = "PixelDiet"
                content.body = "Batch complete - \(batchJob.completedCount) images compressed"
                content.sound = .default
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                try? await UNUserNotificationCenter.current().add(request)
            }
        }
    }

    func cancelCompression() {
        processingTask?.cancel()
        processingTask = nil
        batchJob.isProcessing = false
        batchJob.finishRun()
        NSApp.dockTile.badgeLabel = nil

        // Mark still-processing items as failed
        for item in batchJob.items where item.status == .processing {
            item.status = .failed(error: "Cancelled")
            batchJob.recordCompletion(status: .failed(error: "Cancelled"), originalSize: item.originalSize, compressedSize: nil)
        }
    }

    // MARK: - Retry Failed

    func retryFailed() async {
        let failedItems = batchJob.items.filter {
            if case .failed = $0.status { return true }
            return false
        }

        guard !failedItems.isEmpty, let outputDir = settings.outputDirectory else { return }

        for item in failedItems {
            batchJob.decrementFailed()
            item.status = .processing
        }

        guard let settingsSnap = settings.snapshot() else { return }
        var reservedPaths = Set<String>(batchJob.items.compactMap { $0.destinationURL?.path })
        var tasks: [ImageTask] = []

        for item in failedItems {
            let outputFormat = settingsSnap.outputFormat == .original
                ? (item.effectiveFormat.flatMap { $0.canBeOutput ? $0 : nil } ?? .jpeg)
                : settingsSnap.outputFormat

            var destURL: URL
            do {
                destURL = try PathSanitizer.buildDestinationURL(
                    source: item.sourceURL,
                    outputDir: outputDir,
                    format: outputFormat,
                    relativePath: settingsSnap.preserveDirectoryStructure ? item.relativePath : nil
                )
            } catch {
                errorMessage = error.localizedDescription
                return
            }

            while reservedPaths.contains(destURL.path) {
                destURL = PathSanitizer.appendCounter(destURL)
            }
            reservedPaths.insert(destURL.path)

            var task = item.toTask()
            task.precomputedDestination = destURL
            tasks.append(task)
        }

        batchJob.isProcessing = true

        let itemLookup = Dictionary(uniqueKeysWithValues: failedItems.map { ($0.id, $0) })

        processingTask = Task {
            await batchProcessor.process(
                tasks: tasks,
                settings: settingsSnap
            ) { [weak self] id, status, size, dims in
                guard let self, let item = itemLookup[id] else { return }
                item.status = status
                item.compressedSize = size
                item.compressedDimensions = dims
                self.batchJob.recordCompletion(status: status, originalSize: item.originalSize, compressedSize: size)
            }

            batchJob.isProcessing = false
        }
    }

    // MARK: - Queue Operations with Undo

    func clearAll(undoManager: UndoManager?) {
        let savedItems = batchJob.items
        batchJob.clear()

        undoManager?.registerUndo(withTarget: self) { vm in
            Task { @MainActor in
                vm.batchJob.addItems(savedItems)
            }
        }
        undoManager?.setActionName("Clear All")
    }

}
