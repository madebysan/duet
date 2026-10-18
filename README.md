<p><img src="assets/app-icon.png" width="128" height="128" alt="Duet app icon"></p>

<h1>Duet</h1>

<p>Play local audio quietly under another iPhone app.<br>
Built for music, loops, and audiobooks while YouTube or another audio app keeps playing.</p>

<p><strong>Version 0.1</strong> · iOS 17+ · personal device build</p>

<p>
  <img src="https://img.shields.io/badge/Swift-f05138" alt="Swift">
  <img src="https://img.shields.io/badge/SwiftUI-0066cc" alt="SwiftUI">
  <img src="https://img.shields.io/badge/iOS-000000" alt="iOS">
</p>

![Duet on iPhone: Steady rain looping at 45% inside the volume dial, Synth ocean at 70%, and the Your files sheet with two demo files](assets/screenshot.png)

Duet uses a mixable `AVAudioSession` so its audio keeps playing when another app starts audio: YouTube, Podcasts, Spotify, anything. iOS normally lets these apps interrupt each other; Duet runs under them.

Everything is on one screen: a CD in the middle of a volume dial (drag the ring to set the level), swipe to change discs, and a big play button. Each built-in sound (noise, rain, forest, ocean) has its own vinyl disc that glows and spins while playing. Files you add from Files, iCloud, or Google Drive each become a disc of their own and are remembered across launches. One disc plays at a time, and it loops until you change it.

Not on TestFlight or the App Store. Personal build signed to a connected iPhone.

## Project Walkthrough

| File | Role |
|---|---|
| `MixLayerApp.swift` | App entry point. Creates `AudioPlayerModel`, boots the library on launch, supports `--autoplay-sample` for QA (plays the first sound). |
| `AudioPlayerModel.swift` | Core model: mixable audio session, built-in sounds, your files with bookmarks, looping, volume, interruptions, lock-screen controls. |
| `PlaybackLogic.swift` | Pure, unit-tested logic: disc order for next/previous, volume stepping, dial geometry, disc spin math. |
| `SoundCatalog.swift` | Built-in sounds, their categories, disc finishes, and `DiscAccent` (glow colour picked from each disc's art). |
| `AudioTrack.swift` | `AudioTrack` for a sound or a file; `load()` reads file metadata and covers. |
| `FLACTags.swift` | Reads FLAC titles, artists, albums and covers, which Apple's metadata API skips. |
| `AudioMetadataCache.swift` | On-device metadata cache so reopening the same files is fast. |
| `ContentView.swift` | Main screen (header, volume dial around the disc carousel, transport) and the Your files sheet. |
| `DiscViews.swift` | Disc face, spinning disc, and the carousel disc. |
| `scripts/crop-disc-art.swift` | Crops a generated top-down vinyl photo to a tight square for `Assets.xcassets/DiscArt`. |
| `scripts/generate-disc-art.swift` | Renders placeholder disc art for any sound that doesn't have an image yet; keeps existing images unless `--force`. |
| `scripts/cut-cc0-loops.sh` | Cuts the shipping loops (up to 10 minutes each) from the CC0 Freesound recordings listed in `MixLayer/Resources/Sounds/CREDITS.md`. |
| `scripts/cut-personal-loops.sh` / `cut-loop.py` | Cuts seamless, level-matched loops from san's downloaded recordings into the git-ignored `MixLayer/PersonalSounds/` (Debug builds only). `cut-loop.py` also cuts the licensed loops in `MixLayer/Resources/Sounds/`. |
| `project.yml` | XcodeGen source. Re-generate with `xcodegen generate` if changed. |

## Agent Onboarding

If you are starting work on Duet, read these first in order:

1. **`AGENTS.md`**: build and install commands, constraints (`.mixWithOthers`, file picking, looping)
2. **`plan.md`**: current state, what was verified, next steps
3. **`backlog.md`**: upcoming work by area

## Build

`AGENTS.md` has the exact device-build and install commands. General flow:

```bash
xcodegen generate
xcodebuild -project MixLayer.xcodeproj -scheme MixLayer -destination 'platform=iOS,id=00008150-000A48500132401C' -derivedDataPath build/DerivedData -allowProvisioningUpdates build
xcrun devicectl device install app --device CFC63A02-476D-534D-A1FC-815D2D8EF980 build/DerivedData/Build/Products/Debug-iphoneos/MixLayer.app
```

Clean build if you hit stale caching:

```bash
rm -rf build/DerivedData
```

## Key Constraints

- **Do not remove `.mixWithOthers`.** Playing under other apps is the whole point of Duet.
- **Import by picking files only.** Folder import was removed on 2026-10-17.
- **Google Drive support stays as file-picker fallback** unless Drive API integration is explicitly requested.
- **Never commit `build/`** or DerivedData.

---

Made by [santiagoalonso.com](https://santiagoalonso.com)
