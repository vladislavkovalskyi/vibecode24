# 001 — Vibecode24: keep a MacBook awake for AI coding agents

## Request (owner, 2026-10-24)

Build a macOS app for "vibecoders": people who leave AI coding agents (Claude Code,
Codex CLI and similar) running in a terminal. Goals stated by the owner:

- The core job: the MacBook must not sleep, **even with the lid closed**, using
  `sudo pmset -a disablesleep 1` to enable and `sudo pmset -a disablesleep 0` to restore.
- Extra features are welcome. Example from the owner: a configurator that notices when
  Claude CLI, Codex and similar tools are running, so that closing the lid does not stop
  the agents.
- Strong, non-generic design, very simple and light to use.
- Three interface languages: Russian, Ukrainian, English.
- A great `README.md`; the GitHub repository set up to attract users
  (personal account `vladyslavkovalskyi`).
- Installable from a `.dmg`.
- Full creative freedom: research and add useful features.

## Constraints

- Personal project: no Jira, no organisation repositories.
- All files and repository texts in English; UI in en / ru / uk.
- No paid Apple Developer account is assumed: the app is ad-hoc signed and not notarized.
