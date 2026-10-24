# Contributing to Vibecode24

Thanks for helping. Bug reports, new agents, translations and fixes are all welcome. For anything larger than a small fix, open an issue first so we can agree on the approach before you write code.

## Setup

You need macOS 14 or later and Xcode 16 (or a Swift 6 toolchain).

```sh
git clone https://github.com/vladyslavkovalskyi/vibecode24.git
cd vibecode24
swift build                # compile
swift test                 # run the tests
scripts/build-app.sh       # build a universal, ad-hoc signed Vibecode24.app
scripts/make-dmg.sh        # wrap it in a DMG
```

You can open `Package.swift` in Xcode to work on the UI with previews.

Testing lid-closed mode changes a system-wide power setting. If a debug build leaves it on, run `sudo pmset -a disablesleep 0`.

## Project layout

| Path | Contents |
|---|---|
| `Sources/VibeCore` | Logic with no UI: process radar, agent catalog, sleep layers, guards, modes, session stats, localisation. |
| `Sources/Vibecode24` | The app: menu bar item, popover, settings window, shortcut, URL scheme, login item. |
| `Tests/VibeCoreTests` | Unit tests for `VibeCore`. |
| `scripts/` | Build and packaging scripts. |
| `docs/dev/NNN-feature/` | Design documents, one folder per feature. |

Keep logic in `VibeCore` so it stays testable. The app target should only wire that logic to SwiftUI and AppKit.

## Adding an agent

The built-in agent list lives in `Sources/VibeCore/AgentCatalog.swift`.

1. Find the process name. Start the agent in a terminal, then in another one run:

   ```sh
   ps -axo pid,comm,args | grep -i <agent>
   ```

   A native binary shows its own name in `comm`. A Node or Python tool shows `node` or `python3` in `comm`, and the script path in `args`.
2. Add an entry to `AgentCatalog.swift` that follows the shape of the existing ones: a stable id, the display name, the executable names to match, and, for Node or Python tools, a fragment of the script path that identifies the agent.
3. Pick names that do not catch unrelated processes. `amp` as a script path fragment would match too much; `@sourcegraph/amp` would not.
4. Add a test in `Tests/VibeCoreTests` with a sample `comm` and `args` for the new agent, and one that must not match.
5. Add the agent to the "Supported agents" table in `README.md`, `README.ru.md` and `README.uk.md`.

If you only want an agent supported and don't plan to write the code, open a [new agent request](https://github.com/vladyslavkovalskyi/vibecode24/issues/new?template=new_agent.yml) instead.

## Adding or fixing a translation

UI strings live in `Sources/VibeCore/L10n.swift`. The app ships English, Russian and Ukrainian.

- To fix a string, edit it in place and keep the key.
- To add a language, add it to the language list, then provide a value for every key. Copy the English block as a starting point.
- Write the way a native speaker would. Keep the strings short: the popover is narrow.
- Run `swift test` and check the popover and the settings window in the new language. You can switch the language in the app settings without changing your system language.

## Commits and pull requests

Commit messages are in English and use a type prefix with a scope:

```
feat(radar): detect Crush started through npx
fix(sleep): restore disablesleep after a crash on wake
docs(readme): add Homebrew uninstall step
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `perf`, `chore`.

Before you open a pull request:

- `swift test` passes.
- The change has tests if it touches `VibeCore`.
- You tried the app built with `scripts/build-app.sh` if it touches the UI or sleep handling.
- One pull request covers one change.

## Design documents

Features of any size get a folder in `docs/dev/` with a three-digit number and a short name, for example `docs/dev/004-idle-release/`. Write it before the code:

- `request.md`: the problem and what was asked for.
- `proposal.md`: how you plan to solve it and which options you rejected.

During and after the work, add:

- `plan.md`: the steps.
- `implementation.md`: what you built, what differs from the proposal, and why.

Take the next free number. `docs/dev/001-vibecode24-app/` shows the format.

## Code of Conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). By taking part, you agree to follow it.
