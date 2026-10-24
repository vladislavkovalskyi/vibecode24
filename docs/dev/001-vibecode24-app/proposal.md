# 001 — Proposal

## Product in one sentence

A menu bar switch that keeps the Mac awake with the lid closed while your agents work,
and gives sleep back when they are done.

## How sleep is prevented

Two independent layers, because they solve different problems:

| Situation | Mechanism | Needs root |
|---|---|---|
| Lid open, user idle | `IOPMAssertionCreateWithName(PreventUserIdleSystemSleep)` | no |
| Lid closed, no external display | `pmset -a disablesleep 1` | yes |

`disablesleep` is a system-wide setting that survives the app. That makes it the risky
part, so the design treats "always give sleep back" as a hard requirement:

- restore on quit, on SIGTERM/SIGINT and on logout/shutdown notifications;
- remember ownership in a state file; on the next launch, if the app had enabled it and is
  not active, restore it (covers a crash or force quit);
- never touch the setting if the user enabled it outside the app.

### Privileges

`pmset` needs root. Options considered:

1. AppleScript `with administrator privileges` on every toggle: a password prompt every
   time. Rejected for daily use.
2. A privileged helper via `SMAppService.daemon`: the clean Apple route, but it requires a
   Developer ID signature and notarization to be usable by others. Not available.
3. **Chosen:** a one-time admin prompt installs `/etc/sudoers.d/vibecode24`, validated with
   `visudo -c`, allowing the current user to run exactly two commands without a password:
   `/usr/bin/pmset -a disablesleep 1` and `/usr/bin/pmset -a disablesleep 0`. The app then
   calls `sudo -n`. The rule can be removed from Settings at any time. It grants nothing
   beyond toggling this one setting.

## Modes

- **Auto** (default): awake only while at least one watched agent is running; after the
  last one exits, a grace period (default 2 min) passes and sleep comes back.
- **Always**: awake until turned off.
- **Timer**: 30 min, 1 h, 2 h, 4 h, 8 h.
- **Off**.

## Agent radar

Scans the process table every few seconds with `libproc` and `KERN_PROCARGS2` (no `ps`
subprocess). Matching uses the executable name and, for Node and Python scripts, the
script path in argv. Built-in list: Claude Code, Codex, Gemini CLI, Aider, OpenCode,
Cursor Agent, Copilot CLI, Amp, Goose, Qwen Code, Crush, Droid, Kiro, Cline, Auggie.
Each can be switched off. Users can add their own process names.

For every agent the radar shows CPU use, and whether the agent is working or idle (CPU
under a threshold). An optional setting releases sleep when all agents have been idle for
N minutes, for agents that sit waiting for input.

## Safety guards

- Battery floor: on battery below N % (default 15 %), release.
- Thermal guard: on `ProcessInfo.thermalState == .critical`, release.
- Each release says why in the popover and, optionally, in a notification.

## Extras

- Notification and sound when an agent finishes.
- Session log: how long the Mac stayed awake, how much of it with the lid closed.
- Global shortcut ⌃⌥⌘A to toggle.
- URL scheme `vibecode24://on|off|auto|toggle` for scripts and shell hooks.
- Launch at login (`SMAppService.mainApp`).
- Language: System / English / Русский / Українська, switchable in the app.

## Design direction

Native SwiftUI, system font (SF Pro, SF Mono only for numbers), the macOS material
behind the popover. One accent: a warm amber, like a standby LED, used only for the
"awake" state. The signature element is a small laptop drawing whose lid closes and whose
LED lights up when the app holds the Mac awake; it animates only on a change of state.
No gradients, no glow, no pulsing dots, no card around every value. One row density for
the agent list.

## Distribution

- SwiftPM project, `scripts/build.sh` builds a universal `.app` bundle and signs it
  ad hoc; `scripts/make-dmg.sh` wraps it in a DMG with an Applications link.
- GitHub Actions builds on every push and attaches the DMG to tagged releases.
- Homebrew tap with a cask.
- README in English with translations in Russian and Ukrainian.

## Out of scope

- Notarization (needs a paid developer account). The README explains the first-launch step.
- Intel-only optimisations beyond a universal build.
