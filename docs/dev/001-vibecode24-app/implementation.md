# 001 — Implementation

## Layout

```
Sources/VibeCore/        logic, no UI
  AgentCatalog.swift     17 built-in agents
  AgentMatcher.swift     process → agent
  ProcessScanner.swift   libproc + KERN_PROCARGS2, CPU per process tree
  AwakePolicy.swift      pure decision: hold or release, and why
  AwakeController.swift  tick loop, applies decisions, sessions, events
  SleepControl.swift     IOPMAssertion, sudo -n pmset, watchdog
  HelperRule.swift       the sudoers rule: text, install, remove
  SystemSensors.swift    battery, lid (AppleClamshellState), thermal state
  AppSettings.swift      UserDefaults-backed settings
  SessionLog.swift       awake sessions and stats
  L10n.swift             en / ru / uk strings
Sources/Vibecode24/      SwiftUI app
Tests/VibeCoreTests/     30 tests
scripts/                 icon, DMG background, app bundle, DMG
```

## Verified on this machine (macOS 27.0, Apple silicon, 2026-10-24)

- `swift test`: 30 tests pass, including a `visudo -cf` check of the generated rule.
- `Vibecode24 --scan` finds the running Claude Code session and ignores
  `claude --chrome-native-host`.
- The bundled app, launched in Auto mode with Claude Code running, holds
  `PreventUserIdleSystemSleep` (`pmset -g assertions`). After SIGTERM the process exits and the
  assertion is gone; `SleepDisabled` stays `0`.
- `scripts/build-app.sh` produces a universal (arm64 + x86_64) ad-hoc signed bundle;
  `scripts/make-dmg.sh` produces a DMG with the app and an Applications link.

## Not verified here

- Installing the sudoers rule and the closed-lid run itself: they need the owner's
  administrator password and a physically closed lid. The rule text is validated by `visudo`
  in the tests; the install command is the one shown in `HelperRule.install`.
- Notifications need the app to be granted permission on first launch.

## Known limitations

- Not notarized; first launch needs "Open Anyway" or `xattr -dr com.apple.quarantine`.
- CPU-based idle detection cannot tell an agent waiting for a slow model from one waiting for
  input, so "Allow sleep when agents are idle" is off by default.
- Building inside an iCloud-synced folder needs `--scratch-path` outside it: iCloud adds
  Finder attributes and `codesign` refuses the test bundle.

## Published (2026-10-24)

- Repository: https://github.com/vladislavkovalskyi/vibecode24 (description, 20 topics,
  Discussions on, wiki and projects off, private vulnerability reporting on).
- Release `v0.1.0` built by the Release workflow; the DMG was downloaded back, its SHA-256
  checked, signature verified and `--scan` run from the mounted image.
- Homebrew: `Casks/vibecode24.rb` in `vladislavkovalskyi/homebrew-tap`; `brew audit --cask
  --online --strict` passes.
- `docs/assets/social-preview.png` (1280 × 640) is rendered by `--export-screenshots`. GitHub has
  no API for the social preview, so it is uploaded by hand in the repository settings.
