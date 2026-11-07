# PixelDiet 1.1.0 - App Store Connect Metadata (macOS)

Copy-paste values for every App Store Connect field of a first Mac App Store submission. Field rules come from Apple's App Store Connect Help (checked 2026-10-20, sources at the end); character counts were checked with a script. Items marked **OWNER** need your decision or your personal details.

## App Information

| Field | Value |
|---|---|
| Name (2-30 characters) | `PixelDiet` |
| Subtitle (≤ 30) | `Batch compress & resize images` |
| Bundle ID | `georgekhananaev.PixelDiet` (locked after the first build upload) |
| SKU | `pixeldiet-mac` (locked when the app is created; **OWNER** may choose another) |
| Primary language | English (U.S.) |
| Primary category | **Photo & Video**. Apple: "For macOS, the primary category you set in App Store Connect should match the category you set in Xcode"; the Xcode category is Photography (`LSApplicationCategoryType = public.app-category.photography`), which is Photo & Video on the App Store |
| Secondary category | Graphics & Design (optional) |
| Content Rights | "No, it does not contain, show, or access third-party content" (people's own files are not third-party content) |
| Age Rating | See [Age rating](#age-rating) → **4+** |
| License Agreement | Leave empty: Apple's standard EULA applies |
| DSA trader status | See [EU Digital Services Act](#eu-digital-services-act) (**OWNER**) |
| Korea / Vietnam / Regulated Medical Device / Made for Kids | Not applicable |

## Pricing and Availability

| Field | Value |
|---|---|
| Price | Free (only paid apps need the Paid Apps Agreement) |
| Availability | All countries or regions (**OWNER**). China mainland needs an ICP filing number; without one the app shows "ICP Filing Number Missing" and is not offered there |
| App Distribution Methods | Public (cannot be changed after approval, except to Unlisted) |
| Volume purchase, Tax Category, Last Compatible Version | Leave the defaults |

## App Privacy

App Privacy → Get Started → **"No, we do not collect data from this app"** → Save → **Publish** (the "Data Not Collected" label). Basis: PixelDiet makes no network requests (no network-client entitlement, no networking APIs), has no analytics, crash reporting, ads or accounts, and its only third-party code (libwebp) encodes images on the Mac. Apple: "Data that is processed only on device is not 'collected'."

| Field | Value |
|---|---|
| Privacy Policy URL (required) | `https://github.com/georgekhananaev/pixel-diet/blob/main/PRIVACY.md` (also linked in the app: Help ▸ Privacy Policy, as Guideline 5.1.1(i) requires) |
| Privacy Choices URL | Leave empty (no data to access or delete) |

## Age rating

The current questionnaire (required for new apps since January 31, 2026, with the social-media questions since September 2026). Labels are Apple's; the exact question sentences appear only inside App Store Connect.

| Section | Answer |
|---|---|
| In-app controls and capabilities: Parental Controls, Age Assurance, Unrestricted Web Access, User-Generated Content, Social Media, Messaging and Chat, Advertising | **No** to all (links open in the default browser, outside the app, so there is no in-app web access) |
| Profanity or Crude Humor; Horror/Fear Themes; Alcohol, Tobacco, or Drug Use or References | **None** |
| Medical or Treatment Information | **None** |
| Mature or Suggestive Themes; Sexual Content or Nudity; Graphic Sexual Content and Nudity | **None** |
| Cartoon or Fantasy Violence; Realistic Violence; Prolonged Graphic or Sadistic Realistic Violence; Guns or Other Weapons | **None** |
| Simulated Gambling; Contests | **None** |
| Health or Wellness Topics; Gambling; Loot Boxes | **No** |
| Age Categories and Override | Not Applicable; leave the Age Suitability URL empty |
| **Result** | **4+** |

## EU Digital Services Act

Required at the first submission even without EU distribution; only the Account Holder or an Admin can declare it (Business → Compliance). **OWNER decision:**

- **Non-trader:** no contact details are published. PixelDiet is free with no ads or in-app purchases, which supports this, but Apple leaves the assessment to you (revenue, commercial practice, VAT registration, acting professionally).
- **Trader:** your address (or P.O. box), phone and email are shown on EU product pages and must be verified.

Without a status the app is removed from the EU storefronts.

## Version Information (1.1.0)

| Field | Value |
|---|---|
| Version | `1.1.0` (build 2; must match the uploaded build) |
| Copyright | `2026 George Khananaev` (App Store Connect adds the ©) |
| Support URL (required) | `https://github.com/georgekhananaev/pixel-diet/blob/main/SUPPORT.md` (support email, FAQ and bug-report link, as Guideline 1.5 asks for an easy way to contact you; it returns 404 until `SUPPORT.md` is pushed) |
| Marketing URL (optional) | `https://github.com/georgekhananaev/pixel-diet` |
| What's New | Not shown for a first version; see [What's New](#whats-new-for-the-github-release-and-the-next-update) |
| Routing App Coverage File | Not applicable |
| App Previews (optional) | None |
| Version Release | **OWNER**: Manually release (recommended for a first release) or automatically after approval |
| App tags (U.S. storefront only) | Assigned by Apple after review; check them under App Information and deselect any that don't describe PixelDiet |

**Promotional Text (≤ 170, editable at any time):**

```
Shrink hundreds of photos at once. Convert to WebP, HEIC, JPEG and more, resize, and strip location data - all offline, right on your Mac.
```

**Keywords (≤ 100 bytes, no app or competitor names):**

```
compress,compressor,resize,webp,heic,avif,jpeg,png,batch,optimizer,convert,exif,shrink,photo,size
```

**Description (≤ 4000, plain text):**

```
PixelDiet makes big photos small. Drop in hundreds of images or whole folders, pick a format and quality, and PixelDiet compresses, resizes and converts them in one go, processing several images in parallel.

Everything happens on your Mac. PixelDiet works fully offline, never uploads your images, collects no data, and never changes your originals - compressed copies are saved to the folder you choose.

COMPRESS AND CONVERT
- Save as JPEG, PNG, WebP, HEIC, HEIF, TIFF, BMP or GIF, or keep each file's original format. AVIF output is available on macOS versions that can encode AVIF.
- Open JPEG, PNG, WebP, HEIC, HEIF, AVIF, TIFF, BMP, GIF and PPM files.
- Adjust quality from 10 to 100 for JPEG, WebP, HEIC, HEIF and AVIF.
- Transparent images saved in formats without transparency get a clean white background.

RESIZE
- Set a maximum longest edge, or pick a preset from 640 to 3840 pixels. Images are scaled down with their aspect ratio preserved; smaller images are left as they are.
- Large photos are downsampled efficiently while they are decoded.

PROTECT YOUR PRIVACY
- Strip EXIF metadata such as GPS location and camera details with one switch - on by default. Colors are converted to sRGB, so they look the same everywhere.
- Prefer to keep metadata? PixelDiet keeps it together with the original color profile (CMYK images become sRGB), and warns you when images contain GPS location data.
- Photos are always saved upright, never sideways.

STAY IN CONTROL
- Skip If Larger keeps any file from getting bigger.
- When a file already exists, choose to overwrite, rename or skip it - once, or for the rest of the batch.
- Recreate your folder structure inside the output folder.
- Removed images by mistake? Undo brings them back.
- Before/After Preview: double-click an image to compare the original with the result and see exactly how much space you saved.
- Run history shows the format, quality, savings and time of every run. Retry Failed runs only the images that failed.

MADE FOR THE MAC
- Drag and drop files and folders, keyboard shortcuts, Dock progress, and a notification when a batch finishes in the background.
- Batches keep running at full speed while PixelDiet is in the background.
- Your settings and output folder are remembered between launches.

PixelDiet is built with Apple's native imaging frameworks and the open-source libwebp encoder.
```

## What's New (for the GitHub release and the next update)

```
- Before/After Preview opens by double-clicking an image, pressing Space, or choosing Preview.
- Your settings and output folder are remembered between launches.
- Undo for Remove and Clear All.
- Transparent images saved as JPEG, HEIC or BMP get a white background instead of black.
- Keeping metadata now also keeps the color profile (CMYK becomes sRGB), including for WebP; stripping it converts colors to sRGB.
- Rotated photos are saved upright in every format, and portrait photos show their real size in the list.
- Closing the window keeps your queue; reopen it from the Window menu or the Dock.
- PixelDiet asks before quitting in the middle of a batch.
- Overwriting files on external drives now works.
- Retry Failed, Cancel and conflict handling keep accurate counts.
- Runs on macOS 14 Sonoma and later.
```

## App Review Information

| Field | Value |
|---|---|
| Sign-in required | No (no accounts) |
| Contact first and last name, email | **OWNER** (not shown publicly) |
| Contact phone | **OWNER**, in international format with a leading `+` (for example `+66 ...`); digits-only numbers are rejected |
| Notes (≤ 4000 bytes) | Paste the Notes block from `review-notes.md` |
| Attachment | None |

App Sandbox Information is not asked: PixelDiet uses no temporary-exception entitlements.

## Screenshots (Mac, 16:10, 1-10 images, no alpha)

Upload the five captures of the real app window in `docs/app-store/screenshots/`, made by the `AppStoreScreenshots` UI test on 2026-11-07 (with the final icon in the toolbar) at 2880 x 1800 (Retina, 16:10), RGB without alpha:

1. `01-drop-zone.png` - empty window with drop zone and settings sidebar (light)
2. `02-queue.png` - 12 photos queued with thumbnails (light)
3. `03-results.png` - completed WebP run with per-file savings and run history (light)
4. `04-preview.png` - Before/After Preview sheet (light)
5. `05-results-dark.png` - completed run in Dark Mode

The sample photos are generated by the test, so there is no third-party content. The test sizes the window to 1440 x 900 points and captures it at the display's resolution: 2880 x 1800 on a 2x display, 1440 x 900 on a 1x display (both accepted). Recreate the set any time with the command in `submission-checklist.md`.

## Accessibility Nutrition Labels (optional, after release)

Voluntary for now, and they can be published only for platforms where the app is already live, so prepare them as a draft and publish after release. Claim a feature only if every common task (first launch, adding images, compressing, preview, Settings) works with it.

| Feature (Mac) | Recommendation |
|---|---|
| Dark Interface | Claim: the app follows the system appearance with no bright flashes |
| VoiceOver | Claim after a manual pass with VoiceOver: every control is labelled (icon buttons, slider, size field, presets, format pop-up, image list) and the Xcode accessibility audit passes in Light and Dark Mode; check that the Output Format pop-up opens with VO-Space (the audit reports "Action is missing" for SwiftUI's menu Picker) and that sheets close with Escape |
| Voice Control | Claim after checking "Show names" matches the visible labels |
| Sufficient Contrast | Claim: text and status colors are at least 4.5:1 in Light and Dark Mode on the window, list and badge backgrounds (checked by `PaletteTests` and by the accessibility audit, which re-measures every flagged element) |
| Differentiate Without Color Alone | Claim: statuses use distinct icons and text, not only color |
| Reduced Motion | Claim: no problematic motion |
| Captions, Audio Descriptions | Do not claim (no audio or video) |
| Larger Text | Not offered on Mac |

## Export Compliance

`ITSAppUsesNonExemptEncryption = NO` is set in the build settings (the app, including libwebp, uses no encryption), so App Store Connect does not ask the export-compliance questions on upload.

## Sources

- App information and required properties: https://developer.apple.com/help/app-store-connect/reference/app-information/app-information , https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties
- Categories: https://developer.apple.com/app-store/categories/
- Version information: https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
- Pricing and availability: https://developer.apple.com/help/app-store-connect/reference/pricing-and-availability/app-pricing-and-availability/
- Age ratings: https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions
- App privacy: https://developer.apple.com/app-store/app-privacy-details/
- Accessibility Nutrition Labels: https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels
- EU DSA: https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/
- Screenshots: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- Release notes (phone format, no-alpha screenshots): https://developer.apple.com/help/app-store-connect/release-notes/
