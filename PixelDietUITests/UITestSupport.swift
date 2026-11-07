import XCTest
import ImageIO
import UniformTypeIdentifiers

/// Input and output folders with generated sample images for one UI test.
struct UITestFixture {
    let root: URL
    let input: URL
    let output: URL

    init(imageCount: Int, width: Int = 640, height: Int = 480) throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PixelDietUITests-\(UUID().uuidString)", isDirectory: true)
        input = root.appendingPathComponent("Photos", isDirectory: true)
        output = root.appendingPathComponent("Compressed", isDirectory: true)
        try FileManager.default.createDirectory(at: input, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for index in 1...max(1, imageCount) {
            let name = String(format: "IMG_%04d.png", index)
            try SampleImages.writePhoto(width: width, height: height, seed: index, to: input.appendingPathComponent(name), type: .png)
        }
    }

    func outputFiles(withExtension ext: String) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: output.path).filter { $0.hasSuffix(".\(ext)") }.sorted()
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

/// Procedural landscape "photos" with texture and grain, so compression results look realistic.
enum SampleImages {
    struct WriteError: Error {}

    static func writePhoto(width: Int, height: Int, seed: Int, to url: URL, type: UTType) throws {
        guard let image = makePhoto(width: width, height: height, seed: seed),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
            throw WriteError()
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw WriteError() }
    }

    /// Writes one large, quick-to-generate gradient PNG and `count` copies of it.
    static func writeLargeCopies(count: Int, width: Int, height: Int, into folder: URL) throws {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let gradient = CGGradient(colorsSpace: space, colors: [CGColor(srgbRed: 0.1, green: 0.3, blue: 0.6, alpha: 1),
                                                                     CGColor(srgbRed: 0.9, green: 0.6, blue: 0.3, alpha: 1)] as CFArray,
                                        locations: [0, 1]) else { throw WriteError() }
        ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: width, y: height), options: [])
        guard let image = ctx.makeImage() else { throw WriteError() }
        let first = folder.appendingPathComponent("Large_0001.png")
        guard let destination = CGImageDestinationCreateWithURL(first as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw WriteError()
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw WriteError() }
        for index in 2...max(2, count) {
            try FileManager.default.copyItem(at: first, to: folder.appendingPathComponent(String(format: "Large_%04d.png", index)))
        }
    }

    private static let palettes: [[(CGFloat, CGFloat, CGFloat)]] = [
        [(0.98, 0.62, 0.36), (0.93, 0.36, 0.42), (0.36, 0.22, 0.46)],
        [(0.55, 0.78, 0.98), (0.80, 0.90, 0.98), (0.20, 0.45, 0.30)],
        [(0.10, 0.12, 0.30), (0.45, 0.25, 0.55), (0.08, 0.10, 0.18)],
        [(0.99, 0.85, 0.55), (0.98, 0.70, 0.45), (0.40, 0.30, 0.25)],
        [(0.60, 0.85, 0.90), (0.90, 0.95, 0.97), (0.15, 0.35, 0.45)],
        [(0.85, 0.55, 0.75), (0.98, 0.80, 0.70), (0.25, 0.20, 0.35)],
    ]

    static func makePhoto(width: Int, height: Int, seed: Int) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        var rng = SplitMix(seed: UInt64(seed + 1))
        let p = palettes[seed % palettes.count]
        let w = CGFloat(width), h = CGFloat(height)
        let colors = [CGColor(srgbRed: p[0].0, green: p[0].1, blue: p[0].2, alpha: 1),
                      CGColor(srgbRed: p[1].0, green: p[1].1, blue: p[1].2, alpha: 1)] as CFArray
        if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
            ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: h), end: .zero, options: [])
        }
        // Sun
        ctx.setFillColor(CGColor(srgbRed: 1, green: 0.95, blue: 0.8, alpha: 0.85))
        let r = h * CGFloat(0.08 + rng.unit() * 0.06)
        ctx.fillEllipse(in: CGRect(x: w * CGFloat(0.2 + rng.unit() * 0.6), y: h * 0.55, width: r * 2, height: r * 2))
        // Mountain layers
        for layer in 0..<4 {
            let shade = CGFloat(layer) / 4
            ctx.setFillColor(CGColor(srgbRed: p[2].0 * (1 - shade * 0.5) + shade * 0.1, green: p[2].1 * (1 - shade * 0.4),
                                     blue: p[2].2 * (1 - shade * 0.3), alpha: 1))
            let path = CGMutablePath()
            let base = h * (0.5 - CGFloat(layer) * 0.1)
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: 0, y: base))
            var x: CGFloat = 0
            while x < w {
                x += w / CGFloat(6 + layer * 3)
                path.addLine(to: CGPoint(x: x, y: base + CGFloat(rng.unit() - 0.4) * h * 0.18))
            }
            path.addLine(to: CGPoint(x: w, y: 0))
            path.closeSubpath()
            ctx.addPath(path)
            ctx.fillPath()
        }
        // Foliage texture and clouds, scaled to the image size
        let dots = Int(Double(width * height) / 1350)
        for _ in 0..<dots {
            let size = CGFloat(2 + rng.unit() * 26) * w / 4032 * 4
            let tone = CGFloat(rng.unit() * 0.35)
            ctx.setFillColor(CGColor(srgbRed: p[2].0 * tone + 0.05, green: p[2].1 * (0.6 + tone), blue: p[2].2 * tone + 0.05, alpha: 0.55))
            ctx.fillEllipse(in: CGRect(x: CGFloat(rng.unit()) * w, y: CGFloat(rng.unit()) * h * 0.5,
                                       width: size, height: size * CGFloat(0.6 + rng.unit())))
        }
        for _ in 0..<60 {
            ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: CGFloat(0.05 + rng.unit() * 0.12)))
            let cw = w * CGFloat(0.05 + rng.unit() * 0.2)
            ctx.fillEllipse(in: CGRect(x: CGFloat(rng.unit()) * w, y: h * CGFloat(0.6 + rng.unit() * 0.38), width: cw, height: cw * 0.18))
        }
        guard let base = ctx.makeImage() else { return nil }

        // Film grain
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let grain = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                        bytesPerRow: bytesPerRow, space: space,
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            grain.draw(base, in: CGRect(x: 0, y: 0, width: width, height: height))
            let bytes = buffer.bindMemory(to: UInt8.self)
            var i = 0
            while i < bytes.count {
                let noise = Int(rng.next() % 41) - 20
                bytes[i] = UInt8(clamping: Int(bytes[i]) + noise)
                bytes[i + 1] = UInt8(clamping: Int(bytes[i + 1]) + noise)
                bytes[i + 2] = UInt8(clamping: Int(bytes[i + 2]) + noise)
                i += 4
            }
            return true
        }
        guard drawn, let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow,
                       space: space, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    private struct SplitMix {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
        mutating func unit() -> Double { Double(next() % 10_000) / 10_000 }
    }
}

extension XCUIApplication {
    /// Launches PixelDiet without restoring windows from a previous run.
    /// With `freshSettings`, saved settings and the saved output folder are ignored for this
    /// launch: empty values in the argument domain shadow the stored ones (the sandboxed
    /// app's preferences can't be edited from the test runner). Changes are still saved,
    /// so a later launch without `freshSettings` sees them.
    static func launchPixelDiet(freshSettings: Bool = true, arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"] + arguments
        if freshSettings {
            app.launchArguments += [
                "-com.georgekhananaev.PixelDiet.settings", "",
                "-com.georgekhananaev.PixelDiet.outputFolderBookmark", "",
            ]
        }
        app.launch()
        app.activate()
        return app
    }

    var openPanel: XCUIElement { dialogs["open-panel"] }

    /// Navigates the open panel to `folder` with Go to Folder (Cmd-Shift-G) and confirms.
    /// With `selectAll`, every item in the folder is selected before confirming.
    func confirmOpenPanel(at folder: URL, selectAll: Bool = false, file: StaticString = #filePath, line: UInt = #line) {
        let panel = openPanel
        XCTAssertTrue(panel.waitForExistence(timeout: 10), "Open panel did not appear", file: file, line: line)
        typeKey("g", modifierFlags: [.command, .shift])
        sleep(1)
        typeText(folder.path)
        typeKey(.return, modifierFlags: [])
        sleep(1)
        if selectAll {
            typeKey("a", modifierFlags: .command)
            sleep(1)
        }
        let confirm = panel.buttons["OKButton"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), file: file, line: line)
        confirm.click()
        XCTAssertTrue(panel.waitForNonExistence(timeout: 10), "Open panel did not close", file: file, line: line)
    }

    func chooseOutputFolder(_ folder: URL) {
        buttons["Choose Output Folder..."].firstMatch.click()
        confirmOpenPanel(at: folder)
    }

    func addAllImages(in folder: URL) {
        let addButton = buttons["Browse Files"].firstMatch.exists ? buttons["Browse Files"].firstMatch : toolbars.buttons["Add Files"]
        addButton.click()
        confirmOpenPanel(at: folder, selectAll: true)
    }

    /// One accessibility element per image row (the row combines its children).
    var imageRows: XCUIElementQuery {
        outlines.firstMatch.buttons.matching(identifier: "ellipsis.circle")
    }

    /// A point on the row's thumbnail. Clicking the combined row element itself would aim at
    /// its accessibility hit point, which is the row's actions (ellipsis) menu button.
    func imageRowPoint(_ index: Int) -> XCUICoordinate {
        imageRows.element(boundBy: index).coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.5))
    }

    /// The run summary row, which reads its parts as one label ("JPEG Q80, 2/3, (1 failed), …").
    func runSummary(containing text: String) -> XCUIElement {
        buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// Runs the accessibility audit and reports every issue with the element it is about.
    /// Skipped, as they are macOS's own: AppKit's unnamed containers around the SwiftUI content
    /// (the window's hosting view and the split view's columns), which SwiftUI cannot label
    /// (labels set on the content land on the elements inside, which are still audited); the
    /// window's title-bar buttons; the menu bar outside the windows; and "Action is missing" on
    /// pop-up buttons, which SwiftUI's standard menu Picker reports (labelled; it opens by click
    /// and keyboard, and VoiceOver users should confirm it opens with VO-Space). Contrast flags are
    /// measured again on the element's own rendering: the audit also flags secondary text that
    /// measures 5.9:1 in Dark Mode.
    func auditAccessibility(file: StaticString = #filePath, line: UInt = #line) throws {
        let windowList = windows.allElementsBoundByIndex
        let containerFrames = windowList.flatMap { window in
            [window.frame] + window.splitGroups.firstMatch.children(matching: .group).allElementsBoundByIndex.map(\.frame)
        }
        let titleBarButtonFrames = windowList.flatMap { window in
            window.buttons.matching(NSPredicate(format: "identifier BEGINSWITH '_XCUI:'")).allElementsBoundByIndex.map(\.frame)
        }
        let isSystemElement = { (element: XCUIElement, type: XCUIAccessibilityAuditType) in
            let frame = element.frame
            return (type == .sufficientElementDescription && element.elementType == .group && containerFrames.contains(frame))
                || titleBarButtonFrames.contains { $0.contains(frame) }
                || !windowList.contains { $0.frame.intersects(frame) }
                || (type == .action && element.elementType == .popUpButton)
        }
        var issues: [String] = []
        try performAccessibilityAudit { issue in
            guard let element = issue.element else {
                issues.append(issue.compactDescription)
                return true
            }
            if isSystemElement(element, issue.auditType) {
                return true
            }
            var measured = ""
            if issue.auditType == .contrast, let ratio = Self.measuredContrast(of: element) {
                guard ratio < 4.5 else { return true }
                measured = String(format: " (measured %.2f:1)", ratio)
            }
            issues.append("\(issue.compactDescription)\(measured): \(element.elementType.rawValue) label='\(element.label)' id='\(element.identifier)' frame=\(element.frame)")
            return true
        }
        XCTAssertTrue(issues.isEmpty, issues.joined(separator: "\n"), file: file, line: line)
    }

    /// WCAG contrast ratio of an element as drawn: its most common color is the background, and
    /// the pixel farthest from it is the text color (glyph stems are fully covered at 2x).
    private static func measuredContrast(of element: XCUIElement) -> Double? {
        guard let image = element.screenshot().image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ),
              let data = context.data else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = data.assumingMemoryBound(to: UInt8.self)
        let linear = { (value: UInt8) -> Double in
            let channel = Double(value) / 255
            return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        var counts: [UInt32: Int] = [:]
        var luminances: [UInt32: Double] = [:]
        for offset in stride(from: 0, to: image.width * image.height * 4, by: 4) {
            let (red, green, blue) = (bytes[offset], bytes[offset + 1], bytes[offset + 2])
            let key = UInt32(red) << 16 | UInt32(green) << 8 | UInt32(blue)
            counts[key, default: 0] += 1
            if luminances[key] == nil {
                luminances[key] = 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
            }
        }
        guard let background = counts.max(by: { $0.value < $1.value }).flatMap({ luminances[$0.key] }),
              let text = luminances.values.max(by: { abs($0 - background) < abs($1 - background) }) else { return nil }
        return (max(background, text) + 0.05) / (min(background, text) + 0.05)
    }

    func selectOutputFormat(_ name: String) {
        let popUp = windows.firstMatch.popUpButtons.firstMatch
        popUp.click()
        popUp.menuItems[name].click()
    }
}
