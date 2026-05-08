# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
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

### Changed
- `config` and `bash setcolor` now print success/failure feedback
  (green on success, red on error) so users can see whether a setting
  change applied. Failed `minux.setconfig` calls (e.g. denied because
  the user is not admin/owner) surface a friendly hint instead of
  silently noop'ing.
- Refreshed `man config` and `man bash` to document the expanded CLI.

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
