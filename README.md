# GuidGen

Fast macOS GUID / UUID generator. Lives in your menu bar, pastes a new GUID into any focused app with a global keyboard shortcut.

[![Download](https://img.shields.io/github/v/release/AGrefslie/guidgen?label=Download&style=for-the-badge)](https://github.com/AGrefslie/guidgen/releases/latest)

## Features

- **Global hotkey** — press your shortcut from anywhere; a new GUID is generated and pasted into the focused application.
- **Menu bar mode** — quick generate, recent list, format/version pickers without opening the window.
- **UUID versions** — v4 (random), v7 (time-ordered, ideal as DB primary key), Nil.
- **Output formats** — `Standard`, `NoHyphens`, `{Braces}`, `(Parens)`, `Base64`, `Guid.Parse("…")` (C#), `'…'` (SQL).
- **Persistent history** — last 50 GUIDs, searchable, click to re-copy.
- **Uppercase / lowercase** toggle.

## Install

1. Download the latest `GuidGen-x.y.dmg` from [Releases](https://github.com/AGrefslie/guidgen/releases).
2. Open the DMG and drag **GuidGen.app** to `/Applications`.
3. Launch GuidGen.
4. Grant **Accessibility** permission when prompted (required for the global paste shortcut). System Settings → Privacy & Security → Accessibility → enable GuidGen.

The app is signed with a Developer ID and notarized by Apple, so Gatekeeper will accept it without warnings.

### Requirements

- macOS 13 Ventura or later.

## Usage

- Click the key icon in the menu bar → **New GUID** to copy a fresh GUID without opening the window.
- Configure a global shortcut in the main window (Settings → Global Shortcut → Set Shortcut). Press it from anywhere to paste a new GUID into the current text field.
- Pick UUID version + output format in Settings; the next generated GUID uses them.
- Browse and re-copy any of the last 50 GUIDs from the History panel.

## Build from source

Requires Xcode 16 or later.

```bash
git clone https://github.com/AGrefslie/guidgen.git
cd guidgen
open GuidGen.xcodeproj
```

Hit Run. The Debug build skips notarization and AX prompts won't grant the paste behavior unless you run from `/Applications`.

### Distribution build

The Release archive → DMG → notarize → staple pipeline lives in this repo. With a Developer ID Application certificate installed and a notarytool keychain profile named `guidgen-notary`:

```bash
xcodebuild -scheme GuidGen -configuration Release \
  -archivePath build/GuidGen.xcarchive \
  -destination 'generic/platform=macOS' archive

xcodebuild -exportArchive \
  -archivePath build/GuidGen.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist build/ExportOptions.plist

ditto -c -k --keepParent build/export/GuidGen.app build/GuidGen.zip
xcrun notarytool submit build/GuidGen.zip --keychain-profile guidgen-notary --wait
xcrun stapler staple build/export/GuidGen.app

hdiutil create -volname "GuidGen" -srcfolder build/export/GuidGen.app \
  -ov -format UDZO build/GuidGen-1.0.dmg
codesign --sign "Developer ID Application: Your Name (TEAMID)" build/GuidGen-1.0.dmg
xcrun notarytool submit build/GuidGen-1.0.dmg --keychain-profile guidgen-notary --wait
xcrun stapler staple build/GuidGen-1.0.dmg
```

A `scripts/release.sh` wrapper that bundles all of this is on the roadmap.

## Mac App Store build (optional)

The codebase supports a sandboxed App Store variant via the `APP_STORE` compilation flag. In that build, synthetic paste is disabled (since the sandbox forbids `CGEvent.post` into other apps); the global shortcut copies to the clipboard and the user pastes with ⌘V. See `Config/AppStore.xcconfig`.

## Support

If GuidGen saves you time, you can buy me a coffee — totally optional:

[buymeacoffee.com/axelgrefslie](https://buymeacoffee.com/axelgrefslie)

## License

Not yet decided. Until a `LICENSE` file is added, all rights reserved. Open an issue if you have a use case in mind.
