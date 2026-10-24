# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-10-24

First public release.

### Added

- Menu bar app for macOS 14 Sonoma and later, universal build for Apple silicon and Intel.
- Lid-closed mode through `pmset -a disablesleep`, so a closed MacBook stays awake without an external display.
- Idle sleep prevention through an `IOPMAssertion` while the lid is open.
- One-time admin prompt that installs `/etc/sudoers.d/vibecode24`, limited to `pmset -a disablesleep 1` and `0` for the current user. Removable in Settings → Safety → Lid-closed permission.
- Sleep restore on quit, logout, shutdown, SIGTERM and SIGINT, and on the next launch after a crash or force quit.
- Crash watchdog: a `/bin/sh` process started by the app restores sleep within five seconds if the app dies while it holds the Mac awake.
- A check every 30 seconds that fixes `SleepDisabled` if something else changed it.
- Modes: Auto (default, with a 2-minute grace period after the last agent exits), Always, Timer (30 min to 8 h) and Off.
- Agent radar for 17 agent CLIs: Claude Code, Codex, Gemini CLI, Aider, OpenCode, Cursor Agent, Copilot CLI, Amp, Goose, Qwen Code, Crush, Droid, Kiro, Cline, Continue CLI, Auggie and Kilo Code. It shows a live CPU sparkline and a working or idle state per agent, with per-agent switches and custom process names.
- `--scan` command line flag that prints the agents the radar sees.
- Optional idle release when all agents have been idle for N minutes.
- Safety guards: battery floor (15 % by default), critical thermal state and an optional "Only when connected to power" switch.
- Display off on lid close, which also locks the Mac if your password is required right away.
- Optional "Keep the display on while awake" setting.
- Notification and sound when an agent finishes, and a summary when you open the lid: how long it was closed and which agents finished.
- Session stats: time awake and time awake with the lid closed.
- Global shortcut ⌃⌥⌘A to toggle.
- URL scheme: `vibecode24://on`, `off`, `auto`, `toggle` and `timer?minutes=N`.
- Launch at login.
- Interface in English, Russian and Ukrainian, with an in-app language switch.
- DMG installer and Homebrew cask (`vladislavkovalskyi/tap/vibecode24`).

[Unreleased]: https://github.com/vladislavkovalskyi/vibecode24/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/vladislavkovalskyi/vibecode24/releases/tag/v0.1.0
