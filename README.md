<p align="center">
  <img src="Assets/ClosendLogo.png" alt="Closend logo" width="128" />
</p>

<h1 align="center">Closend</h1>

![swift]https://img.shields.io/badge/lang-swift-white?style=for-the-badge
![mac]https://img.shields.io/badge/for-mac-white?style=for-the-badge
![lang]https://img.shields.io/badge/lang-🇷🇺🇺🇸-white?style=for-the-badge

**Closend** is a tiny macOS utility that makes the red close button quit apps completely.

On macOS, pressing the red window button usually closes only the current window while the app keeps running in the background. Closend makes that button behave more like `⌘Q`: close the window, end the app, and keep your Dock cleaner.

## Features

- Makes the red macOS close button quit the app.
- Runs quietly in the menu bar.
- Optional Dock icon for quick access to settings.
- Launch at login support.
- App exclusions for programs that should keep the default macOS behavior.
- Works locally on your Mac.
- No accounts, analytics, ads, or cloud sync.

## Requirements

- macOS **13** or later.
- Accessibility permission.

**Closend** needs Accessibility access so it can detect when you click the red close button. It uses this permission only for its closing behavior.

## Install

Download the latest ZIP from **GitHub Releases**, unzip it, and open `Closend.app`.

On first launch, macOS may ask for Accessibility permission:

`System Settings → Privacy & Security → Accessibility → Closend`

If macOS says the app cannot be verified, right-click `Closend.app`, choose `Open`, then confirm. A fully notarized build requires an Apple Developer account.

## Build from source

```bash
chmod +x build-app.sh
./build-app.sh
open dist/Closend.app
```

The **build script** creates:

- `dist/Closend.app`
- `dist/Closend-0.10.0.zip`

## Note

Closend asks apps to quit normally. If an app has unsaved changes, macOS or the app may still show a save confirmation dialog.

<p align="center">
  <img src="Assets/star-it-please.svg" alt="Star it, please!" />
</p>
