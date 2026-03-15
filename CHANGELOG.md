# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/), [SemVer](https://semver.org/)

## [Unreleased]

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
