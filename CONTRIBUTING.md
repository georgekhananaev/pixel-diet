# Contributing to PixelDiet

Thanks for your interest in contributing to PixelDiet! This document outlines how to get involved.

## Before You Start

By submitting a contribution (pull request, patch, or suggestion), you agree to assign all rights, title, and interest in that contribution to George Khananaev, as outlined in the [LICENSE](LICENSE).

## Getting Started

1. Fork the repository
2. Clone your fork and create a new branch:
   ```bash
   git clone https://github.com/<your-username>/PixelDiet.git
   cd PixelDiet
   git checkout -b feature/your-feature-name
   ```
3. Open `PixelDiet.xcodeproj` in Xcode 16+ (Swift 6.2 required)
4. Make your changes
5. Run tests: Product > Test (Cmd+U)
6. Commit and push to your fork
7. Open a pull request against `main`

## Development Requirements

- **macOS 14.0+** (Sonoma)
- **Xcode 16+** with Swift 6.2 support
- No external dependencies to install - everything is built-in

## Project Structure

```
PixelDiet/
├── Models/          # Data models (ImageItem, BatchJob, ImageFormat, etc.)
├── Views/           # SwiftUI views
│   └── Components/  # Reusable UI components
├── ViewModels/      # MainViewModel, SettingsViewModel
├── Services/        # ImageCompressor, BatchProcessor, ThumbnailService, etc.
│   └── Protocols/   # ImageCompressing, ImageAnalyzing
└── Utilities/       # Constants, error types, path sanitizer, logger
```

## Code Guidelines

### Swift 6.2 Concurrency

This project uses Swift 6.2 Approachable Concurrency with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. This means:

- All types are **implicitly `@MainActor`** unless explicitly marked otherwise
- Services that run in background `TaskGroup` child tasks **must** be marked `nonisolated` (e.g., `ImageCompressor`, `ImageAnalyzer`, `PathSanitizer`)
- `@Observable` classes **never cross actor boundaries** - use `Sendable` structs (`ImageTask`, `SettingsSnapshot`) instead
- Error types and result types thrown/returned from background tasks must be `nonisolated` and `Sendable`

### General Rules

- **No external dependencies** - use only Apple frameworks (exception: libwebp for WebP encoding)
- **App Sandbox** - all file access must go through `NSOpenPanel` or security-scoped bookmarks
- **Memory efficiency** - use `CGImageSourceCreateThumbnailAtIndex` for resizing, never load full bitmaps when avoidable
- **Atomic writes** - always write to temp file first, then atomic move
- **Localization ready** - use `String(localized:)` for all user-facing strings
- Follow existing code style and naming conventions

### What Not to Do

- Don't add network access or analytics
- Don't add external package dependencies without discussion
- Don't break App Sandbox compliance
- Don't add `@MainActor` annotations on types that are already implicitly MainActor (everything is, under Swift 6.2)

## What to Contribute

### Good First Contributions

- Bug fixes with test coverage
- Accessibility improvements (VoiceOver labels, keyboard navigation)
- Localization / translations
- Test coverage improvements
- Documentation

### Larger Contributions

For larger features, please open an issue first to discuss the approach before writing code. This saves everyone time.

## Reporting Bugs

Open an issue at [GitHub Issues](https://github.com/georgekhananaev/pixel-diet/issues) with:

- macOS version
- Steps to reproduce
- Expected vs. actual behavior
- Crash logs if applicable (from Console.app, subsystem `com.georgekhananaev.PixelDiet`)

## Code of Conduct

Be respectful, constructive, and collaborative. Focus on the code, not the person.
