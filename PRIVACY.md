# Privacy Policy for PixelDiet

**Last updated: October 23, 2026**

## Overview

PixelDiet is a fully offline image compression application for macOS. Your privacy is important to us.

## Data Collection

PixelDiet does **not** collect or transmit any personal data. The only data it keeps is listed under [Data Stored Locally](#data-stored-locally), and it never leaves your Mac. Specifically:

- **No analytics** - No usage tracking, crash reporting, or telemetry
- **No network access** - The app makes zero network requests. All image processing happens locally on your Mac. Links in the Help menu (such as this policy) open in your web browser
- **No accounts** - No sign-in, registration, or user accounts required
- **No advertising** - No ads, no ad tracking, no ad identifiers
- **No third-party services** - The only third-party code is the open-source libwebp library, which encodes WebP images on your Mac and has no network or data-collection functionality

## Data Stored Locally

PixelDiet stores the following data on your device only:

- **User preferences** - Output format, quality, resize and metadata settings (stored in the app's preferences, never transmitted)
- **Output folder access** - A security-scoped bookmark so PixelDiet can keep writing to the output folder you chose across launches (stored in the app's preferences)

This data never leaves your Mac. To remove it, delete PixelDiet, then in Finder choose Go ▸ Go to Folder…, enter `~/Library/Containers/georgekhananaev.PixelDiet`, and move that folder to the Trash.

## Image Processing

All image compression, resizing, and format conversion is performed entirely on your Mac using Apple's native frameworks (ImageIO, Core Graphics, Accelerate) and libwebp. Your images are never uploaded, transmitted, or shared with any server or third party. PixelDiet reads only the files and folders you choose, and writes compressed copies only to the output folder you choose; your original files are never modified.

## EXIF Metadata

PixelDiet can strip EXIF metadata (including GPS location data) from images during compression. This feature is enabled by default to protect your location privacy. When you turn it off, PixelDiet warns you if any of your images contain GPS location data.

## Notifications

If a batch finishes while PixelDiet is in the background, the app may ask for permission to show a local notification on your Mac. Notifications are generated on your device and are not sent through any server. You can change this at any time in System Settings > Notifications.

## Children's Privacy

PixelDiet does not collect any data from any users, including children under 13.

## Changes to This Policy

Any changes to this privacy policy will be posted on this page with an updated date.

## Contact

For questions about this privacy policy, contact via:
- Email: [george@khananaev.com](mailto:george@khananaev.com)
- GitHub: [github.com/georgekhananaev/pixel-diet](https://github.com/georgekhananaev/pixel-diet)
- LinkedIn: [linkedin.com/in/georgekhananaev](https://www.linkedin.com/in/georgekhananaev/)

**George Khananaev**
