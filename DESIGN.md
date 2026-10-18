# Duet Design

## Atmosphere

Dark, quiet, and tactile. Duet should feel like a small CD player you reach for, not a file manager: open it, set the level, pick a disc, leave. Each sound is a bare CD; the disc's finish carries the color, and the screen glows faintly in that color.

Reference: Untitled's disc flows on Mobbin (iridescent discs, tactile motion). Cases were tried and removed on 2026-10-18. Fallback direction if this doesn't hold up: a TIDE-style full-screen ambient home (see `backlog.md`, UI).

## Colors

| Token | Value | Use |
|---|---:|---|
| `background` | `#0A0A0A` | Full-screen app background, disc spindle hole |
| `surface` | `#1A1A1A` | Nudge buttons, Add files, mode pills |
| `surfaceLight` | `#262626` | (spare) |
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

Discs are circles with a translucent inner ring and a dark spindle hole, shown bare (no case). Controls are circles (play, nudges, Your files). The volume control is the dial ring. Add files uses a 14 pt radius.

## Layout

Two screens. The main screen is the "Dial" direction, picked on 2026-10-18 from three prototypes (archived in `prototypes/history/duet-main-screen/`).

- **Main screen**, no title bar, top to bottom: category label (uppercase), title (30 pt), status line; the dial; the volume readout ("65%", 44 pt, with "Volume · drag the ring"); then − / play (76 pt) / + at the bottom. A Your files icon button sits top-right. A red status line replaces the normal one only if the audio session fails.
- **The dial**: a 270° ring (radius 160 pt, 7:30 to 4:30 clockwise) with 28 tick marks around the disc carousel. The ring band (126 to 188 pt from center) is the volume knob: drag along it to set the level, with a selection haptic every 5%. Touches inside the band reach the carousel: swipe to change discs, tap the disc to play or pause.
- **Your files sheet** (medium or large detent, Done to close): a note that each file is its own disc, Add files, the file list (tap to play, swipe to remove), and "Remove all files" in the ⋯ menu.

The carousel holds every available sound in category order (Noise, Rain, Forest, Ocean), then each of your files as its own burned disc, then a dashed "Add files" disc. The centered disc is 236 pt; neighbours peek in at the screen edges, scaled to 65% and darkened. One swipe moves one disc. Centering "Add files" turns the play button into "+".

## Motion

| Moment | Motion |
|---|---|
| Disc loaded | Disc lifts to full size and glows, spring (response 0.45, damping 0.82) |
| Switching discs | Swipe the carousel; the new disc lifts and glows once loaded (0.28 s after the swipe settles) |
| Play | Disc eases up to one turn per 2.6 s over 0.6 s |
| Pause | Disc spins down over 0.6 s |
| Play button, discs, Add files | Press scale to 0.92 with a short spring |
| Volume ring drag | Selection haptic every 5 percent; arc and knob follow with a 0.15 s snap |

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
| Looping | Every disc loops on its own, built-in or yours; one file plays at a time (san, 2026-10-18). Lock-screen next/previous walks the carousel order |
| Volume | Drag the dial ring to any whole percent; − and + step 1% up to 10%, then 5% |
| Long files | Elapsed of total in the subtitle, no scrubber |
| Metadata | Read once, cached locally by file path, size, and modification date |
| Removing files | Swipe a row, or "Remove all files" in the ⋯ menu |

## Shared Components

| Component | Variants | Sizes | File | Usages |
|---|---|---|---|---:|
| `DiscFace` | any `DiscFinish` | square, scales | `MixLayer/DiscViews.swift` | 2 |
| `SpinningDisc` | spinning, settling, resting | square | `MixLayer/DiscViews.swift` | 1 |
| `CarouselDisc` | loaded (glow, full size), idle, Add files (dashed, +) | 236 pt | `MixLayer/DiscViews.swift` | 1 |
| `VolumeDialView` / `DialRing` | arc tinted by the disc glow, knob, ticks | 320 pt ring | `MixLayer/ContentView.swift` | 1 |
| `DiscCarousel` | centered, side (scaled, darkened) | 236 pt discs, full width | `MixLayer/ContentView.swift` | 1 |
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
| 2026-10-18 | Main screen uses the Dial direction (ring around the disc is the volume knob) | Picked over Thumb deck and Jukebox in a three-way prototype |
| 2026-10-18 | One file at a time: every disc loops on its own; Loop one / Play all / Shuffle removed; each file is its own disc | san wants a single sound playing, whether built-in or uploaded |
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
