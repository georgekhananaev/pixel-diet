import XCTest

/// End-to-end journeys through the real (sandboxed) app: open panels, compression, preview,
/// conflicts, retry, cancel, persistence and the secondary windows.
final class PixelDietUITests: XCTestCase {
    private var fixture: UITestFixture?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        await MainActor.run { XCUIApplication().terminate() }
        fixture?.remove()
        try await super.tearDown()
    }

    @MainActor
    func testCompressPreviewAndConflictJourney() throws {
        let fixture = try UITestFixture(imageCount: 4)
        self.fixture = fixture
        let app = XCUIApplication.launchPixelDiet()

        // Empty state: nothing to compress yet
        XCTAssertTrue(app.staticTexts["Drop images or folders here"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.toolbars.buttons["Compress"].isEnabled)

        app.chooseOutputFolder(fixture.output)
        XCTAssertTrue(app.staticTexts["Compressed"].waitForExistence(timeout: 5), "Output folder name is shown in the sidebar")

        app.addAllImages(in: fixture.input)
        XCTAssertTrue(app.staticTexts["4 images"].waitForExistence(timeout: 15))
        let names = app.imageRows.allElementsBoundByIndex.map { $0.label.components(separatedBy: ",").first ?? "" }
        XCTAssertEqual(names, ["IMG_0001.png", "IMG_0002.png", "IMG_0003.png", "IMG_0004.png"], "Images are listed in name order")

        app.selectOutputFormat("WebP")
        let compress = app.toolbars.buttons["Compress 4 Images"]
        XCTAssertTrue(compress.isEnabled)
        compress.click()

        XCTAssertTrue(app.buttons["Open Output Folder"].waitForExistence(timeout: 60), "Run finished")
        XCTAssertEqual(try fixture.outputFiles(withExtension: "webp").count, 4)
        XCTAssertTrue(app.imageRows.allElementsBoundByIndex.allSatisfy { $0.label.contains("Completed") })
        XCTAssertTrue(app.staticTexts["Run #1 - WebP - 4/4 completed"].exists)

        // Preview by double-click, closed with Escape
        app.imageRowPoint(0).doubleClick()
        let previewTitle = app.staticTexts["Before / After Preview"]
        XCTAssertTrue(previewTitle.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Reveal Output in Finder"].exists, "Completed image knows its output file")
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(previewTitle.waitForNonExistence(timeout: 5))

        // Preview by Space on a selected row, closed with the Close button
        app.imageRowPoint(1).click()
        app.typeKey(" ", modifierFlags: [])
        XCTAssertTrue(previewTitle.waitForExistence(timeout: 5))
        app.buttons["Close"].firstMatch.click()
        XCTAssertTrue(previewTitle.waitForNonExistence(timeout: 5))

        // Right-click menu offers Preview for the clicked row
        app.imageRowPoint(2).rightClick()
        app.menuItems["Preview"].click()
        XCTAssertTrue(previewTitle.waitForExistence(timeout: 5))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(previewTitle.waitForNonExistence(timeout: 5))

        // Compressing again finds existing files: Skip All counts every image as skipped
        compress.click()
        XCTAssertTrue(app.staticTexts["File Already Exists"].waitForExistence(timeout: 10))
        app.buttons["Skip All"].click()
        XCTAssertTrue(app.runSummary(containing: "(4 skipped)").waitForExistence(timeout: 30))
        XCTAssertEqual(try fixture.outputFiles(withExtension: "webp").count, 4, "Skipped files are left alone")

        // Delete removes the selected image and updates the totals
        app.imageRowPoint(0).click()
        app.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(app.staticTexts["3 images"].waitForExistence(timeout: 5))

        // Clear All empties the queue; Undo brings the images back
        app.toolbars.buttons["Clear All"].click()
        XCTAssertTrue(app.staticTexts["Drop images or folders here"].waitForExistence(timeout: 5))
        app.typeKey("z", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["3 images"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testRenameKeepsExistingFilesAndRetryRecoversFailures() throws {
        let fixture = try UITestFixture(imageCount: 3)
        self.fixture = fixture
        let app = XCUIApplication.launchPixelDiet()
        app.chooseOutputFolder(fixture.output)
        app.selectOutputFormat("JPEG")
        app.addAllImages(in: fixture.input)
        XCTAssertTrue(app.staticTexts["3 images"].waitForExistence(timeout: 15))

        // An existing output file is kept when choosing Rename
        let existing = fixture.output.appendingPathComponent("IMG_0001.jpg")
        try Data("OLD".utf8).write(to: existing)
        // A source that disappears after import fails on its own
        let missing = fixture.input.appendingPathComponent("IMG_0002.png")
        let missingData = try Data(contentsOf: missing)
        try FileManager.default.removeItem(at: missing)

        app.toolbars.buttons["Compress 3 Images"].click()
        XCTAssertTrue(app.staticTexts["File Already Exists"].waitForExistence(timeout: 10))
        app.buttons["Rename"].click()
        XCTAssertTrue(app.runSummary(containing: "(1 failed)").waitForExistence(timeout: 30))
        XCTAssertTrue(app.imageRows.element(boundBy: 1).label.contains("The original file was moved or deleted"))
        XCTAssertEqual(try Data(contentsOf: existing), Data("OLD".utf8))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.output.appendingPathComponent("IMG_0001-1.jpg").path))

        // Restore the source and retry only the failed image
        try missingData.write(to: missing)
        let retry = app.toolbars.buttons["Retry Failed"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        retry.click()
        XCTAssertTrue(retry.waitForNonExistence(timeout: 30), "Retry Failed disappears once nothing has failed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.output.appendingPathComponent("IMG_0002.jpg").path))
    }

    @MainActor
    func testCancelLeavesNoImageProcessing() throws {
        // 48 MP images: slow enough per image that Cancel lands mid-run
        let fixture = try UITestFixture(imageCount: 1)
        self.fixture = fixture
        try SampleImages.writeLargeCopies(count: 40, width: 8000, height: 6000, into: fixture.input)
        let app = XCUIApplication.launchPixelDiet()
        app.chooseOutputFolder(fixture.output)
        app.addAllImages(in: fixture.input)
        XCTAssertTrue(app.staticTexts["41 images"].waitForExistence(timeout: 60))

        app.toolbars.buttons["Compress 41 Images"].click()
        app.typeKey(".", modifierFlags: .command)

        XCTAssertTrue(app.toolbars.buttons["Compress 41 Images"].waitForExistence(timeout: 120), "Run settled after cancel")
        XCTAssertLessThan(try fixture.outputFiles(withExtension: "jpg").count, 41, "Cancel stopped the run early")
        XCTAssertFalse(app.imageRows.allElementsBoundByIndex.contains { $0.label.contains("Processing") })
        XCTAssertTrue(app.imageRows.allElementsBoundByIndex.contains { $0.label.contains("Operation cancelled") })
        XCTAssertTrue(app.toolbars.buttons["Retry Failed"].exists, "Cancelled images can be retried")
    }

    @MainActor
    func testSettingsAndOutputFolderPersistAcrossLaunches() throws {
        let fixture = try UITestFixture(imageCount: 1)
        self.fixture = fixture
        var app = XCUIApplication.launchPixelDiet()
        app.chooseOutputFolder(fixture.output)
        XCTAssertTrue(app.staticTexts["Compressed"].waitForExistence(timeout: 5))
        app.selectOutputFormat("WebP")
        app.buttons["1,280 pixels"].click()
        let skipIfLarger = app.windows.firstMatch.switches.element(boundBy: 1)
        skipIfLarger.click()
        XCTAssertEqual(skipIfLarger.value as? Int, 0)
        app.terminate()

        app = XCUIApplication.launchPixelDiet(freshSettings: false)
        let window = app.windows.firstMatch
        XCTAssertTrue(app.staticTexts["Compressed"].waitForExistence(timeout: 10), "Output folder restored")
        XCTAssertEqual(window.popUpButtons.firstMatch.value as? String, "WebP")
        XCTAssertEqual(window.textFields.firstMatch.value as? String, "1,280")
        XCTAssertEqual(window.switches.element(boundBy: 1).value as? Int, 0)
    }

    @MainActor
    func testAboutAcknowledgementsHelpAndSettings() throws {
        let app = XCUIApplication.launchPixelDiet()

        // The app menu's item; the Window menu lists the About window too, like every Window scene
        let appMenu = app.menuBars.menuBarItems["PixelDiet"]
        appMenu.click()
        appMenu.menuItems["About PixelDiet"].click()
        XCTAssertTrue(app.staticTexts["Version 1.1.0"].waitForExistence(timeout: 5))
        app.buttons["Acknowledgements"].click()
        XCTAssertTrue(app.staticTexts["libwebp"].waitForExistence(timeout: 5))
        app.buttons["Done"].click()
        app.buttons["OK"].click()
        XCTAssertTrue(app.staticTexts["Version 1.1.0"].waitForNonExistence(timeout: 5))

        // Help lives in the standard Help menu, next to the support and privacy links
        let helpMenu = app.menuBars.menuBarItems["Help"]
        helpMenu.click()
        for item in ["Contact Support", "Report a Bug", "Privacy Policy"] {
            XCTAssertTrue(helpMenu.menuItems[item].exists, "Help menu offers \(item)")
        }
        helpMenu.menuItems["PixelDiet Help"].click()
        XCTAssertTrue(app.staticTexts["Keyboard Shortcuts"].waitForExistence(timeout: 5))
        app.buttons["Done"].click()
        XCTAssertTrue(app.staticTexts["Keyboard Shortcuts"].waitForNonExistence(timeout: 5))

        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["Settings are saved automatically and restored the next time you open PixelDiet."]
            .waitForExistence(timeout: 5))
    }

    @MainActor
    func testClosedWindowReopensFromWindowMenuWithQueueIntact() throws {
        let fixture = try UITestFixture(imageCount: 2)
        self.fixture = fixture
        let app = XCUIApplication.launchPixelDiet()
        app.addAllImages(in: fixture.input)
        XCTAssertTrue(app.staticTexts["2 images"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.windows.firstMatch.title, "PixelDiet", "Named for the Window menu, Mission Control and VoiceOver")

        app.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(app.windows.firstMatch.waitForNonExistence(timeout: 5))

        app.menuBars.menuBarItems["Window"].click()
        app.menuBars.menuItems["PixelDiet"].click()
        XCTAssertTrue(app.staticTexts["2 images"].waitForExistence(timeout: 5), "The queue survives closing the window")
    }

    /// Labels, contrast, hit regions, clipped text and traits, in the empty and the filled state
    /// and in Settings, in Light and Dark Mode
    @MainActor
    func testMainWindowPassesTheAccessibilityAudit() throws {
        continueAfterFailure = true  // Report the issues of every state, not only the first
        let fixture = try UITestFixture(imageCount: 2)
        self.fixture = fixture
        for appearance in [["-NSRequiresAquaSystemAppearance", "YES"], ["-AppleInterfaceStyle", "Dark"]] {
            let app = XCUIApplication.launchPixelDiet(arguments: appearance)
            try app.auditAccessibility()

            app.addAllImages(in: fixture.input)
            XCTAssertTrue(app.staticTexts["2 images"].waitForExistence(timeout: 15))
            try app.auditAccessibility()

            app.typeKey(",", modifierFlags: .command)
            XCTAssertTrue(app.staticTexts["Settings are saved automatically and restored the next time you open PixelDiet."]
                .waitForExistence(timeout: 5))
            try app.auditAccessibility()
            app.terminate()
        }
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
