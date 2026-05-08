# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- `apt help` / `-h` / `--help` / `?` now prints a structured usage
  block listing every command, its short flag, and which actions
  require admin privileges.
- `halt` and `restart` accept `help` / `-h` / `--help` / `?` and ask
  for an interactive `[y/N]` confirmation by default; pass `-y` /
  `--yes` to keep the previous immediate behaviour.
- `config` with no arguments now lists every configurable key and its
  current value when the `menu` package is not installed, instead of
  printing a generic "invalid input" message.
- `config <key>` shows the current value plus the valid options for that
  key, and `config help` / `-h` / `--help` / `?` print full usage.
- `bash help` / `-h` / `--help` / `?` print usage for the shell launcher
  and `bash setcolor` now validates all three colour names and reports
  unknown values clearly instead of silently writing them to disk.
- The boot welcome prompt accepts `help` / `?` and lists the available
  prompt commands (`bash`, `update`, `restart`, `halt`).
- `login`, `useradd`, `userdel`, and `passwd` now all accept
  `help` / `-h` / `--help` / `?` and use a uniform Usage block.
- `useradd` prompts interactively (masked) for a password when one is
  not supplied on the command line (parity with `passwd`).
- `userdel` now requires an interactive `[y/N]` confirmation before
  deleting an account; pass `-y` / `--yes` to keep the previous
  non-interactive behaviour.

### Changed
- `apt` distinguishes between missing argument, missing admin, and
  unknown command instead of one merged "Invalid input or access
  denied" message; failure paths now return `false` and surface
  red error lines with concrete hints. Removed the always-printed
  `Apt: operation complete.` trailer that ran even after failures.
- `config` and `bash setcolor` now print success/failure feedback
  (green on success, red on error) so users can see whether a setting
  change applied. Failed `minux.setconfig` calls (e.g. denied because
  the user is not admin/owner) surface a friendly hint instead of
  silently noop'ing.
- `login.sh` no longer eats a stray keystroke after empty input, prints
  `Access granted/denied` in green/red, and shows the username on a
  failed attempt. It returns false on failure so `&&` / `||` work.
- `useradd` / `userdel` / `passwd` print colour-coded success and
  failure lines with concrete hints (e.g. "'apt -i auth-client' to
  install the network auth client") and avoid duplicate messages when
  delegating to `usermod`.
- The boot login retry loop dropped its blocking 2-second sleep and now
  shows an attempt counter so users can see the prompt is alive.
- Refreshed `man config`, `man bash`, `man login`, `man useradd`, and
  `man userdel` to document the expanded CLI.

## [3.0.2] - 2026-05-08

### Fixed
- Stopped an endless first-run installation verify loop in the boot flow.
- Fixed wrapper failure return values so shell control flow (`&&` / `||`) behaves correctly for `cat`, `head`, `less`, `tail`, `man`, `mktemp`, and `service`.

### Added
- Added manual pages for `bash`, `edit`, `halt`, `lock`, `makeboot`, `newtab`, `restart`, `useradd`, and `userdel`.

### Changed
- Bumped project package version to 3.0.2.
- Added and packaged `CHANGELOG.md` in the release manifest.

## [3.0.1] - 2026-05-08

### Changed
- Updated in-system branding from **Minux** to **ReMinux**.
- Updated installer and APT release metadata handling for the 3.0.1 release path.
- Refreshed manual pages for `apt`, `chat`, `config`, `ls`, `man`, `ping`, `search`, and `usermod`.
