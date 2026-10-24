# Security Policy

## Supported versions

Security fixes go into the latest release. Update to it before you report.

## What the app can do with root

Vibecode24 never runs as root. To keep a closed MacBook awake it needs `pmset`, which requires root. On first use it asks for your admin password once and installs `/etc/sudoers.d/vibecode24`:

```
yourname ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0
```

`yourname` is your macOS short user name. Before installing the file, the app checks it with `visudo -c`.

The rule lets processes running as your user run exactly two commands as root without a password:

- `/usr/bin/pmset -a disablesleep 1` (turn system sleep off)
- `/usr/bin/pmset -a disablesleep 0` (turn it back on)

sudo matches the full command line, so the rule does not allow `pmset` with other arguments, other programs, or a shell. The practical effect for an attacker who already runs code as your user: they can stop your Mac from sleeping, or let it sleep. They gain nothing else.

While `disablesleep` is on, the app also starts a watchdog: a `/bin/sh` loop that checks every five seconds whether the app process still exists. When the app process disappears, the loop runs `sudo -n /usr/bin/pmset -a disablesleep 0` and exits. The watchdog runs as your user and goes through the same sudoers rule, so it can run only the allowed command that turns sleep back on.

Remove the rule at any time in **Settings → Safety → Lid-closed permission → Remove…**, or with:

```sh
sudo rm /etc/sudoers.d/vibecode24
```

If the Mac stays awake when it should not, run `sudo pmset -a disablesleep 0`.

## In scope

- A way to make the sudoers rule allow more than the two commands above.
- A way for the app to leave `disablesleep` on after quit, logout or a crash and the next launch.
- A way for another process to drive the app (URL scheme, shortcut) into something beyond changing its mode.
- Problems in how the app writes, validates or removes the sudoers file.

## Reporting a vulnerability

Use GitHub private vulnerability reporting: open the [Security tab](https://github.com/vladislavkovalskyi/vibecode24/security) and click **Report a vulnerability**, or go straight to [a new advisory](https://github.com/vladislavkovalskyi/vibecode24/security/advisories/new).

Please do not open a public issue for a security problem.

Include the app version, your macOS version and Mac model, the steps to reproduce, and what an attacker gains. You will get a reply within 7 days. Once a fix ships, the advisory is published with credit to you, unless you prefer to stay anonymous.
