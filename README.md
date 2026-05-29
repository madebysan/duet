<p><img src="assets/app-icon.png" width="128" height="128" alt="MixLayer app icon"></p>

<h1>MixLayer</h1>

<p>Play local audio quietly under another iPhone app.<br>
Built for music, loops, and audiobooks while YouTube or another audio app keeps playing.</p>

<p><strong>Version 0.1.0</strong> · iOS 17+ · personal device build</p>

<p>
  <img src="https://img.shields.io/badge/Swift-f05138" alt="Swift">
  <img src="https://img.shields.io/badge/SwiftUI-0066cc" alt="SwiftUI">
  <img src="https://img.shields.io/badge/iOS-000000" alt="iOS">
</p>

![MixLayer player screen](artifacts/visual-qa/03-bottom-aligned.jpg)

MixLayer uses a mixable `AVAudioSession` so its audio keeps playing when another app starts audio — YouTube, Podcasts, Spotify, anything. iOS normally lets these apps interrupt each other; MixLayer runs under them.

The library picks one folder (recursive) or individual files. Metadata (title, artist, album, artwork, accent color) is scanned and cached locally. Google Drive requires the `Pick Files` button because Drive often greys out folder access in the Files provider.

Not on TestFlight or the App Store. Personal build signed to a connected iPhone.

## Project Walkthrough

| File | Role |
|---|---|
| `MixLayerApp.swift` | App entry point. Creates `AudioPlayerModel` as a `@StateObject`, boots the library on launch, supports `--autoplay-sample` arg for QA. |
| `AudioPlayerModel.swift` | Core model — audio session config, file import, queue management, playback controls, metadata caching. |
| `AudioTrack.swift` | `AudioTrack` struct with URL, metadata, play status. The `load()` factory reads audio metadata. |
| `AudioMetadataCache.swift` | Simple on-device cache so switching back to the same folder or files is faster. |
| `ContentView.swift` | Main UI — player view, track queue sheet, library source picker. |
| `project.yml` | XcodeGen source. Re-generate with `xcodegen generate` if changed. |

## Agent Onboarding

If you are starting work on MixLayer, read these first in order:

1. **`AGENTS.md`** — build/install commands, constraint rules (`.mixWithOthers`, folder mode, etc.)
2. **`plan.md`** — current state, verification commands, known open questions
3. **`backlog.md`** — upcoming work organized by area

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

- **Do not remove `.mixWithOthers`** — this is the entire point of the app.
- **One active library**, not a multi-folder queue.
- **Google Drive support stays as file-picker fallback** unless Drive API integration is explicitly requested.
- **Never commit `build/`** or DerivedData.

Made by [santiagoalonso.com](https://santiagoalonso.com)
