import Foundation

nonisolated struct PathSanitizer {
    /// Build destination URL with structure preservation and collision handling
    static func buildDestinationURL(
        source: URL,
        outputDir: URL,
        format: ImageFormat,
        relativePath: String?
    ) throws -> URL {
        // Sanitize filename - strip path separators
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

            // Security: verify destination is still within output directory.
            // Compare path components so "/out" does not match "/out2".
            let destComponents = destURL.standardizedFileURL.pathComponents
            let outputComponents = outputDir.standardizedFileURL.pathComponents
            guard destComponents.count > outputComponents.count,
                  Array(destComponents.prefix(outputComponents.count)) == outputComponents else {
                throw CompressionError.outputDirectoryNotWritable
            }
        } else {
            destURL = outputDir.appendingPathComponent(fileName)
        }

        // NOTE: Do NOT resolve collisions here - the ViewModel handles overwrite
        // dialogs and in-memory collision resolution before dispatching to BatchProcessor.
        return destURL
    }

    /// "photo.jpg" -> "photo-<number>.jpg". The whole original stem is kept, so names
    /// that already end in a number ("2024-05-01", "IMG-0001") are not rewritten.
    static func numberedVariant(of url: URL, number: Int) -> URL {
        let baseName = url.deletingPathExtension().lastPathComponent
        return url.deletingLastPathComponent().appendingPathComponent("\(baseName)-\(number).\(url.pathExtension)")
    }

    /// Validate output directory does not overlap with input.
    /// Only blocks when:
    /// - Output dir is the SAME as an input dir (would overwrite originals)
    /// - Input files are INSIDE the output dir (output is parent of input - could overwrite)
    /// Allows output to be a subfolder of input - that's a common valid use case.
    static func validateNoOverlap(inputURLs: [URL], outputDir: URL) throws {
        // Use standardizedFileURL to resolve symlinks, .., and trailing slashes consistently
        let outputComponents = outputDir.resolvingSymlinksInPath().standardizedFileURL.pathComponents

        var checkedDirs = Set<[String]>()
        for url in inputURLs {
            let inputDir = url.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
            let inputComponents = inputDir.pathComponents
            guard !checkedDirs.contains(inputComponents) else { continue }
            checkedDirs.insert(inputComponents)

            // Block if same directory
            if inputComponents == outputComponents {
                throw CompressionError.inputOutputOverlap
            }

            // Block if input is inside output (output is parent of input)
            if inputComponents.count > outputComponents.count
                && Array(inputComponents.prefix(outputComponents.count)) == outputComponents {
                throw CompressionError.inputOutputOverlap
            }
        }
    }
}
