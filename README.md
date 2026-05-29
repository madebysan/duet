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

MixLayer is a small iOS audio player for one job: keep playing when another app starts audio. iOS normally lets Spotify, YouTube, Podcasts, and similar apps interrupt each other. This app uses a mixable audio session so its own audio can continue under YouTube, AirPods included.

The library flow is intentionally simple. Choose one folder and MixLayer scans the audio files inside it, including subfolders. If a file provider does not allow folder access, Google Drive is the common case, use `Pick Files` instead and select the tracks directly.

It reads audio metadata for title, artist, album, duration, artwork, and accent color. Metadata is cached locally so switching back to the same folders is faster.

This is not set up for TestFlight or the App Store. It is a personal build signed to a connected iPhone.

## Build

The generated Xcode project is included, and `project.yml` is the source file for XcodeGen.

```bash
xcodegen generate
xcodebuild -project MixLayer.xcodeproj -scheme MixLayer -destination 'platform=iOS,id=00008150-000A48500132401C' -derivedDataPath build/DerivedData -allowProvisioningUpdates build
```

Install the debug build on the connected phone:

```bash
xcrun devicectl device install app --device CFC63A02-476D-534D-A1FC-815D2D8EF980 build/DerivedData/Build/Products/Debug-iphoneos/MixLayer.app
```

Made by [santiagoalonso.com](https://santiagoalonso.com)
