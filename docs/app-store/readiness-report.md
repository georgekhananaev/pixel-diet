# PixelDiet 1.1.0 - Mac App Store Readiness Report

**Date:** 2026-11-04 (Phase 4; earlier passes 2026-10-18 to 10-21) · **Version:** 1.1.0 (build 2) · **Bundle ID:** `georgekhananaev.PixelDiet` · **Minimum macOS:** 14.0 · **Verified with:** Xcode 27.1, macOS 27.0 SDK, on macOS 26.6

## Verdict

**The app is ready for submission.** Every code, configuration and asset item is done, and the full Xcode test plan passes on the real sandboxed app (2026-10-21), including the accessibility audit in Light and Dark Mode. The Phase 2 pass (2026-10-20) fixed launch, background, colour, orientation, queue, wording, contrast and structure issues. The Phase 3 pass (2026-10-21) closed every minor the earlier reviews had deferred, and its own fresh review was fixed too. The Phase 4 pass (2026-11-04) re-checked everything against Apple's current rules: a new icon without the Apple-like apple, a fix for the macOS 27 SDK open-panel change, a support page, and corrected wording. Each fix had a failing test first where a test is possible. The account steps remain:
- commit and push this round's changes, so the Support URL (`SUPPORT.md`) and the updated privacy policy are live
- create the App Store Connect record and fill in the metadata (all values in `metadata.md`)
- distribution-sign, validate and upload from Organizer
- do a final TestFlight check on a Mac running macOS 27, the version App Review uses

See [`submission-checklist.md`](submission-checklist.md).

| Area | Status |
|---|---|
| Build (Debug, Release), static analyzer | Pass, 0 compiler and analyzer warnings in every target (2026-11-04, after the last change) |
| App information (build settings) | Category Photography, display name, copyright, export compliance, min macOS 14.0, 1.1.0 (2) - checked in the archived `Info.plist` |
| Unit tests | 2026-11-04, sandboxed app host: 110 tests, 109 passed, 1 skipped by design (external-volume test, needs a second volume), after the review fix; the full test plan earlier the same day: 119 tests, 117 passed, 2 skipped by design |
| UI tests on the real sandboxed app | 2026-11-04: 9 passed (compress/preview/conflicts, rename and retry, cancel, persistence, About/Help/Settings, window reopen, accessibility audit in Light and Dark Mode, launch), 1 skipped by design (screenshot capture, run separately) |
| Release archive | 1.1.0 (2), rebuilt 2026-11-04: universal (x86_64 + arm64), min macOS 14.0, SDK 27.0 (Xcode 27.1), hardened runtime, sandbox entitlements only, no quarantine attribute, Icon Composer icon compiled into `Assets.car` |
| Archived app launch | 2026-11-04: opens its window; no sandbox denials, errors, faults or crash reports; quits cleanly |
| Screenshots | 5 real-app captures from 2026-11-07 with the final mosaic icon in the toolbar, 2880×1800 (Retina, 16:10), RGB without alpha |
| Privacy policy and support URLs | Privacy policy returns 200; the updated text and `SUPPORT.md` go live with your next push |
| Independent code review | Phase 1: 5 Important fixed. Phase 2: 1 Critical (WebP transparency) and 5 of 10 Minor fixed with tests. Phase 3: every deferred minor closed; its review (1 Important, 9 Minor) fixed with tests except 2 Minor recorded below. Phase 4: review found 1 Important (the output-folder rule was stated backwards in the app and in `SUPPORT.md`) and 9 Minor; all fixed, the Important one test-first |

## What the app is

PixelDiet is a single-window, sandboxed SwiftUI/AppKit batch image compressor. You add files or folders by drag and drop or the open panel. You choose an output folder, format, quality, maximum size and metadata options, then compress. Results appear per file and per run, with a Before/After preview.

- **Architecture:** MVVM, Swift 6 with MainActor default isolation. A `BatchProcessor` actor runs a `nonisolated` `ImageCompressor` (ImageIO plus libwebp) with memory-aware admission. Settings are stored as JSON in UserDefaults; the output folder is a security-scoped bookmark.
- **Not present (checked):** backend, accounts, payments or IAP, subscriptions, ads, analytics, user-generated content, web views, push notifications. No data is collected; the only network-capable code paths open links in the browser.

## Apple requirements: what applies and the decision

| Requirement | Applies? | Decision / evidence |
|---|---|---|
| App Sandbox (Guideline 2.4.5(i)) | Yes | Enabled with only `files.user-selected.read-write` and `files.bookmarks.app-scope`. The UI tests confirm that open-panel grants, output writes and bookmark restore all work inside the sandbox. |
| Built and submitted with Xcode; no updater or downloaded code (2.4.5) | Yes | Archive built with Xcode 27.1; no installer, updater or downloaded code. |
| Minimum Xcode/SDK for uploads | macOS has no SDK floor | Apple's April 2026 and April 2027 SDK rules cover iOS, iPadOS, tvOS, visionOS and watchOS only; the stated macOS floor is Xcode 14. The archive uses Xcode 27.1 and the macOS 27.0 SDK, accepted for uploads since October 15, 2026. |
| Runs on the currently shipping macOS (2.4.5(viii)) | Yes | macOS 27 is current. Built with its SDK; the one macOS 27 SDK behavior change that affects PixelDiet (open panel folder selection) is fixed; a unit test checks that folders are an allowed type, which keeps them selectable however AppKit derives the flags. This Mac runs macOS 26.6, so seeing it work on macOS 27 is a TestFlight check. |
| Privacy manifest | Yes | No tracking and no collected data. UserDefaults: `CA92.1`. File metadata of user-selected files: `3B52.1`. A scan found no other required-reason or networking APIs. |
| Third-party SDK manifests/signatures | No | libwebp is not on Apple's list and is compiled from source. |
| App Privacy label | Yes | "Data Not Collected": all processing happens on the device. |
| Privacy policy in App Store Connect **and in the app** (5.1.1(i)) | Yes | Help ▸ Privacy Policy in the app; the URL returns 200. |
| Accurate metadata (2.3) | Yes | Deployment target 14.0 matches the stated requirement. Store copy describes only verified behavior, and screenshots are captures of the real app. |
| App completeness (2.1) | Yes | Every advertised feature works in the real app (UI-tested): preview, reveal output, retry, cancel, persistence. |
| Accounts, account deletion, Sign in with Apple, IAP, UGC | No | None present. |
| Export compliance | Yes | `ITSAppUsesNonExemptEncryption = NO`. |
| Notifications | No usage string on macOS | Permission is requested lazily, before the first background-completion notification. |
| Screenshots: 16:10, no alpha | Yes | 5 at 2880×1800, RGB. |
| Age rating | Yes | 4+ (every capability "No", including the social media question required since September 2026; every content descriptor "None"). |
| EU DSA trader status | Yes | You must declare it in App Store Connect. |
| Accessibility Nutrition Labels | Optional | Voluntary, and publishable only after release. Labelled controls, Escape-to-close sheets, secondary-label contrast; claim features only after the checks in `metadata.md`. |
| Window menu and Help (HIG, common rejections) | Yes | Single `Window` scene listed in the Window menu, reopened by the Dock; standard Help menu with real help, support, bug report, source and privacy links. |
| Category | Yes | Xcode: Photography; App Store Connect: Photo & Video (Apple has no "Photography" category there). |
| libwebp BSD-3 notice | License condition | Shown in About → Acknowledgements (UI-tested). |
| App icon | Yes | Icon Composer icon (`AppIcon.icon`, no Apple-like motif): macOS 26+ draws it in the system shape and styles, and Xcode generates the 16-1024 px icon for macOS 14/15 into `Assets.car` plus `AppIcon.icns`. |
| Trademarks (5.2.5) | Yes | The 1.0.0 icon, a rainbow-striped apple with a leaf, resembled Apple's logo; replaced by a mosaic of rainbow pixels that slim down from big to tiny (pixels on a diet). |
| Support URL with contact details (1.5) | Yes | `SUPPORT.md`: email, bug reports, FAQ (live once pushed). |

## Issues found and fixed

Every fix below except R5 has a test that failed before the fix. R5 is a view-only change, verified by building; C12 (undefined behavior) was found by reading the code.

**App Store blockers**

| # | Issue | Fix |
|---|---|---|
| B1 | Deployment target 26.2, while README and CI promise macOS 14 | 14.0 in all configurations; builds against SDK 27 with no availability errors |
| B2 | Privacy policy URL 404 | PRIVACY.md updated; **you need to push** |
| B3 | The advertised Before/After Preview was unreachable | Opens by double-click, Return, Space, and the right-click and ⋯ menus (UI-tested) |
| B4 | Output files were never recorded, so "Reveal Output" never appeared and the preview spun forever | Recorded from the processor result; status placeholders added |
| B5 | Screenshots were not an accepted size | Real-app captures at 2880×1800 |
| B6 | Version and build not prepared | 1.1.0 (2) |

**Critical defects (wrong output, lost data, broken flows)**

- **C1 WebP edges:** semi-transparent images saved as WebP got darkened edges.
- **C2 WebP orientation:** rotated photos saved as WebP with metadata kept came out sideways.
- **C3 External drives:** Overwrite failed on another volume with `EXDEV`.
- **C4 Skip If Larger:** it could delete a file you had chosen to overwrite.
- **C5 Persistence:** settings and the output folder were never restored.
- **C6 Retry:** Retry Failed never counted its results.
- **C7 Conflict skips:** images skipped in the conflict dialog were not counted.
- **C8 PPM:** the "Original" format failed for PPM files.
- **C9 Cancel:** cancelling left the counts inconsistent.
- **C10 Totals:** removing images left the totals wrong.
- **C11 Memory sizing:** concurrency was sized from compressed file size.
- **C12 WebP pointer:** undefined behavior in the WebP writer pointer.
- **C13 Path check:** the output path check could be escaped (`/out` matched `/out2`).
- **C14 Non-images:** non-image files were imported as 0×0 images.

**Found by the independent code review**

- **R1 Rename:** "Vacation-12" became "Vacation-13". It now becomes "Vacation-12-1".
- **R2 Case collisions:** two images whose names differed only by letter case overwrote each other's output.
- **R3 Mixed batches:** batches of large and small images exceeded the memory budget. Each image is now admitted by its own estimated memory.
- **R4 1.0.0 bookmark:** 1.0.0 saved bookmarks of *input* folders under the output-folder key, so 1.1.0 would have used one as the output folder. The old key is discarded, and only folders are accepted.
- **R5 Mid-run folder change:** changing the output folder mid-run revoked access to the folder being written. The button is disabled while a batch runs.

**Found by testing the real app in Xcode** (invisible to the earlier SwiftPM harness)

- **U1 Double-click preview:** double-clicking a row never opened the preview, because the table consumed the clicks. It now uses the native `contextMenu(forSelectionType:primaryAction:)`, which also adds Return-to-preview and multi-selection "Remove N from Queue". Verified with real mouse and keyboard events.
- **U2 Import order:** images were listed in reverse or random order, because the open panel returns selections unordered. They are now always in Finder-style name order.
- **U3 Missing-file message:** a source file deleted after it was added failed with "Image has invalid dimensions". It now says "The original file was moved or deleted".
- **U4 Test leftovers:** unit tests left empty preference files in the app's real container. Tests now use in-memory storage and leave nothing behind.
- **U5 Completion sound:** the sound was loaded with `NSSound` on the main thread at the end of every run, which Xcode's Thread Performance Checker flagged as a UI-stall risk. Bisecting confirmed it was the only source. It now plays as a system sound off the main thread.

**Found in the Phase 2 pass (2026-10-20)**

- **L1 Windowless launch:** restoring window state could bring back no window at all; the main window now always opens at launch.
- **L2 Background batches:** App Nap slowed batches while the window was hidden, the Mac could idle-sleep mid-batch, and macOS could quit the windowless app and drop the queue. A batch now holds a user-initiated activity, and automatic termination is off.
- **R1/R2 Menus:** no way back to a closed window, and the standard Help menu was missing. Now Window ▸ PixelDiet, the Dock, File ▸ Add Images…/Choose Output Folder…, and Help ▸ PixelDiet Help with support links. Quitting mid-batch asks first.
- **E1 Black backgrounds:** transparent images saved as JPEG, HEIC or BMP were black; they are placed on white.
- **E3/E5 Colour:** "keep metadata" dropped everything for WebP, and "strip" did not convert wide-gamut images to sRGB. Keep now keeps metadata and the colour profile (WebP via ICCP/XMP); strip converts to sRGB.
- **E4/E6/E7 Orientation and size:** portrait photos showed sideways dimensions; with metadata kept, BMP and AVIF came out sideways and GIF could be turned twice; HEIC kept the original pixel size. Every format is now written upright, with correct metadata.
- **Q1-Q6 Queue:** run numbers reused after Clear All, removal mid-run, a misleading overwrite prompt for duplicate names, leftover temp files after a crash, completion sound for cancelled runs, and an import indicator that ended early - all fixed; Remove and Clear All can be undone.
- **W1/A1 Wording and contrast:** "1 images" and similar; captions at very low contrast. Plural-aware strings, locale-aware numbers and times, secondary-label captions, labelled slider/size field/presets.
- **Review C1 WebP transparency:** the WebP encoder drew over uninitialised memory, so from the second image of a batch on, transparent areas could show the previous image. The buffer is now cleared first (`webpTransparentAreasStayClearAfterAnOpaqueImage`).
- **Review M6 HDR/float images:** extended-range images were not placed on white and failed as WebP; they are drawn in sRGB now.
- **P1/P2/S1 Performance and structure:** thumbnails at 96 px instead of 200 px; quiet bookmark resolution at launch; WebP at libwebp's default effort (~4% smaller files); the app file holds only scenes and commands; shared settings controls; app information moved into build settings with a shared scheme.

**Found in the Phase 3 pass (2026-10-21)**

- **Cancel while preparing:** Cancel and Quit did nothing while a run checked destinations or while the "File Already Exists" dialog was open. One task now covers preparation and compression, Cancel closes the dialog, and the dialog has **Stop Compressing** (Cmd+.). The fresh review found that a prompt could still appear right after Cancel; it no longer does (`noConflictPromptAppearsAfterCancel`).
- **Quit:** quitting mid-batch waited without limit if a write hung (a network share that went away); it now waits at most 10 seconds.
- **Undo mid-run:** Redo after an Undo in the middle of a run did nothing and lost the step. Redo now takes out exactly what Undo put back, never images the run is writing.
- **Numbered names:** with Overwrite All, two images sharing an output name created `a-2.jpg`, `a-3.jpg`, … on every run. The numbered name now goes through the conflict policy, and Rename picks the next free number (`a-2.jpg`, not `a-1-1.jpg`).
- **Output folder:** a read-only folder or volume failed every image with the same error; one message now appears before the run. The check creates and removes a hidden file, because permission checks can be wrong on network volumes.
- **Source files:** a file replaced after it was added was compared (Skip If Larger) and reported with its old size, and a symbolic link was measured as the link (8 bytes).
- **Memory:** admission assumed 4 bytes per source pixel. Peaks measured on 24 and 48 MP photos in a release build are 13 B/px at full size (23 for 16-bit), about 28 per output pixel when downscaled (with a floor for progressive JPEG and interlaced PNG), WebP 24 (45 with transparency) and AVIF 75 MB + 14 B/px. Admission now uses these, within a quarter of the Mac's memory. The WebP encoder also needs about a fifth less memory, with byte-identical output.
- **Responsiveness:** existing-file and free-name checks run off the main thread; a finished image redraws only its row and run header.
- **Transparency note:** shown only when a queued image would actually lose its transparency, including with Original (e.g. transparent HEIC).
- **Preparation display:** images in a new run showed last run's checkmarks while the run was being prepared.
- **Accessibility (from the first full UI run, 2026-10-21):** the audit found unnamed elements (the image list, the format pop-up, a decorative icon read by its symbol name) and Light-Mode text below 4.5:1 - the system secondary label is 3.95:1 there, green about 2:1. Text and status colors now come from one palette that is at least 4.5:1 in both modes (`PaletteTests`), the elements are named, and the audit passes in Light and Dark Mode. Skipped as macOS's own: AppKit's unnamed containers around SwiftUI content, title-bar buttons, the menu bar, and "Action is missing" on SwiftUI's menu Picker (check VO-Space before claiming VoiceOver).

**Found in the Phase 4 pass (2026-10-23 to 2026-11-04, fresh compliance scan against Apple's current rules)**

- **Icon resembling Apple's logo (Guideline 5.2.5):** the 1.0.0 icon was a rainbow-striped apple with a leaf. On your decision it is now a mosaic of rainbow pixels that slim down from big to tiny (pixels on a diet), in the same palette, running to the icon's edges. (A first replacement, a pixel landscape photo, was rejected by you: it did not fill the icon and did not say "diet".)
- **Icon on macOS 26 and later:** the old full-canvas PNG icon was shrunk onto a gray plate, while Apple's icons fill the shape. The new icon is an Icon Composer file, so the system draws it in its own shape and in the default, dark and tinted styles. Xcode generates the macOS 14/15 icon from the same file.
- **macOS 27 SDK open panel:** built with the macOS 27 SDK, setting the allowed file types now also decides whether files and folders are selectable (Apple's release note 6938919). Add Images listed only images and set them last, so on macOS 27, the version App Review uses, folders could no longer be picked. Folders are now an allowed type and the flags are set afterwards (`addImagesPanelAcceptsImagesAndFolders`).
- **Output-folder message (found by the Phase 4 review):** the error said the output folder "cannot be inside the input folder", the opposite of the rule the code applies (a folder inside is allowed; the images' folder and any folder containing it are refused). The message now states the real rule and is defined once (`outputFolderMayBeInsideTheImagesFolderButNotContainIt`, RED then GREEN); the review notes and `SUPPORT.md` say the same.
- **Support URL (Guideline 1.5):** the GitHub issue tracker showed no contact details. `SUPPORT.md` now gives the email, bug reports and a FAQ, and it is the Support URL.
- **Privacy policy (5.1.1(i)):** added an email contact and how to remove the preferences and output-folder bookmark PixelDiet keeps.
- **IDE git error ("unable to normalize alternate object path"):** the JetBrains project mapped two nested git repositories inside a stale build folder copied from the old Mac. Those mappings and the stale folder are removed, and build folders are excluded in the IDE.

**Polish and maintainability**
- **Import feedback:** a loading state during import, and a message when nothing importable was added.
- **Output folder check:** a preflight check for a missing or unmounted output folder.
- **Accessibility:** labels on icon-only buttons and Escape-to-close; savings below 100% never display as "100%".
- **Layout:** preview columns aligned; the About layout fixed.
- **Docs:** Help and README are accurate.
- **Dead code and concurrency:** dead code removed; Swift 6 data-race warnings fixed.
- **Reproducible builds:** libwebp pinned to 1.6.0 and `Package.resolved` tracked.
- **CI:** builds, analyzes and runs the unit tests on the macOS 26 runner (on the macOS 15 image, actool crashes compiling the Icon Composer icon); the UI journeys run locally before each release.

## Verification

**UI journeys** (the real sandboxed app, driven through the real open panels):
1. **Compress, preview, conflicts:**
   - empty state, with Compress disabled
   - choose the output folder, then add 4 photos, which are listed in name order
   - WebP output: 4 `.webp` files written to disk, every row Completed
   - preview by double-click (closed with Escape), by Space (closed with Close) and by the right-click menu
   - compress again, choose Skip All: "4 skipped", and the existing files are left alone
   - Delete removes a row; Clear All empties the queue; ⌘Z brings the images back
2. **Rename and retry:**
   - an existing output is kept and the new file becomes `IMG_0001-1.jpg`
   - a deleted source fails with the "moved or deleted" message
   - once the file is restored, Retry Failed compresses it, and the button disappears
3. **Cancel:**
   - a 41-image batch of 48 MP photos is cancelled with ⌘.
   - fewer than 41 outputs are written
   - nothing is left "Processing", the "Operation cancelled" images are listed, and Retry Failed is offered
4. **Persistence:** after a relaunch the format, size preset, the Skip If Larger toggle, and the output folder (security-scoped bookmark resolved in the sandbox) are restored.
5. **Secondary windows:**
   - About shows "Version 1.1.0"
   - Acknowledgements lists libwebp
   - Help shows the keyboard shortcuts
   - Settings (⌘,) opens
6. **Launch:** launch performance, and launch screenshots in each appearance.
7. **Window reopen:** with 2 images queued, Cmd+W closes the window and Window ▸ PixelDiet brings it back with the queue intact; the window is named "PixelDiet".
8. **Accessibility audit** in Light and Dark Mode: the empty window, the queue and Settings.
9. **App Store screenshots** (run on request): the five store images at the display's resolution (2880×1800 on a 2x display).

**Other checks:**
- **Unit tests in the sandboxed host:** encoding (alpha, orientation, overwrite, skip-if-larger, PPM, resize, missing source), batch accounting and memory admission, view-model journeys on real files, persistence, analyzer, paths.
- **Release archive:** inspected (version, architectures, minimum macOS, SDK, linked libraries, signature) and launched.

**Phase 2 checks (2026-10-20):**
- Window at launch, after a normal quit, after a forced quit with the window closed, and when upgrading over state saved by the committed 1.0-era build (`WindowGroup`): the window always opens; the Dock reopens a closed window.
- Automatic termination: with the window closed the system log shows `_kLSApplicationWouldBeTerminatedByTALKey=0` (it was 1).
- Power assertion during a batch: checked by a unit test through IOKit.
- ImageIO behaviour per format (orientation tags, EXIF sizes) probed directly before the fixes; WebP effort chosen by benchmark (numbers in the plan).
- Settings window rendered offscreen in light and dark mode: the new row fits.

**Phase 3 checks (2026-10-21):**
- Peak memory (`phys_footprint` sampled every 0.5 ms, release build) for every output format, with and without resizing, 8- and 16-bit, progressive, interlaced, alpha, P3 and HEIC sources; the fresh reviewer re-measured independently with the same results.
- WebP output before and after the encoder change compared byte for byte (opaque, alpha, P3 with metadata, quality 50/80/100): identical.
- "File Already Exists" dialog rendered offscreen in light and dark mode with Stop Compressing: fits.
- Archived app launched (on a 2x display): opens its window; no errors, faults, sandbox denials or crash reports.

**Phase 4 checks (2026-11-04):**
- Icon: compiled with actool and in the Release build; `NSWorkspace` draws it filling the macOS 26 icon shape (default and dark styles) next to Calculator, with no gray plate; `Assets.car` holds the icon stack plus 16-1024 px renditions for macOS 14/15; its pixel grid stays visible at 32 px (16 px shows the color gradient). The generator reproduces the committed files byte for byte. Archive rebuilt after the final icon: universal, no quarantine, window opens, quits cleanly, no crash reports.
- macOS 27 SDK release notes read in full for AppKit and SwiftUI changes: the open-panel change is the only one that alters PixelDiet's behaviour; context-menu symbols are hidden by default (cosmetic, as Apple's HIG intends); drops use `onDrop`, which is unaffected.
- The UI tests' changes to PixelDiet's real preferences were rolled back: identical to the backup taken before the run.

**Not verifiable here (your test run and TestFlight pass):**
- **Finder drag and drop:** the UI tests used the open panel.
- **Notification prompt:** the background-completion notification and its permission prompt.
- **External drives:** an exFAT/FAT drive inside the sandbox (the harness verified only an APFS second volume, unsandboxed).
- **macOS 27 (the shipping version App Review uses):** this Mac runs 26.6; check Add Images with a folder and the icon in the Dock on macOS 27.
- **Older macOS:** behavior on macOS 14 and 15 machines, including the icon Xcode generates for them.
- **Upgrade from 1.0.0:** installing over the DMG.
- **Distribution signing and App Store Connect validation:** these need your account in Organizer.

## Remaining blockers (yours)

1. **App Store Connect:** create the record; set pricing (Free), App Privacy, age rating and EU trader status; enter the metadata, screenshots and review notes.
2. **Archive → Validate → Upload** from Organizer (it handles distribution signing).
3. **TestFlight check** on a real Mac (list above), then **Submit**.

## Decisions made on your behalf

| Decision | Why | Cost if wrong |
|---|---|---|
| No commits | Your CLAUDE.md rule | You review one large diff before committing |
| Images listed in Finder-style name order, regardless of selection order | The open panel returns selections unordered, so name order is the only predictable rule | People who expect their drag order |
| `startCompression()` / `retryFailed()` return when the run ends | Deterministic tests without test-only APIs; the UI already wraps them in a Task | None |
| A destination-path error fails only that image | Avoids aborting the whole batch with images stuck as "Processing" | A different error surface |
| CI runs unit tests only | UI journeys take minutes and need an interactive session | UI regressions are caught locally rather than in CI |
| UI tests isolate settings with launch arguments | The test runner can't edit the sandboxed app's preferences | Tests write their settings into the app's real preferences (cleaned up after this session) |
| One `Window` scene plus a launch fallback, not a `WindowGroup` | A single window can't be duplicated; macOS 14 has no `defaultLaunchBehavior` | A rare windowless launch if SwiftUI changes its delegate (the Dock still reopens) |
| Photos always written upright (orientation tag reset to 1) | Several writers lose or double the tag | The original tag value isn't kept; the picture looks the same |
| "Strip EXIF Metadata" converts to sRGB | Same colours in every browser, smaller files | Wide-gamut colours are mapped into sRGB; 16-bit sources become 8-bit |
| Automatic termination off | The queue lives only in memory | An idle, windowless PixelDiet stays in memory |
| WebP method 4 (libwebp default) | ~4% smaller for ~45 ms more per 1920 px image | WebP batches about 25% slower end to end |
| Dragging compressed files out of the list not built | Only claimed in the 1.0.0 changelog, not in README or store copy | A missing nice-to-have |
| Quit waits at most 10 s for images being written | A write can hang on a lost network share | A single write slower than 10 s is abandoned at quit; its hidden temp file is removed by a later run |
| Redo takes out exactly what Undo put back | Works in the middle of a run without touching it | Redo of Clear All keeps images added after the Undo |
| Memory budget: a quarter of the Mac's memory, with measured per-image peaks | Large unresized or WebP batches stay out of swap | Fewer images in parallel on 8 GB Macs for full-size WebP batches |
| Full-size images still decoded with the thumbnail API | Direct decoding would save memory but keeps CMYK and 16-bit pixel formats that the store text and tests describe; end-to-end time is the same | About 4 B/px more peak memory for unresized images |
| Text and status colors from one palette, darker than the system colors in Light Mode | The system secondary label is 3.95:1 and green about 2:1 in Light Mode, below the 4.5:1 text needs; Dark Mode keeps the system colors | Light-Mode captions and badges look slightly darker than stock macOS |
| The accessibility audit skips four macOS-owned issues | AppKit's containers around SwiftUI content, title-bar buttons and the menu bar are not the app's; SwiftUI's menu Picker reports "Action is missing" | A real problem of that kind would go unreported; the pop-up still needs a VoiceOver check before claiming VoiceOver |
| Files chosen directly (not in a folder) are accepted whenever ImageIO reads them, e.g. PSD or RAW, and saved as JPEG with Original | Harmless extra capability; the store copy lists only the verified formats | Folder scans pick only the listed formats |
| The Icon Composer icon is also the source of the macOS 14/15 icon | Apple offers no supported way to ship a `.icon` file and a separate asset-catalog icon; Xcode generates the older-OS icon from the `.icon` | macOS 14/15 show Xcode's rendering of the same artwork, with a glass edge |
| README screenshots replaced by the store screenshots | The March images showed the apple icon and outdated UI text | None |
| The old apple icon scripts in `scripts/` (`generate_icon_v4.py`, `generate_5_icons.py`) left in place | They are untracked local files of yours; `generate_app_icon.py` makes the new icon | Running them would bring the apple back (into a folder that no longer exists) |

**Deferred minors** (not fixed; none blocks submission):
- **Skipped after a file change:** when a source was replaced after it was added and is then skipped by Skip If Larger, its row keeps the old size (completed images update it).
- **Redo of Clear All after a new run:** Clear All, Undo, compress, Redo keeps the newer run's summary, which reappears once images are added again.
- **Launch bookmark:** the output-folder bookmark is still resolved on the main thread at launch, but no longer shows UI or mounts volumes, so it cannot wait on a missing drive.

The other Phase 1 and Phase 2 minors (import progress gap, removal during a run, thumbnail size, leftover temp files, plurals, cancelled-run sound, WebP metadata, long lists, the overwrite edge case, undo during a run, cancel while preparing, quit feedback, the memory estimate) are fixed.

## Sources (official Apple)

- App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Upcoming requirements: https://developer.apple.com/news/upcoming-requirements/
- Upload builds: https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds
- Privacy manifest files: https://developer.apple.com/documentation/bundleresources/privacy-manifest-files · Required reason APIs: https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- Third-party SDK requirements: https://developer.apple.com/support/third-party-SDK-requirements/
- App privacy details: https://developer.apple.com/app-store/app-privacy-details/ · Manage app privacy: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy
- App information: https://developer.apple.com/help/app-store-connect/reference/app-information/app-information · Version information: https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
- Screenshot specifications: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- Age ratings: https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions
- Export compliance key: https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption
- Preparing for distribution / App Sandbox: https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution · https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox
- Notarization (not used for the Mac App Store): https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- EU DSA trader requirements: https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements
- Accessibility Nutrition Labels: https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels
