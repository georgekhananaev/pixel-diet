# PixelDiet Support

PixelDiet is a free, offline batch image compressor for macOS 14 Sonoma and later.

## Contact

- **Email:** [george@khananaev.com](mailto:george@khananaev.com?subject=PixelDiet%20Support). Questions, problems and feedback are welcome; I usually reply within a few days.
- **Bug reports and feature requests:** [GitHub Issues](https://github.com/georgekhananaev/pixel-diet/issues) (needs a free GitHub account).

When you report a problem, please include your PixelDiet version (PixelDiet ▸ About PixelDiet), your macOS version, the output format and settings you used, and, if you can, a sample image that shows the problem.

## Frequently asked questions

**Where are my compressed images?**
In the output folder shown at the bottom of the sidebar. Click **Open Output Folder** after a run, or choose **Reveal Output in Finder** from an image's menu. Your original files are never changed.

**Why can't I click Compress?**
Add at least one image and choose an output folder first (**File ▸ Choose Output Folder…**).

**Which output folders can I use?**
Any folder you can write to, except the folder your images are in or a folder that contains it, so originals can never be overwritten. A new folder inside your images' folder is fine.

**Why was an image skipped?**
With **Skip If Larger** on, PixelDiet does not save a compressed copy that would be bigger than the original. Lower the quality, choose another format, or turn the option off.

**Why did a transparent image get a white background?**
PixelDiet saves JPEG, HEIC, HEIF, AVIF and BMP images without transparency, so transparent areas are filled with white. Choose PNG, WebP or TIFF to keep transparency (GIF keeps only fully transparent areas).

**Does PixelDiet keep the location and camera details of my photos?**
Not by default: **Strip EXIF Metadata** removes them and converts colors to sRGB. Turn the option off to keep metadata and the original color profile; PixelDiet then warns you when images contain GPS location data.

**What happens if a file with the same name already exists?**
PixelDiet asks whether to overwrite it, rename the new file (it gets a number) or skip it, for that file or for the rest of the batch. You can also stop compressing from that dialog.

**I closed the window. How do I get it back?**
Choose **Window ▸ PixelDiet** or click PixelDiet in the Dock. Your queue is still there.

**How do I reset PixelDiet's settings?**
Quit PixelDiet, open Terminal and run:

```
defaults delete ~/Library/Containers/georgekhananaev.PixelDiet/Data/Library/Preferences/georgekhananaev.PixelDiet
```

This removes the app's settings and the remembered output folder; your images are not affected.

## Privacy

PixelDiet works entirely on your Mac. It makes no network requests and collects no data. See the [Privacy Policy](PRIVACY.md).
