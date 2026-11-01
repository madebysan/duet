# Feedback inbox

Shake the phone in a Debug build of Duet, write what should change and tap Save. On the Mac, ask the agent to "process the feedback inbox". This is san's own tool: Release builds (TestFlight and the App Store) compile none of it, so nothing about privacy or App Review changes.

## On the phone

- Needs a Debug build installed from Xcode or `xcodebuild`.
- Shake anywhere in the app. The sheet keeps a screenshot of the screen behind it, the app's saved settings, the build and the device. Dictation works in the text box.
- Each note is saved to the app's private `Documents/Feedback/<date-time>/` as `note.md`, `screenshot.png` and `context.json`. Nothing leaves the phone until the Mac pulls it.
- Camera previews, Metal and video views can show black in the screenshot; describe what you were looking at when it matters.

## On the Mac

```bash
scripts/feedback/pull.sh
```

It finds the paired iPhone (unlocked, same Wi-Fi or plugged in), copies notes that are not already in `work/feedback/inbox/` or `work/feedback/done/`, and prints the first line of each. `--device <id>` picks a phone; `--simulator <udid>` reads a Simulator instead. `work/feedback/` is local-only, so notes and screenshots never reach Git.

## For agents: processing the inbox

When san asks to process the feedback inbox:

1. Run `scripts/feedback/pull.sh`, then take the folders in `work/feedback/inbox/` oldest first.
2. Read `note.md`, look at `screenshot.png`, and use `context.json` (settings, build, presented sheets) to find the screen and state in the code.
3. List the notes for san, numbered, one line each with your reading of the request. If one is unclear, conflicts with the project's `AGENTS.md` or plans, or touches data, permissions or anything hard to undo, ask san before changing code.
4. Make the changes san approves, build, and install on the phone when san needs to try them. One note per change so each can be kept or undone on its own.
5. When san approves a change, commit only its files (`Feedback <id>: <what changed>`), write a one-line `result.md` in the note's folder with the commit, and move the folder to `work/feedback/done/`. A rejected note also moves to `done/` with the reason in `result.md`.
