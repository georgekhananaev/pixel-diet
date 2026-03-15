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

    /// Pending overwrite confirmation — set when a conflict is found during startCompression
    var pendingOverwriteFile: String?
    var pendingOverwriteContinuation: CheckedContinuation<ConflictChoice, Never>?

    // MARK: - Queue Management

    func addFiles(urls: [URL]) async {
        // Reset conflict policy when new files are added
        conflictPolicy = .ask

        // Create security-scoped bookmarks for dropped URLs (Round 2 Fix: H-4)
        for url in urls {
            try? BookmarkManager.saveBookmark(for: url)
        }

        // Discover images (async to avoid blocking main thread)
        // Round 3 Fix: Collect ImageInfo results in TaskGroup, then batch-create
        // ImageItem instances afterward — avoids N individual MainActor hops.
        let imageURLs = urls.flatMap { url -> [URL] in
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                return FileManager.default.findImages(in: url)
            } else {
                return [url]
            }
        }

        let infos = await withTaskGroup(of: (URL, ImageAnalyzer.ImageInfo)?.self) { group in
            for url in imageURLs {
                group.addTask { [analyzer] in
                    guard let info = try? analyzer.analyze(url: url) else { return nil }
                    return (url, info)
                }
            }

            var results: [(URL, ImageAnalyzer.ImageInfo)] = []
            for await result in group {
                if let result { results.append(result) }
            }
            return results
        }

        // Batch-create ImageItems on MainActor (already here — implicit under Swift 6.2)
        let items = infos.map { url, info in
            ImageItem(
                sourceURL: url,
                originalSize: info.fileSize,
                originalDimensions: info.dimensions,
                frameCount: info.frameCount,
                hasGPSData: info.hasGPSData,
                bitDepth: info.bitDepth,
                colorSpaceName: info.colorSpaceName,
                detectedFormat: info.detectedFormat
            )
        }

        batchJob.addItems(items)

        // Load thumbnails async
        for item in items {
            Task {
                if let cgImage = await thumbnailService.thumbnail(for: item.sourceURL) {
                    item.thumbnail = NSImage(cgImage: cgImage, size: .zero)
                }
            }
        }
    }

    // MARK: - Compression

    func startCompression() async {
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
        let settingsSnap = settings.snapshot()
        var reservedPaths = Set<String>()
        var tasks: [ImageTask] = []

        for item in batchJob.items {
            let outputFormat = settingsSnap.outputFormat == .original
                ? (item.effectiveFormat?.canBeOutput == true ? item.effectiveFormat! : .jpeg)
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
                            batchJob.recordCompletion(status: .skipped(reason: "File exists"), compressedSize: nil)
                            continue
                        case .skipAll:
                            conflictPolicy = .skipAll
                            item.status = .skipped(reason: "File exists")
                            batchJob.recordCompletion(status: .skipped(reason: "File exists"), compressedSize: nil)
                            continue
                        }
                    } else {
                        // In-batch collision only — auto-rename
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
                        batchJob.recordCompletion(status: .skipped(reason: "File exists"), compressedSize: nil)
                        continue
                    }
                    // In-batch collision — rename
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
        }

        batchJob.isProcessing = true
        batchJob.startTime = Date()
        batchJob.endTime = nil

        // Reset counters for fresh batch
        NSApp.dockTile.badgeLabel = "0%"

        processingTask = Task {
            await batchProcessor.process(
                tasks: tasks,
                settings: settingsSnap
            ) { [weak self] id, status, size, dims in
                guard let self, let item = self.batchJob.items.first(where: { $0.id == id }) else { return }
                item.status = status
                item.compressedSize = size
                item.compressedDimensions = dims
                self.batchJob.recordCompletion(status: status, compressedSize: size)

                // Update dock badge with progress percentage
                let pct = Int(self.batchJob.progress * 100)
                NSApp.dockTile.badgeLabel = pct < 100 ? "\(pct)%" : nil
            }

            batchJob.isProcessing = false
            batchJob.endTime = Date()

            // Clear dock badge
            NSApp.dockTile.badgeLabel = nil

            // Haptic feedback
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)

            // System notification when app is in background
            if !NSApp.isActive {
                let content = UNMutableNotificationContent()
                content.title = "PixelDiet"
                content.body = "Batch complete \u{2014} \(batchJob.completedCount) images compressed"
                content.sound = .default
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                try? await UNUserNotificationCenter.current().add(request)
            }
        }
    }

    func cancelCompression() {
        processingTask?.cancel()
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

        let settingsSnap = settings.snapshot()
        var reservedPaths = Set<String>(batchJob.items.compactMap { $0.destinationURL?.path })
        var tasks: [ImageTask] = []

        for item in failedItems {
            let outputFormat = settingsSnap.outputFormat == .original
                ? (item.effectiveFormat?.canBeOutput == true ? item.effectiveFormat! : .jpeg)
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

        processingTask = Task {
            await batchProcessor.process(
                tasks: tasks,
                settings: settingsSnap
            ) { [weak self] id, status, size, dims in
                guard let self, let item = self.batchJob.items.first(where: { $0.id == id }) else { return }
                item.status = status
                item.compressedSize = size
                item.compressedDimensions = dims
                self.batchJob.recordCompletion(status: status, compressedSize: size)
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

    func removeItems(_ ids: Set<UUID>, undoManager: UndoManager?) {
        let removed = batchJob.items.filter { ids.contains($0.id) }
        batchJob.items.removeAll { ids.contains($0.id) }

        undoManager?.registerUndo(withTarget: self) { vm in
            Task { @MainActor in
                vm.batchJob.addItems(removed)
            }
        }
        undoManager?.setActionName("Remove \(removed.count) Items")
    }
}
