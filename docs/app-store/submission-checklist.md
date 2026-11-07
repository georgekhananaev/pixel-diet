# PixelDiet 1.1.0 - Mac App Store Submission Checklist

Remaining steps need your Apple Developer account, App Store Connect, your authentication on this Mac, or a business decision. Everything verifiable locally has been done; see `readiness-report.md`.

## Already done and verified on this Mac (Xcode 27.1, macOS 27 SDK)

- [x] Debug and Release builds and the static analyzer: 0 warnings.
- [x] App information in the build settings: category Photography, display name, copyright, `ITSAppUsesNonExemptEncryption = NO`, minimum macOS 14.0, version 1.1.0 (2). Shared scheme added to the project (in your uncommitted changes).
- [x] Release archive `PixelDiet.xcarchive` 1.1.0 (2): universal x86_64 + arm64, sandbox entitlements only (user-selected files, app-scoped bookmarks), no quarantine attribute.
- [x] The archived app launches straight into its window with no sandbox denials, errors, faults or crash reports.
- [x] Unit tests (SwiftPM harness with the Xcode 27.1 toolchain, 2026-10-21): 102 tests, three consecutive runs, all pass except the plural-text test, which needs the app host; the plurals were checked in the built app instead.
- [x] Privacy policy URL returns 200 (pushed 2026-10-20). The updated `PRIVACY.md` in your working tree is published with your next push.
- [x] Screenshots captured from the real app on 2026-11-07, with the final `logo-agy04` icon in the toolbar: `docs/app-store/screenshots/` (2880 x 1800 Retina, no alpha).
- [x] Full test plan in Xcode on 2026-11-04: 119 tests, 117 passed, 0 failed, 2 skipped by design (screenshot capture, external-volume test) - every unit test in the sandboxed host (including the macOS 27 open-panel guard), 9 UI journeys including window reopen, the Help menu and the accessibility audit in Light and Dark Mode. 0 compiler warnings.
- [x] New Icon Composer icon (`PixelDiet/AppIcon.icon`, your `logo-agy04` artwork on a navy plate) compiles without warnings (2026-11-07): macOS 26 draws it filling the icon shape in light and dark icon styles; the macOS 14/15 renditions (16-1024 px) are in `Assets.car`.

## 1. Tests and screenshots (done; repeat before each release)

- [x] Test automation approved on this Mac (2026-10-21).
- [x] Run the whole test plan: Product ▸ Test in Xcode (Cmd+U), or `xcodebuild test -project PixelDiet.xcodeproj -scheme PixelDiet -destination 'platform=macOS'`.
- [x] Recapture the App Store screenshots whenever the UI changes: `TEST_RUNNER_PIXELDIET_SCREENSHOTS=1 xcodebuild test -project PixelDiet.xcodeproj -scheme PixelDiet -destination 'platform=macOS' -only-testing:PixelDietUITests/AppStoreScreenshots -resultBundlePath shots.xcresult`, then `xcrun xcresulttool export attachments --path shots.xcresult --output-path ~/Desktop/shots` and copy the five PNGs (named in its `manifest.json`) over the files in `docs/app-store/screenshots/`. They come out without alpha, at 2880 x 1800 on this Mac's 2x display (1440 x 900 on a 1x display; both accepted).

## 2. Developer account and App Store Connect

- [ ] Agreements, tax and banking in App Store Connect → Business. The free-app agreement is enough for a free app. Accept the latest Apple Developer Program License Agreement (updated October 13, 2026) in the developer account first; pending agreements block submissions.
- [ ] Create the app: Apps → + → New App.
  - Platform **macOS**, name `PixelDiet`, primary language English (U.S.)
  - Bundle ID `georgekhananaev.PixelDiet` (register it under Certificates, Identifiers & Profiles if it isn't listed; no extra capabilities are needed)
  - SKU `pixeldiet-mac`
- [ ] App Information: category **Photo & Video** (secondary Graphics & Design), Content Rights, age rating (every answer No/None → 4+): fill from `metadata.md`.
- [ ] Pricing (Free) and Availability (all countries; China mainland needs an ICP filing number).
- [ ] App Privacy: "Data Not Collected" → Publish; Privacy Policy URL from `metadata.md`.
- [ ] Declare EU Digital Services Act trader status (Business → Compliance). It is required even if you don't distribute in the EU. Do it first: trader verification has been taking weeks.
- [ ] Commit and push this round's changes (including the new `SUPPORT.md` and the `docs/` folder) so the Support URL and the README screenshots resolve, then fill the version 1.1.0 page: description, keywords, promotional text, support and marketing URLs, and copyright `2026 George Khananaev` from `metadata.md`.
- [ ] Upload the 5 screenshots from `docs/app-store/screenshots/`.
- [ ] App Review Information: your contact details (phone with a leading `+`) and the notes from `review-notes.md`.

## 3. Archive, validate, upload

- [ ] In Xcode: scheme PixelDiet, destination **Any Mac (Apple Silicon, Intel)**, then Product → Archive.
- [ ] Organizer → select the 1.1.0 (2) archive → **Validate App** → App Store Connect.
  - With automatic signing, Xcode creates or uses the Apple Distribution certificate and the Mac App Store provisioning profile for you.
- [ ] Organizer → **Distribute App** → App Store Connect → Upload. Wait for the "build processed" email.

## 4. TestFlight check, then submit

- [ ] Install the TestFlight build on a Mac running **macOS 27**, the currently shipping version that App Review tests on (Guideline 2.4.5(viii)), and ideally also on macOS 14 or 15 (minimum is 14.0). Check:
  - On macOS 27: File ▸ Add Images… lets you select a **folder** as well as images (the macOS 27 SDK changed how the open panel decides what is selectable; covered by `addImagesPanelAcceptsImagesAndFolders`, but this Mac runs macOS 26).
  - The Dock and Finder show the new icon filling the macOS icon shape, with no gray plate around it.
  - Add photos by drag and drop from Finder (the UI tests use the open panel).
  - Compress, preview, and relaunch: the output folder is remembered.
  - Close the window, then reopen it from Window ▸ PixelDiet and from the Dock: the queue is still there.
  - Start a long batch and press Cmd+Q: PixelDiet asks first; Quit stops after the images being written (at most 10 seconds).
  - Compress into a folder that already holds the outputs: in "File Already Exists", Stop Compressing ends the batch and nothing is written.
  - Overwrite into an output folder on an **exFAT/FAT external drive**.
  - While a long batch runs, switch to another app. When it finishes, the notification permission prompt and then the notification should appear.
  - Turn on VoiceOver and add, compress and preview images (needed before claiming VoiceOver in the Accessibility Nutrition Labels).
  - On a Mac that ran the **1.0.0 DMG**: after installing 1.1.0, the main window opens and the sidebar shows "No output folder selected", not one of your input folders.
- [ ] Select the build on the 1.1.0 version page, choose manual or automatic release, then Add for Review → Submit.
- [ ] After release: optionally publish the Accessibility Nutrition Labels (see `metadata.md`).

## Notes

- Notarization is not used for Mac App Store builds.
- For future updates, increment `CURRENT_PROJECT_VERSION` for every upload and `MARKETING_VERSION` for every release.
- Run the UI tests locally before each release. CI runs only the unit tests.
- The UI tests save the format and output folder they choose into PixelDiet's real preferences (the sandboxed app's preferences can't be isolated from the test runner). Choose your own output folder again afterwards.
- Retina (2880 x 1800) screenshots need a 2x display; on a 1x display the same command gives 1440 x 900, which is accepted too.
