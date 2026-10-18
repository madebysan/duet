# Changelog

## 2026-10-18

- Replaced the sound shelf and tabs with a swipeable CD carousel at the top: swipe to change discs (keeps playing if playing, loads if paused), tap the centered disc to play or pause, Your mix is the last disc.
- Removed the "Duet" title and the "Mixing with other apps" status; an error line still appears if audio fails to start.
- Removed the square cases: the carousel shows bare CDs that lift and glow when loaded.
- Moved Your files (modes, Add files, list) into its own sheet, opened from a button at the bottom of the main screen.
- New main screen ("Dial", picked from three prototypes): the disc sits inside a volume ring you drag; big percentage readout; − / play / + at the bottom; Your files as a top-right button.
- One file at a time: every disc loops on its own, and each uploaded file is its own disc. Removed Loop one / Play all / Shuffle and the single Your mix disc.
- Replaced the placeholder disc art with 16 generated vinyl records (Nano Banana Pro via Magnific), one colour story per sound.
- New app icon: two glowing translucent records (cyan and magenta overlapping into violet) on midnight navy, generated with Nano Banana Pro; all sizes regenerated, README icon re-rounded. Source kept at `artifacts/icon/duet-icon-2026-10-18-source.webp`.
- Main screen: dial, name, and controls centered as one group; the percentage readout is gone (the ring shows the level).
- Swipe anywhere, including on the name, to move one disc; the name slides out and the next slides in, so only one is ever visible.
- Each disc's glow now comes from its own art (Blackbird glows gold, not green); `DiscAccentTests` checks all 16.
- Your files show their embedded cover art on their disc, with a glow picked from the cover.
- Added FLAC support, including FLAC titles, artists, albums and covers (`FLACTags.swift`, tested with a fixture).
- Your files: a slim scrub line under the title to jump anywhere, and each file resumes where you left it.
- Thinner volume ring with a smaller knob, closer to the disc; removed the Ready / Looping / Paused labels.

## 2026-10-17

- Renamed the app to Duet (home-screen name, in-app header, VoiceOver label, logs). Internal Xcode project, target, and bundle id still use MixLayer.
- Replaced the app icon with the two-overlapping-records design and regenerated every icon size from the 1024 px master.
- Rebuilt the UI as one screen with a CD library: discs slide out of their case and spin while playing, a drag-to-set volume bar, Sounds and Your files tabs.
- Added generated white, pink, and brown noise as built-in looping sounds; Rain, Forest, and Ocean are placeholders.
- Your files are remembered across launches; added Loop one, Play all, and Shuffle; removed folder import.
- Fixed play doing nothing on first launch, no resume after interruptions, and swipe-to-delete not working.
- Added a unit test target for playback logic.
- Added placeholder art printed on each built-in sound's disc (rain, forest, ocean, and grain textures), replaceable in `Assets.xcassets/DiscArt`.
- Added ten loops cut from san's downloaded rain, forest, and ocean recordings (personal builds only, git-ignored), and grouped the shelf into Noise, Rain, Forest, Ocean.
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
