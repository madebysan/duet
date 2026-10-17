# Changelog

## 2026-10-17

- Renamed the app to Duet (home-screen name, in-app header, VoiceOver label, logs). Internal Xcode project, target, and bundle id still use MixLayer.
- Replaced the app icon with the two-overlapping-records design and regenerated every icon size from the 1024 px master.
- Rebuilt the UI as one screen with a CD library: discs slide out of their case and spin while playing, a drag-to-set volume bar, Sounds and Your files tabs.
- Added generated white, pink, and brown noise as built-in looping sounds; Rain, Forest, and Ocean are placeholders.
- Your files are remembered across launches; added Loop one, Play all, and Shuffle; removed folder import.
- Fixed play doing nothing on first launch, no resume after interruptions, and swipe-to-delete not working.
- Added a unit test target for playback logic.
- Added placeholder art printed on each built-in sound's disc (rain, forest, ocean, and grain textures), replaceable in `Assets.xcassets/DiscArt`.
- Built and installed on san's iPhone.

## 2026-05-28

- Created the MixLayer iOS app as a personal device build.
- Added mixable audio playback so the app can play under YouTube or another audio app.
- Added folder library import, recursive subfolder scanning, shuffle, previous/next, play/pause, progress, and volume control.
- Added metadata-driven UI using title, artist, album, artwork, duration, and artwork-derived accent color.
- Added local metadata caching for repeat folder use.
- Reworked the UI spacing and control sizes after physical-device screenshots.
- Added `Pick Files` as a fallback for Google Drive and other providers that do not allow folder selection.
- Generated and installed a bitmap app icon.
- Built and installed the app on san's connected iPhone.
- Moved the project into `~/Projects/layer-player`.
