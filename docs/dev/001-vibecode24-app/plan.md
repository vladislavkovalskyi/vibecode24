# 001 — Plan

Work was split between a coordinator and parallel agents. Files did not overlap, so the
branches merged without conflicts.

| Step | Owner | Output |
|---|---|---|
| 1. Facts and competitor research | research agent (read-only) | lid-closed caveats, process names per agent CLI, competitor features |
| 2. Core module `VibeCore` | coordinator | catalog, matcher, libproc scanner, policy, sleep control, sudoers rule, sensors, settings, session log, L10n |
| 3. App module `Vibecode24` | coordinator | menu bar popover, settings, onboarding, hot key, URL scheme, notifications, screenshot exporter |
| 4. Icon, DMG background, build and DMG scripts, CI | build agent (worktree) | `scripts/`, `Assets/`, `.github/workflows/`, `VERSION` |
| 5. README in three languages, community files | docs agent (worktree) | `README*.md`, `LICENSE`, `CONTRIBUTING.md`, `SECURITY.md`, issue templates |
| 6. Merge, align docs with the code, render screenshots | coordinator | `docs/assets/*.png` |
| 7. Publish | coordinator | GitHub repository settings, release with the DMG, Homebrew tap |

## Decisions taken during the work

- **Match on argv, not on the process name.** The native Claude Code binary is a file named
  after its version (`~/.local/share/claude/versions/2.1.309`), so `proc_name` never says
  "claude". The scanner reads `argv` with `KERN_PROCARGS2` and matches `argv[0]`, the
  executable path, and the script argument after an interpreter.
- **Ignore helper processes.** `claude --chrome-native-host` and `codex app-server` run all
  day and are not agent sessions.
- **One session per process tree.** A Node wrapper and the native binary it starts are one
  session; the CPU of the whole tree counts, so a running build keeps the agent "working".
- **Watchdog.** Restoring on the next launch is not enough after a crash: the Mac would stay
  sleepless until the user opens the app again. A `/bin/sh` loop started by the app restores
  sleep within five seconds of the app process disappearing.
- **Lid events.** On lid close the display is turned off (`pmset displaysleepnow`), which also
  locks the Mac when the password is required immediately. On lid open, a summary
  notification lists what finished meanwhile.
- **Strings in code, not in `.strings` files.** The app switches language without a restart and
  the SwiftPM build stays resource-free. Tests check that every key exists in all three
  languages with the same format arguments.
- **Own switch style.** The system switch ignored `.tint` in some contexts; the accent colour is
  the only colour the app has, so the switch is drawn in SwiftUI.
