# How Duet works

Reference detail for the [Duet README](../README.md): the source files, how to build and test, the scripts, and the release lanes.

## Source files

The Xcode project, target and bundle id still say MixLayer, Duet's first name. Everything lives in `MixLayer/`.

| File | Role |
|---|---|
| `MixLayerApp.swift` | App entry point. Creates `AudioPlayerModel`, boots the library on launch, supports `--autoplay-sample` for QA (plays the first sound). |
| `AudioPlayerModel.swift` | Core model: mixable audio session, built-in sounds, your files with bookmarks, looping, volume, interruptions, lock-screen controls. |
| `PlaybackLogic.swift` | Pure, unit-tested logic: disc order for next and previous, volume stepping, dial geometry, disc spin math. |
| `SoundCatalog.swift` | Built-in sounds, their categories, disc finishes, and `DiscAccent` (the glow colour picked from each disc's art). |
| `AudioTrack.swift` | `AudioTrack` for a sound or a file; `load()` reads file metadata and covers. |
| `FLACTags.swift` | Reads FLAC titles, artists, albums and covers, which Apple's metadata API skips. |
| `AudioMetadataCache.swift` | On-device metadata cache so reopening the same files is fast. |
| `ContentView.swift` | Main screen (volume dial around the disc carousel, transport) and the Your files sheet. |
| `DiscViews.swift` | Disc face, spinning disc, and the carousel disc. |
| `Resources/Sounds/` | The ten shipped loops and `CREDITS.md`, which records the source and license of each one. |
| `Assets.xcassets/DiscArt/` | One square image per built-in sound; the app clips it to a circle and draws the hub over the centre. |
| `PrivacyInfo.xcprivacy` | Privacy manifest: no tracking, no collected data, UserDefaults and file-timestamp API reasons. |

`project.yml` is the XcodeGen source. Regenerate the project with `xcodegen generate` after changing it.

## Build and test

Requirements: Xcode 27 and [XcodeGen](https://github.com/yonaskolb/XcodeGen). To build for a connected iPhone:

```bash
xcodegen generate
xcodebuild -project MixLayer.xcodeproj -scheme MixLayer -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData -allowProvisioningUpdates build
```

Then install with `xcrun devicectl device install app --device <your device id> build/DerivedData/Build/Products/Debug-iphoneos/MixLayer.app`. `xcrun devicectl list devices` prints the id. If the build picks up stale caches, remove `build/DerivedData` and build again.

Unit tests cover the pure playback logic, disc glow colours and the FLAC tag reader. They run on a simulator:

```bash
xcodebuild -project MixLayer.xcodeproj -scheme MixLayer -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData-sim test
```

## Scripts

| Script | What it does |
|---|---|
| `scripts/cut-cc0-loops.sh` | Downloads nothing itself; cuts the shipped loops (up to 10 minutes each, 3 s crossfade at the seam, levelled to about -21 dBFS) from the CC0 Freesound recordings listed in `CREDITS.md`. |
| `scripts/cut-loop.py` | The loop cutter the shell scripts call: finds a quiet seam, crossfades, levels, writes AAC. |
| `scripts/crop-disc-art.swift` | Crops a generated top-down vinyl image to a tight square for `Assets.xcassets/DiscArt`. |
| `scripts/generate-disc-art.swift` | Renders placeholder disc art for any sound that has no image yet; keeps existing images unless `--force`. |

## Release lanes

`fastlane/Fastfile` holds the App Store lanes: `preflight` (tests plus a signed Release archive), `build`, `upload_testflight`, `push_metadata`, `upload_screenshots`, `readiness`, `presubmit_check`, and `submit_app_store_review`. Credentials come from a git-ignored `fastlane/.env`; `fastlane/.env.example` lists the variables. Listing text lives in `fastlane/metadata/`, the store screenshots in `fastlane/screenshots/en-US/`. Run Fastlane with `LC_ALL=en_US.UTF-8`.

## Design constraints

- `.mixWithOthers` stays. Playing under other apps is the whole point of Duet.
- Files are added by picking them. Folder import was removed on 2026-10-17 because the Files picker is enough and keeps bookmarks simple.
- One disc plays at a time, and every disc loops on its own.
- `DESIGN.md` owns the look and motion of the CD library. Read it before UI work.
