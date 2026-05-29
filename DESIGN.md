# MixLayer Design

## Atmosphere

Dark, quiet, and music-first. The app should feel closer to a tiny listening tool than a file manager. Artwork and metadata carry most of the visual personality, with controls staying compact and predictable.

## Colors

| Token | Value | Use |
|---|---:|---|
| `background` | `#0A0A0A` | Full-screen app background |
| `surface` | `#1A1A1A` | Icon buttons and list rows |
| `surfaceLight` | `#262626` | Secondary pills and volume capsule |
| `textPrimary` | `#FFFFFF` | Track title, key controls |
| `textSecondary` | `#9E9E9E` | Labels and metadata |
| `textTertiary` | `#616161` | Muted status text |
| `fallbackAccent` | `#1AA6FF` | Default accent when artwork has no color |

Track artwork can override the accent color. That accent is used for play state, progress, primary pills, and current-track markers.

## Typography

System fonts only. Display text uses rounded system type. Labels use monospaced system type with uppercase tracking.

| Role | Style |
|---|---|
| Track title | 27 pt, bold, rounded |
| Transport icons | 22 to 31 pt, semibold/bold |
| Header label | 13 pt, semibold, monospaced |
| Sublabel | 11 pt, semibold, monospaced |
| Track row title | 16 pt, semibold, rounded |

## Shape Language

Artwork has a large continuous radius. Transport controls are circles. Utility controls are capsules. Repeated rows use rounded rectangles with a 16 pt radius.

## Spacing Rhythm

The layout is bottom-weighted. Header, artwork, and metadata stay tighter together. Progress, transport, shuffle, and volume controls sit near the lower half so the screen does not feel top-heavy.

## Depth

Depth comes from blurred artwork in the background, soft accent glows, and subtle strokes. Avoid heavy cards or nested containers.

## Animation

Use short spring feedback for taps and play-state changes. Motion should feel responsive, not decorative.

## Patterns

| Pattern | Current decision |
|---|---|
| Library source | One folder at a time, or selected files as a provider fallback |
| Google Drive | Folder selection may be greyed out, use `Pick Files` |
| Metadata | Read once, cache locally by file path, file size, and modification date |
| Volume | Two buttons, 10% increments, visible percentage |
| Shuffle | Compact icon pill, not a wide command button |
| Empty library | Preserve the sample track until a user picks folder/files |

## Shared Components

| Component | Variants | Sizes | File | Usages |
|---|---|---|---|---:|
| `PlayerBackground` | artwork, fallback | full screen | `MixLayer/ContentView.swift` | 1 |
| `ArtworkHero` | artwork, fallback glyph | responsive square | `MixLayer/ContentView.swift` | 1 |
| `ProgressStrip` | current track | full width | `MixLayer/ContentView.swift` | 1 |
| `TransportControls` | previous, play/pause, next | circular | `MixLayer/ContentView.swift` | 1 |
| `VolumeStepper` | minus, percent, plus | capsule | `MixLayer/ContentView.swift` | 1 |
| `IconCircleButton` | folder/menu, library | 45 pt | `MixLayer/ContentView.swift` | 2 |
| `TrackQueueSheet` | library sheet | medium/large sheet | `MixLayer/ContentView.swift` | 1 |
| `TrackRow` | current, idle | 58 pt artwork row | `MixLayer/ContentView.swift` | 1 |
| `SmallArtwork` | artwork, fallback glyph | 58 pt | `MixLayer/ContentView.swift` | 1 |

## Decisions

| Date | Decision | Rationale |
|---|---|---|
| 2026-05-28 | Use a mixable playback audio session | The whole app exists to keep playing under YouTube or another audio app |
| 2026-05-28 | Keep folder mode to one active library | A queue made from multiple folders is harder to reason about and not needed |
| 2026-05-28 | Scan subfolders | Audiobooks and music libraries often nest files by author, album, or chapter |
| 2026-05-28 | Cache metadata locally | san expects to reuse a small number of folders, so repeat scans should feel fast |
| 2026-05-28 | Add file-pick fallback | Google Drive often blocks folder-level Files access on iOS |
| 2026-05-28 | Use a bitmap app icon | The app should not ship with a generic generated SVG mark |

## Anti-Patterns

- Do not bring back a huge shuffle button.
- Do not stretch the layout horizontally when the selected track changes.
- Do not stack cards inside cards.
- Do not make the UI feel like a file browser first.
- Do not add Google Drive API work unless the file-picker fallback proves insufficient.
