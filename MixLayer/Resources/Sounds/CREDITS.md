# Sound credits

Every disc that ships must have its source here: author, link, and license. Only CC0 (public domain) recordings go in this folder, so nothing needs on-screen attribution.

Each loop is saved as `<disc-id>.m4a` (the ids are in `MixLayer/SoundCatalog.swift`).

| Disc | File | Source | Author | License |
| --- | --- | --- | --- | --- |
| Rain | `steady-rain.m4a` | [steady night rain](https://freesound.org/people/chromakei/sounds/547892/) (Freesound #547892) | chromakei | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| Birds | `blackbird.m4a` | [Blackbird_Sweden_long.wav](https://freesound.org/people/calodas/sounds/188371/) (Freesound #188371) | calodas | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| Forest | `forest-wind.m4a` | [130914 Wind in pine trees, slow light, forest, pink noise Sarah's cottage ON](https://freesound.org/people/TRP/sounds/715696/) (Freesound #715696) | TRP | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| Ocean | `soft-surf.m4a` | [Gentle Ocean Waves Mix (2018)](https://freesound.org/people/esh9419/sounds/417797/) (Freesound #417797) | esh9419 | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| Creek | `creek.m4a` | [water river stream creek close soft good detail.flac](https://freesound.org/people/kyles/sounds/637960/) (Freesound #637960) | kyles | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| Coffee shop | `coffee-shop.m4a` | [Coffee shop ambience, remastered, no coughs](https://freesound.org/people/C_Rogers/sounds/512253/) (Freesound #512253, from #370973 by waweee, also CC0) | C_Rogers | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |

Downloaded 2026-10-18 as Freesound's high-quality MP3 previews (128 kbps) and cut with `scripts/cut-cc0-loops.sh`: up to 10 minutes from each recording, a 3 s crossfade at the seam, levelled to about -21 dBFS RMS, saved as 128 kbps AAC. CC0 needs no credit; it is listed here so every shipped sound can be traced.

Creek and Coffee shop were added on 2026-10-24 the same way. White, Pink and Brown noise are not recordings: they were generated with ffmpeg (`anoisesrc`, two seeds for stereo), cut with `scripts/cut-loop.py`, and matched by loudness to the recorded discs, so they have no outside source. Box breathing is san's own recording and is intentionally not listed (san, 2026-10-24).
