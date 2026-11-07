import XCTest
import UniformTypeIdentifiers

/// Captures Mac App Store screenshots (2880 x 1800, 16:10) of the real app window as test
/// attachments. Skipped unless PIXELDIET_SCREENSHOTS is set, e.g.:
/// `TEST_RUNNER_PIXELDIET_SCREENSHOTS=1 xcodebuild test -only-testing:PixelDietUITests/AppStoreScreenshots -resultBundlePath shots.xcresult`
/// then `xcrun xcresulttool export attachments --path shots.xcresult --output-path <dir>`.
final class AppStoreScreenshots: XCTestCase {
    private let windowSize = CGSize(width: 1440, height: 900)
    private var root: URL?

    override func tearDown() async throws {
        await MainActor.run { XCUIApplication().terminate() }
        if let root { try? FileManager.default.removeItem(at: root) }
        try await super.tearDown()
    }

    @MainActor
    func testCaptureScreenshots() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["PIXELDIET_SCREENSHOTS"] != nil, "Set PIXELDIET_SCREENSHOTS to capture screenshots")

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PixelDietShots-\(UUID().uuidString)")
        self.root = root
        let photos = root.appendingPathComponent("Vacation Photos", isDirectory: true)
        let lightOutput = root.appendingPathComponent("Light/Compressed", isDirectory: true)
        let darkOutput = root.appendingPathComponent("Dark/Compressed", isDirectory: true)
        for folder in [photos, lightOutput, darkOutput] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        let names = ["IMG_2041.jpg", "IMG_2042.jpg", "IMG_2058.heic", "Sunset_Beach.png", "IMG_2063.jpg", "Harbor.jpg",
                     "IMG_2077.heic", "Mountain_Trail.jpg", "IMG_2090.jpg", "Old_Town.png", "IMG_2104.jpg", "Lighthouse.jpg"]
        for (index, name) in names.enumerated() {
            let type: UTType = name.hasSuffix(".png") ? .png : name.hasSuffix(".heic") ? .heic : .jpeg
            let size = type == .png ? (2400, 1600) : (4032, 3024)
            try SampleImages.writePhoto(width: size.0, height: size.1, seed: index, to: photos.appendingPathComponent(name), type: type)
        }

        // Light appearance
        var app = XCUIApplication.launchPixelDiet(arguments: ["-NSRequiresAquaSystemAppearance", "YES"])
        resizeWindow(of: app)
        app.chooseOutputFolder(lightOutput)
        app.selectOutputFormat("WebP")
        capture(app, as: "01-drop-zone")

        app.addAllImages(in: photos)
        XCTAssertTrue(app.staticTexts["12 images"].waitForExistence(timeout: 60))
        sleep(3) // thumbnails
        capture(app, as: "02-queue")

        app.toolbars.buttons["Compress 12 Images"].click()
        XCTAssertTrue(app.buttons["Open Output Folder"].waitForExistence(timeout: 120))
        capture(app, as: "03-results")

        app.imageRowPoint(1).doubleClick() // IMG_2041, a bright sunset
        XCTAssertTrue(app.staticTexts["Before / After Preview"].waitForExistence(timeout: 10))
        sleep(2) // preview images
        capture(app, as: "04-preview")
        app.typeKey(.escape, modifierFlags: [])
        app.terminate()

        // Dark appearance
        app = XCUIApplication.launchPixelDiet(arguments: ["-AppleInterfaceStyle", "Dark"])
        resizeWindow(of: app)
        app.chooseOutputFolder(darkOutput)
        app.selectOutputFormat("WebP")
        app.addAllImages(in: photos)
        XCTAssertTrue(app.staticTexts["12 images"].waitForExistence(timeout: 60))
        app.toolbars.buttons["Compress 12 Images"].click()
        XCTAssertTrue(app.buttons["Open Output Folder"].waitForExistence(timeout: 120))
        sleep(2)
        capture(app, as: "05-results-dark")
    }

    /// Moves the window below the menu bar, then drags its bottom-right corner so the
    /// window is exactly `windowSize` points.
    @MainActor
    private func resizeWindow(of app: XCUIApplication) {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        let titleBar = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: 0, dy: 12))
        titleBar.press(forDuration: 0.3, thenDragTo: titleBar.withOffset(CGVector(dx: 0, dy: 60 - window.frame.minY)))
        let frame = window.frame
        let corner = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1)).withOffset(CGVector(dx: -2, dy: -2))
        let target = corner.withOffset(CGVector(dx: windowSize.width - frame.width, dy: windowSize.height - frame.height))
        corner.press(forDuration: 0.3, thenDragTo: target)
        XCTAssertEqual(window.frame.size, windowSize, "Window resized for screenshots")
    }

    @MainActor
    /// Attaches the window at full resolution; `XCTAttachment(screenshot:)` would downscale it.
    /// Keyboard focus is first moved to the image list (empty area), so no toolbar button shows
    /// a focus ring when keyboard navigation is enabled.
    private func capture(_ app: XCUIApplication, as name: String) {
        let list = app.outlines.firstMatch
        if list.exists, app.sheets.count == 0 {
            list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.97)).click()
        }
        let image = app.windows.firstMatch.screenshot().image
        // App Store Connect rejects screenshots with an alpha channel: the window's rounded
        // corners are placed on white
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil, width: cgImage.width, height: cgImage.height, bitsPerComponent: 8, bytesPerRow: 0,
                space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ) else {
            XCTFail("Could not prepare screenshot \(name)")
            return
        }
        let bounds = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        context.setFillColor(CGColor.white)
        context.fill(bounds)
        context.draw(cgImage, in: bounds)
        guard let opaque = context.makeImage(),
              let png = NSBitmapImageRep(cgImage: opaque).representation(using: .png, properties: [:]) else {
            XCTFail("Could not encode screenshot \(name)")
            return
        }
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: UTType.png.identifier)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
