# Changelog

All notable changes to this project will be documented in this file.

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
