# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/), [SemVer](https://semver.org/)

## [Unreleased]

## [1.1.0] - 2026-11-04

### Added
- **app**: New app icon, rainbow pixel blocks pinched toward a glowing center, on a navy plate, made with Icon Composer and filling the whole icon shape: macOS 26 and later show it in the system icon shape and styles (the navy plate stays in Dark Mode), and macOS 14 and 15 get a matching icon generated from it
- **docs**: SUPPORT.md with contact details and answers to common questions (the App Store support page)
- **privacy**: PrivacyInfo.xcprivacy declaring UserDefaults (CA92.1) and file metadata of user-selected files (3B52.1)
- **privacy**: PRIVACY.md privacy policy, linked from the Help menu
- **ui**: Before/After Preview opens by double-clicking an image, pressing Return or Space, or choosing Preview from its menu
- **ui**: Right-click menu works on the selection; with several images selected it offers "Remove N from Queue"
- **ui**: Preview shows the reason when an image was skipped or failed, or that it has not been compressed yet
- **ui**: "Adding images…" progress while folders are scanned, and a message when nothing importable was dropped
- **ui**: Acknowledgements sheet in About with the libwebp license
- **app**: Standard Help menu with PixelDiet Help (Cmd+?), Contact Support, Report a Bug, GitHub Repository and Privacy Policy
- **app**: File menu items Add Images… (Cmd+O) and Choose Output Folder… (Cmd+Shift+O)
- **app**: Closing the window keeps the queue; Window ▸ PixelDiet or the Dock icon brings it back
- **app**: Quitting during a batch asks first, then lets the images being written finish (waiting at most 10 seconds, in case a write hangs)
- **ui**: The "File Already Exists" dialog has Stop Compressing (Cmd+.) to end the batch
- **ui**: Undo and Redo for Remove and Clear All (images return to their places, with their run history)
- **compression**: "Keep metadata" keeps the original color profile, also for WebP (ICC profile and XMP metadata); CMYK images are converted to sRGB
- **ui**: Escape closes the preview and detail sheets; accessibility labels on icon-only buttons
- **settings**: All settings and the output folder are remembered across launches (stale folder bookmarks are refreshed; bookmarks left by 1.0.0, which recorded input files, are discarded)
- **tests**: Compression engine, batch processor, view-model pipeline, persistence and analyzer test suites
- **tests**: UI test journeys that drive the real sandboxed app: compress/preview/conflicts, rename and retry, cancel, settings persistence across relaunch, About/Help/Settings, window reopen, an accessibility audit in Light and Dark Mode; plus an opt-in App Store screenshot capture

### Changed
- **privacy**: PRIVACY.md gives a contact email and explains how to remove the preferences PixelDiet keeps on your Mac
- **project**: Minimum macOS is now 14.0 (was 26.2), matching the documented requirement
- **project**: libwebp-Xcode pinned to 1.6.0; Package.resolved is now tracked for reproducible release builds
- **project**: App category (Photography), display name, copyright and export compliance are build settings (no hand-written Info.plist); shared scheme for CI and fresh clones
- **compression**: Photos are always saved upright: the EXIF orientation is applied to the pixels in every format (BMP, AVIF and GIF cannot carry it reliably)
- **compression**: "Strip EXIF Metadata" also converts colors to sRGB
- **compression**: WebP uses libwebp's default effort (method 4): about 4% smaller files
- **perf**: Compression keeps full speed while the window is hidden (no App Nap), the Mac does not idle-sleep mid-batch, and macOS never quits PixelDiet on its own while it holds a queue
- **perf**: List thumbnails are decoded at 96 px instead of 200 px (about a quarter of the memory)
- **perf**: The output folder bookmark is resolved without UI or mounting network volumes at launch
- **perf**: Each image is admitted to the batch by its measured peak memory for the size it is resized to (decoding 8- and 16-bit, progressive and interlaced sources; WebP with or without transparency; AVIF), within a quarter of the Mac's memory and one image per core, instead of a concurrency limit derived from compressed file size
- **perf**: WebP encoding needs about a fifth less memory (no extra full-size pixel copies); the output is byte-for-byte the same
- **perf**: Checking for existing output files and free numbered names runs off the main thread, so the window stays responsive with thousands of images on a network folder
- **perf**: A finished image redraws only its row and run header, not the whole list
- **perf**: Preview decodes downsampled images instead of full-resolution files
- **app**: Dock badge, completion sound, haptics and the background notification moved into one feedback component; notification permission is requested only when a notification is about to be shown
- **ui**: Imported images are listed in Finder-style name order (the open panel returns selections in arbitrary order)
- **ui**: Retry Failed starts a new run and is shown only while images have failed
- **ui**: Cancel waits for in-flight images and reports every unfinished image as cancelled
- **ui**: Help lists every format and the real keyboard shortcuts; Settings window labels no longer say "Default"
- **ui**: Savings below 100% never display as "100%"
- **ui**: Counts read "1 image", "1 item", "Compress 1 Image"; savings percentages and run times use the system's number and time formats
- **ui**: Higher-contrast captions, labelled quality slider, size field and presets for VoiceOver; the sidebar and Settings window share the same controls
- **ui**: The "Transparent areas become white" note appears only when a queued image would lose its transparency in the format it is saved in (also with Original, e.g. for transparent HEIC)
- **ui**: Text and status colors have at least 4.5:1 contrast in Light and Dark Mode: secondary text, savings badges, run counts and status icons use darker shades in Light Mode (the system secondary label is 3.95:1 there, green about 2:1); the conflict dialog keeps standard button text with colored icons
- **ui**: VoiceOver names for the image list and the Output Format pop-up; decorative icons are hidden from VoiceOver
- **ci**: CI runs build, static analysis and unit tests on the macOS 26 runner (the macOS 15 image cannot compile the Icon Composer icon); the UI journeys run locally before each release

### Fixed
- **app**: The Add Images panel keeps folders selectable when built with the macOS 27 SDK, where AppKit derives the selectable item kinds from the allowed file types
- **compression**: WebP output of semi-transparent images had darkened edges (premultiplied alpha passed as straight alpha)
- **compression**: Rotated photos converted to WebP with "Strip EXIF Metadata" off came out sideways
- **compression**: Overwriting files on another volume (e.g. an external drive) failed with "Cross-device link"
- **compression**: "Skip If Larger" could delete an existing output file that the user chose to overwrite
- **compression**: "Original" output format failed for PPM sources instead of falling back to JPEG
- **compression**: Undefined behavior from an escaping pointer in the WebP memory writer
- **viewmodels**: Retry Failed never counted its results and could leave images stuck as "processing"
- **viewmodels**: Images skipped in the conflict dialog were not counted in their run
- **viewmodels**: Completed images never recorded their output file, so Reveal Output and the preview's compressed side never worked
- **viewmodels**: Removing images left the total size in the title and footer unchanged
- **viewmodels**: A missing or unmounted output folder now shows one clear error instead of failing every image
- **viewmodels**: Compute relative paths from input root for preserve directory structure (was always nil)
- **services**: Non-image files (e.g. .txt) dropped onto the app were added as 0x0 images
- **compression**: A source file deleted after it was added failed with "Image has invalid dimensions"; it now says the original file was moved or deleted
- **app**: The completion sound was loaded on the main thread at the end of every run (flagged by Xcode's Thread Performance Checker); it now plays as a system sound off the main thread
- **services**: Output paths are checked by path components, so a relative path cannot escape into a sibling folder
- **ui**: The Delete-key shortcut on the toolbar Remove button could steal Backspace from text fields
- **viewmodels**: Rename turned names ending in a number into a different number ("Vacation-12" became "Vacation-13", "2024-05-01" became "2024-05-2"); it now appends "-1", "-2", ...
- **viewmodels**: Two images whose names differed only by letter case overwrote each other's output in the same batch
- **ui**: Choosing a new output folder is disabled while a batch is writing to the current one
- **ui**: Open Output Folder now opens correct directory (was opening input folder due to bookmark overwrite)
- **ui**: Swift 6 data-race warnings in both drop handlers
- **compression**: Remove force unwrap on CGColorSpace in stripAlpha
- **ui**: Remove force unwraps in ImageListView and the About view
- **compression**: Transparent images saved as JPEG, HEIC or BMP got a black background; they are now placed on white
- **compression**: WebP output of transparent images could show parts of the previous image in the batch (uninitialised pixel buffer)
- **compression**: HDR/float images in extended-range color spaces were not placed on white and failed as WebP
- **compression**: Kept HEIC metadata reported the original pixel size after resizing
- **services**: Portrait photos showed their stored (sideways) dimensions in the list
- **viewmodels**: Images could be removed from the queue in the middle of a run
- **viewmodels**: After Clear All, new runs reused run numbers, so Undo could merge two runs' results
- **viewmodels**: Two queued images with the same output name asked "already exists - overwrite?", then renamed anyway
- **viewmodels**: Hidden temporary files left by a crash or forced quit are removed from the output folder before the next run
- **viewmodels**: A cancelled run played the completion sound and posted "Batch complete"
- **viewmodels**: "Adding images…" ended when the first of two overlapping imports finished, and did not show while dropped files loaded
- **viewmodels**: The same file selected twice in one import was queued twice
- **viewmodels**: Cancel and Quit were ignored while a run was being prepared (checking destinations, or while the "File Already Exists" dialog was open)
- **viewmodels**: Redo after an Undo in the middle of a run did nothing and lost the step
- **viewmodels**: A read-only output folder or volume failed every image with the same error; it now shows one message before the run starts
- **viewmodels**: With Overwrite All, images sharing an output name created a new numbered file (a-2.jpg, a-3.jpg, ...) on every run instead of replacing the last run's
- **compression**: A source file replaced after it was added was compared (Skip If Larger) and reported with its old size
- **services**: A symbolic link was measured as the link (a few bytes) instead of its image, so Skip If Larger skipped it and its savings were wrong

### Removed
- **privacy**: Disk space API declaration (its only caller was unused code)
- **code**: Unused helpers (collision resolver, disk-space and writability checks, total-size helper, encoder-availability flags), the transient multi-frame warning status, unused model fields, and an analyzer protocol requirement used only through the concrete type

## [1.0.0] - 2026-03-15

### Added
- **assets**: Custom app icon - gradient feather (red/orange to teal/green) on dark grid background with color-matched glows
- **ui**: Per-run history tracking - each compression run shows as collapsible row with format, quality level, stats, and elapsed time
- **ui**: Conflict resolution sheet with 6 options (overwrite/rename/skip, each with "apply to all" variant)
- **ui**: Context menus on image rows (Reveal in Finder, Copy Path, Reveal Output, Remove)
- **ui**: Ellipsis menu button on each image row for quick actions
- **ui**: Native List selection with Cmd+click, Shift+click, Delete key support
- **ui**: Drag-out compressed files from list to Finder/Mail/Slack
- **ui**: Clickable status counts in batch progress open filtered detail sheets per run
- **ui**: Dynamic window title showing item count, total size, or compression progress
- **ui**: Dock badge progress percentage during compression
- **ui**: System notifications when batch completes in background
- **ui**: Haptic feedback and sound effect on batch completion
- **ui**: Tooltips on all settings controls
- **ui**: GPS data warning in settings (live detection, not placeholder)
- **ui**: Dismiss button on completed batch banner
- **ui**: Toolbar "Remove N" button when items are selected
- **ui**: Custom About dialog with version, build info, system details, and copy-to-clipboard
- **ui**: Help sheet with getting started guide and keyboard shortcut reference
- **ui**: Support menu with GitHub Issues and Repository links
- **ui**: Toolbar app icon in navigation bar
- **docs**: README with project overview, features, architecture, format table, and build instructions
- **docs**: CONTRIBUTING guide with Swift 6.2 concurrency rules and code guidelines
- **docs**: Non-Commercial Open Source License
- **docs**: Screenshots in README - main UI, batch results, and skip detail

### Removed
- **viewmodels**: Delete unused SettingsViewModel (functionality handled by CompressionSettings directly)
- **viewmodels**: Remove unused removeItems() from MainViewModel
- **models**: Remove unused decrementSkipped() from BatchJob

### Changed
- **project**: Updated .gitignore to ignore icon generation scripts, JetBrains IDE, and skills-lock.json
- **ui**: Increased minimum window size to 900x600
- **ui**: Menu bar Cmd+O now triggers file picker via NotificationCenter
- **ui**: Settings panel scroll improvements
- **ui**: Quality slider renders without tick marks for smoother appearance
- **ui**: Escape key dismisses conflict dialog (defaults to skip)
- **ui**: Added accessibility labels to savings indicator and compressed size
- **perf**: Bounded thumbnail loading with TaskGroup (max 8 concurrent instead of unbounded)
- **perf**: Image preview loading offloaded to detached task
- **perf**: Optimized image list section grouping to single-pass
- **services**: ThumbnailService uses Task.detached instead of @concurrent
- **services**: PathSanitizer overlap validation uses pathComponents comparison
- **services**: FileManager helpers now log errors via os.Logger
- **services**: BatchProcessor throttle loop handles cancellation safely
- **services**: BookmarkManager clears stale bookmark when access fails
- **perf**: Rewrite WebP encoder using advanced libwebp API (WebPConfig + WebPMemoryWriter) - 2-3x faster encoding
- **perf**: Use RGBX import for opaque images, skip alpha channel processing
- **perf**: Switch ImageListView from ScrollView+LazyVStack to native List for instant selection
- **ui**: Wider settings sidebar (280-400px, was 220-320px)
- **models**: Add RunSummary model for per-run stat tracking
- **models**: Add batchRunId and outputFormatUsed to ImageItem for run grouping

### Fixed
- **compression**: Strip alpha channel for opaque output formats (JPEG, BMP) to prevent ImageIO warnings and halve decode memory
- **models**: Remove force unwrap in CompressionSettings.snapshot() - returns optional instead
- **models**: Guard division by zero in ImageItem.savingsPercentage
- **ui**: Fix race condition in drag-and-drop URL collection with serial queue
- **ui**: Fix CheckedContinuation hang when conflict dialog dismissed without choice
- **ui**: Fix conflict sheet binding to properly clean up continuation state
- **ui**: Fix cancelCompression to clear isProcessing, dock badge, and mark items
- **services**: Fix WebP memory leak - WebPMemoryWriterClear now in defer block
- **services**: Add canBeOutput validation before attempting compression
- **services**: Add early dimension validation before expensive resize operation
- **services**: Add WebP buffer size overflow guard
- **settings**: Remove stale SettingsViewModel from SettingsWindow
- **ui**: Fix security-scoped resource leak in Open Output Folder button
- **ui**: Fix continuation double-resume risk in conflict sheet via single resolveConflict() method
- **perf**: Replace O(n) item lookup per completion callback with O(1) Dictionary lookup
- **models**: Savings calculation now only counts completed items (was incorrectly including all queued items)
- **models**: Add completedOriginalSize counter for accurate savings math
- **ui**: Remove stale "X selected" toolbar label
- **perf**: CompressionSettings didSet infinite recursion replaced with explicit setter methods
