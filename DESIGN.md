# Duet Design

## Atmosphere

Dark, quiet, and tactile. Duet should feel like a small CD player you reach for, not a file manager: open it, set the level, pick a disc, leave. Each sound is a bare CD; the disc's finish carries the color, and the screen glows faintly in that color.

Reference: Untitled's disc flows on Mobbin (iridescent discs, tactile motion). Cases were tried and removed on 2026-10-18. Fallback direction if this doesn't hold up: a TIDE-style full-screen ambient home (see `backlog.md`, UI).

## Colors

| Token | Value | Use |
|---|---:|---|
| `background` | `#0A0A0A` | Full-screen app background, disc spindle hole |
| `surface` | `#1A1A1A` | Nudge buttons, Add files, mode pills |
| `surfaceLight` | `#262626` | Volume bar track |
| `textPrimary` | `#FFFFFF` | Titles, play button fill, selected mode pill |
| `textSecondary` | `#9E9E9E` | Subtitles, labels |
| `textTertiary` | `#616161` | "Soon" discs, durations |
| `accent` | `#1AA6FF` | Playing-row waveform, fallback glow |

Each built-in sound has a `DiscFinish` in `SoundCatalog.swift`: a sheen (colors swept around the disc), a case color (now unused), and a glow. The glow tints the top-of-screen radial light and the volume fill. Your files use the silver `burned` finish; a file with artwork uses its artwork accent instead.

## Typography

System fonts only, rounded design for display text.

| Role | Style |
|---|---|
| App title | 24 pt, bold, rounded |
| Now playing title | 22 pt, bold, rounded |
| Volume percent | 17 pt, bold, rounded, monospaced digits |
| Section label, mode pills | 13 pt, semibold |
| Subtitles, status | 12 to 13 pt, medium |

## Shape Language

Discs are circles with a translucent inner ring and a dark spindle hole, shown bare (no case). Controls are circles (play, nudges) or capsules (mode pills). The volume bar, Add files, and the Your files button use 14 to 16 pt radii.

## Layout

Two screens.

- **Main screen**, top to bottom, with no title bar: the disc carousel, the now playing title with the play button, the volume bar, and a "Your files" button pinned to the bottom (shows the file count and mode). The "Mixing with other apps" status was removed on 2026-10-18; a red line appears at the top only if the audio session fails.
- **Your files sheet** (medium or large detent, Done to close): Loop one / Play all / Shuffle, Add files, the file list, and "Remove all files". Managing your own audio is a different job from picking a background sound, so it lives here, not on the main screen.

The carousel holds every available sound in category order (Noise, Rain, Forest, Ocean), then the "Your mix" disc for your files. The centered disc is 220 pt; neighbours peek in at the sides, scaled to 74% and darkened. One swipe moves one disc. Tapping a side disc scrolls to it; tapping the centered disc plays or pauses. With no files yet, Your mix is an empty dashed disc and the play button becomes "+" to open Your files.

## Motion

| Moment | Motion |
|---|---|
| Disc loaded | Disc lifts to full size and glows, spring (response 0.45, damping 0.82) |
| Switching discs | Swipe the carousel; the new disc lifts and glows once loaded (0.28 s after the swipe settles) |
| Play | Disc eases up to one turn per 2.6 s over 0.6 s |
| Pause | Disc spins down over 0.6 s |
| Play button, discs, Add files | Press scale to 0.92 with a short spring |
| Volume drag | Selection haptic every 5 percent |

Reduce Motion turns off the spin; the slide still happens. Rotation is a pure function of time (`DiscSpin` in `PlaybackLogic.swift`), so it never drifts or jumps when pausing.

## Patterns

| Pattern | Current decision |
|---|---|
| Built-in sounds | Six generated loops: white, pink, brown noise (`scripts/generate-noise.py`) and Rain, Forest, Ocean (`scripts/generate-ambience.py`); a sound with no file shows as "Soon" |
| Personal recordings | Ten loops cut from san's downloaded YouTube references (`~/Downloads/ambient-references`): Steady rain, Porch rain, Rain on leaves, Gentle rain, Woodland, Blackbird, Forest wind, Soft surf, Breakers, Beach. Stored git-ignored in `MixLayer/PersonalSounds/` as 160 kbps AAC (about 2 MB each), copied in by a build step, hidden when absent. Personal device builds only: not licensed for the App Store |
| Choosing a sound | Swipe the carousel. Swiping while playing switches playback to the new disc; swiping while paused only loads it ("Ready"). Selection commits 0.28 s after the swipe settles so passing discs don't each start. The generated Rain, Forest, Ocean discs are named "Synth rain", "Synth forest", "Synth ocean" |
| Disc art | Each built-in sound prints an image on its disc: `MixLayer/Assets.xcassets/DiscArt/disc-<sound-id>.imageset/`. Placeholders come from `scripts/generate-disc-art.swift`; to use your own, replace the JPG (square, at least 512 px, subject centred because the middle is covered by the hub) and keep the file name, or drop in a PNG and update that imageset's `Contents.json`. A light sheen from the sound's finish is blended over the art so it still reads as a CD. "Soon" discs show their art faded |
| Your files | Picked with the Files picker (works with Google Drive); remembered across launches with security-scoped bookmarks |
| Folder import | Removed; picking files is the only import path |
| Modes | Sounds always loop one. Your files: Loop one, Play all (default), Shuffle |
| Volume | Wide fill bar, drag to any whole percent; − and + step 1% up to 10%, then 5% |
| Long files | Elapsed of total in the subtitle, no scrubber |
| Metadata | Read once, cached locally by file path, size, and modification date |
| Removing files | Swipe a row, or "Remove all files" in the ⋯ menu |

## Shared Components

| Component | Variants | Sizes | File | Usages |
|---|---|---|---|---:|
| `DiscFace` | any `DiscFinish` | square, scales | `MixLayer/DiscViews.swift` | 2 |
| `SpinningDisc` | spinning, settling, resting | square | `MixLayer/DiscViews.swift` | 1 |
| `CarouselDisc` | loaded (glow, full size), idle, empty Your mix (dashed, +) | 220 pt | `MixLayer/DiscViews.swift` | 1 |
| `VolumeBar` | tinted by glow | full width, 48 pt | `MixLayer/VolumeBar.swift` | 1 |
| `DiscCarousel` | centered, side (scaled, darkened) | 220 pt discs, full width | `MixLayer/ContentView.swift` | 1 |
| `FilesSheet` | empty state, list | medium/large sheet | `MixLayer/ContentView.swift` | 1 |
| `FilesPanel` / `FileRow` | empty state, list, current, playing | 44 pt artwork rows | `MixLayer/ContentView.swift` | 1 |
| `PressScaleStyle` | — | — | `MixLayer/ContentView.swift` | 3 |

## Decisions

| Date | Decision | Rationale |
|---|---|---|
| 2026-05-28 | Use a mixable playback audio session | The whole app exists to keep playing under YouTube or another audio app |
| 2026-05-28 | Cache metadata locally | san reuses a small set of files, so repeat loads should feel fast |
| 2026-05-28 | Use a bitmap app icon | The app should not ship with a generic generated SVG mark |
| 2026-10-17 | One screen: play, volume, then your files | The job is get in, set it, get out |
| 2026-10-18 | Swipeable disc carousel at the top replaces the shelf and tabs; no title or mixing status | Changing discs should feel like flipping through CDs, and the chrome added nothing |
| 2026-10-18 | Bare CDs, no square cases | The discs carry the identity; the cases added clutter |
| 2026-10-18 | Your files moves to its own sheet | Managing your own files is a different experience from picking a sound |
| 2026-10-17 | CD library based on Untitled's disc flows | Tactile, memorable, and each sound gets an identity |
| 2026-10-17 | Drop folder import, keep file picking only | The folder button was unreachable and Google Drive greys out folders anyway |
| 2026-10-17 | Remember picked files with bookmarks | Re-picking every launch was the biggest friction |
| 2026-10-17 | Disc stays out on pause, spins down over 0.6 s | Pauses are brief; tucking in would read as "stopped" |
| 2026-10-17 | No layering of several sounds yet | It turns one volume into several and adds a mixer screen |

## Anti-Patterns

- Do not bring back a big artwork hero, a scrubber, or previous/next buttons on the main screen.
- Do not stack cards inside cards.
- Do not make the UI feel like a file browser first.
- Do not use `.swipeActions` outside a `List`; it silently does nothing.
- Do not reassign a `@Published` property inside its own `didSet` unconditionally; it recurses and crashes.
- Do not add Google Drive API work unless the file picker proves insufficient.
