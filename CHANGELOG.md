# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/), [SemVer](https://semver.org/)

## [Unreleased]

### Added
- **ui**: Per-run history tracking — each compression run shows as collapsible row with format, quality level, stats, and elapsed time
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

### Changed
- **perf**: Rewrite WebP encoder using advanced libwebp API (WebPConfig + WebPMemoryWriter) — 2-3x faster encoding
- **perf**: Use RGBX import for opaque images, skip alpha channel processing
- **perf**: Switch ImageListView from ScrollView+LazyVStack to native List for instant selection
- **ui**: Wider settings sidebar (280-400px, was 220-320px)
- **models**: Add RunSummary model for per-run stat tracking
- **models**: Add batchRunId and outputFormatUsed to ImageItem for run grouping

### Fixed
- **models**: Savings calculation now only counts completed items (was incorrectly including all queued items)
- **models**: Add completedOriginalSize counter for accurate savings math
- **ui**: Remove stale "X selected" toolbar label
- **perf**: CompressionSettings didSet infinite recursion replaced with explicit setter methods
