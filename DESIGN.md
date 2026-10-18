# Duet Design

## Atmosphere

Dark, quiet, and tactile. Duet should feel like a small CD player you reach for, not a file manager: open it, set the level, pick a disc, leave. Each sound is a bare CD; the disc's finish carries the color, and the screen glows faintly in that color.

Reference: Untitled's disc flows on Mobbin (iridescent discs, tactile motion). Cases were tried and removed on 2026-10-18. Fallback direction if this doesn't hold up: a TIDE-style full-screen ambient home (see `backlog.md`, UI).

## Colors

| Token | Value | Use |
|---|---:|---|
| `background` | `#0A0A0A` | Full-screen app background, disc spindle hole |
| `surface` | `#1A1A1A` | Nudge buttons, Your files button, Add files, file rows |
| `textPrimary` | `#FFFFFF` | Titles, play button fill, volume knob |
| `textSecondary` | `#9E9E9E` | Category label, scrub times, file details |
| `textTertiary` | `#616161` | File durations, empty Add files disc |
| `accent` | `#1AA6FF` | Playing-row waveform, fallback glow |

Each disc's glow is read from its own art: `DiscAccent` in `SoundCatalog.swift` picks the most vivid colour in the vinyl ring (saturation² × brightness, 24 hue buckets) and lifts it to a bright accent; mostly colourless art keeps a pale tint. The glow lights the disc, the ring arc, and the background. `DiscFinish.glow` is only the fallback for a sound with no art; `DiscAccentTests` checks every disc. Your files without a cover use the silver `burned` finish; a file with an embedded cover prints it on the disc and takes its glow from it.

## Typography

System fonts only, rounded design for display text.

| Role | Style |
|---|---|
| Disc title | 30 pt, bold, rounded (scales down to 70% before truncating) |
| Category label | 12 pt, semibold, uppercase, 1.2 tracking |
| Scrub times | 12 pt, medium, monospaced digits |
| Audio problem / Add files hint | 13 pt, medium |
| Your files sheet rows | 15 pt semibold title, 12 pt details |

## Shape Language

Discs are circles with a translucent inner ring and a dark spindle hole, shown bare (no case). Controls are circles (play, nudges, Your files). The volume control is the dial ring. Add files uses a 14 pt radius.

## Layout

Two screens. The main screen is the "Dial" direction, picked on 2026-10-18 from three prototypes (archived in `prototypes/history/duet-main-screen/`).

- **Main screen**, no title bar: the dial, the name block (category label and 30 pt title), a scrub row, and − / play (76 pt) / + are stacked and centered vertically as one group. No status labels (Ready, Looping, Paused): the play button and spinning disc show the state; a line under the title appears only for an audio problem or the Add files hint. No percentage readout: the ring shows the level. A Your files icon button sits top-right.
- **Scrub row (your files only)**: elapsed time, a slim 3 pt line tinted with the glow (7 pt while dragging), and the total. Drag to jump; the jump happens on release so audio doesn't stutter. VoiceOver adjusts by 15 s. For built-in sounds the row stays empty so the controls don't move.
- **Resume**: each file remembers its position (saved on pause, on switching discs, every ~5 s while playing, and when the app leaves the foreground) and continues there; positions under 5 s or within 5 s of the end start from the top (`ResumePosition`).
- **Swiping**: a horizontal swipe anywhere on the screen moves one disc (the ring band keeps its own volume drag). On the name it follows the finger a little; the old name slides out and the next slides in from the swipe direction, clipped so only one name is ever visible. The name follows the centered disc immediately; playback switches 0.28 s after the swipe settles.
- **The dial**: a thin 270° ring (radius 140 pt, 2.5 pt line, 13 pt knob, 28 small ticks; 7:30 to 4:30 clockwise) just outside the 236 pt disc. Only the knob takes touches: a 56 pt circle around it (the knob grows to 18 pt while dragging). Drag it around the ring to set the level, with a selection haptic every 5%. Taps or drags anywhere else on the ring fall through to the carousel and the swipe, so the volume can't change by accident.
- **Your files sheet** (medium or large detent, Done to close): a note that each file is its own disc, Add files, the file list (tap to play, swipe to remove), and "Remove all files" in the ⋯ menu.

The carousel holds every available sound in category order (Rain, Forest, Ocean), then each of your files as its own burned disc, then a dashed "Add files" disc. The centered disc is 236 pt; neighbours peek in at the screen edges, scaled to 65% and darkened. One swipe moves one disc. Centering "Add files" turns the play button into "+".

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
| Built-in sounds | Ten recorded loops in three groups: Rain (Steady rain, Porch rain, Rain on leaves, Gentle rain), Forest (Woodland, Blackbird, Forest wind), Ocean (Soft surf, Breakers, Beach). A disc with no audio is left out. The generated noise and synth sounds were removed on 2026-10-18 |
| Where the audio comes from | Shipping audio: a CC0 recording per disc in `MixLayer/Resources/Sounds/<id>.m4a`, sourced in `CREDITS.md` (being found, 2026-10-18). Until then Debug builds use san's personal cuts from YouTube downloads in the git-ignored `MixLayer/PersonalSounds/`; Release builds never include them |
| Choosing a sound | Swipe the carousel. Swiping while playing switches playback to the new disc; swiping while paused only loads it. Selection commits 0.28 s after the swipe settles so passing discs don't each start. |
| Disc art | Each built-in sound prints a generated vinyl image on its disc: `MixLayer/Assets.xcassets/DiscArt/disc-<sound-id>.imageset/`. Made with Nano Banana Pro in the Magnific web app from the prompts in `artifacts/disc-art/prompts.md` (top-down record, plain off-white label at about a third of the diameter, no text), then cropped with `scripts/crop-disc-art.swift`. Each category mixes vinyl techniques (splatter, smoke, marble, rings, colour-in-colour, half-and-half). A light sheen from the sound's finish is blended over the art |
| Your files | Picked with the Files picker (works with Google Drive); remembered across launches with security-scoped bookmarks. Audio already in Duet's own folder (Files › On My iPhone › Duet) is listed automatically, refreshed each time the app opens; removing one hides it (`hiddenFolderFiles`) and picking it again brings it back |
| File formats | MP3, M4A, M4B, AAC, WAV, AIFF, CAF, and FLAC (added 2026-10-18). FLAC tags and covers come from `FLACTags.swift`, since Apple's metadata API skips them |
| File covers | A file's embedded cover art is printed on its disc and drives its glow (same `DiscAccent` picker as the built-in discs); files without a cover use the silver burned disc |
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
| 2026-10-18 | Dial, name, and controls centered as one group; percentage readout removed; swipe anywhere to change disc | The ring already shows the level; a swipe on the name is the most natural way to flip discs |
| 2026-10-18 | Slim scrub line and per-file resume for your files; thinner ring closer to the disc; status labels removed | Long files shouldn't always restart; the ring and labels were heavier than needed |
| 2026-10-18 | Glow comes from each disc's art (`DiscAccent`), not a per-category colour | Blackbird is black with yellow spots and was glowing green |
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
