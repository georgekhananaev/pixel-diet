import Foundation

nonisolated struct PathSanitizer {
    /// Build destination URL with structure preservation and collision handling
    static func buildDestinationURL(
        source: URL,
        outputDir: URL,
        format: ImageFormat,
        relativePath: String?
    ) throws -> URL {
        // Sanitize filename — strip path separators
        let baseName = source.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")

        let fileName = baseName + "." + format.fileExtension

        var destURL: URL
        if let relativePath = relativePath, !relativePath.isEmpty {
            // Preserve directory structure
            let relativeDir = (relativePath as NSString).deletingLastPathComponent
            destURL = outputDir
                .appendingPathComponent(relativeDir)
                .appendingPathComponent(fileName)

            // Security: verify destination is still within output directory
            let resolvedDest = destURL.standardizedFileURL.path
            let resolvedOutput = outputDir.standardizedFileURL.path
            guard resolvedDest.hasPrefix(resolvedOutput) else {
                throw CompressionError.outputDirectoryNotWritable
            }
        } else {
            destURL = outputDir.appendingPathComponent(fileName)
        }

        // NOTE: Do NOT resolve collisions here — the ViewModel handles overwrite
        // dialogs and in-memory collision resolution before dispatching to BatchProcessor.
        return destURL
    }

    /// Append -1, -2, etc. if file already exists on disk (for single-file mode)
    /// NOTE: For batch mode, use in-memory reservedPaths set instead
    static func resolveCollision(at url: URL) -> URL {
        var candidate = url
        var counter = 1
        let fm = FileManager.default
        let baseName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let parentDir = url.deletingLastPathComponent()

        while fm.fileExists(atPath: candidate.path) {
            candidate = parentDir.appendingPathComponent("\(baseName)-\(counter).\(ext)")
            counter += 1
        }

        return candidate
    }

    /// Append counter to URL (for in-memory collision resolution)
    static func appendCounter(_ url: URL) -> URL {
        let baseName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let parentDir = url.deletingLastPathComponent()

        // Extract existing counter if present (e.g., "photo-3" -> 3)
        let parts = baseName.split(separator: "-")
        if let last = parts.last, let num = Int(last), parts.count > 1 {
            let nameWithoutCounter = parts.dropLast().joined(separator: "-")
            return parentDir.appendingPathComponent("\(nameWithoutCounter)-\(num + 1).\(ext)")
        }
        return parentDir.appendingPathComponent("\(baseName)-1.\(ext)")
    }

    /// Validate output directory does not overlap with input.
    /// Only blocks when:
    /// - Output dir is the SAME as an input dir (would overwrite originals)
    /// - Input files are INSIDE the output dir (output is parent of input — could overwrite)
    /// Allows output to be a subfolder of input — that's a common valid use case.
    static func validateNoOverlap(inputURLs: [URL], outputDir: URL) throws {
        let outputPath = outputDir.resolvingSymlinksInPath().path
        let outputNorm = outputPath.hasSuffix("/") ? outputPath : outputPath + "/"

        var checkedDirs = Set<String>()
        for url in inputURLs {
            let inputDir = url.deletingLastPathComponent().resolvingSymlinksInPath().path
            guard !checkedDirs.contains(inputDir) else { continue }
            checkedDirs.insert(inputDir)

            let inputNorm = inputDir.hasSuffix("/") ? inputDir : inputDir + "/"

            // Block if same directory
            if inputNorm == outputNorm {
                throw CompressionError.inputOutputOverlap
            }

            // Block if input is inside output (output is parent of input)
            if inputNorm.hasPrefix(outputNorm) {
                throw CompressionError.inputOutputOverlap
            }
        }
    }
}
