## [Unreleased]

## [2.1.1] - 2026-04-04

### Added
- Added a manual workbench queue that tracks matched customers, their requested enchants, and the last raw trade-chat message
- Added slash toggles for the workbench via `/ec` and `/ec workbench`
- Added best-effort `Cast` actions and a manual materials checklist for each queued order
- Added automatic workbench completion on trade close when there is strong completion evidence such as payment, a workbench cast, or a fully checked mats list

### Changed
- Store reagent snapshots during `/ec scan` so queued orders can show aggregated mats totals
- Cleaned up the XML load order so the main addon file is not loaded twice

## [2.1.0] - 2026-04-04

### Changed
- Prepared the fork for ongoing maintenance with root-level addon packaging, release documentation, and GitHub Actions release automation
- Adopted a TBC Anniversary baseline with `20505` metadata, API compatibility fallbacks, and an Anniversary-capable settings path
- Promoted the TBC-oriented recipe tag set from the author's `1.6` build as the new fork starting point

### Fixed
- Removed the imported options-library dependency on `GroupBulletinBoardDB`
- Rebuild compiled recipe and search patterns after scans and options changes so live config edits take effect immediately

## [2.0.2] - Unknown

### Changed
- Updated for Ulduar

## [2.0.1] - Unknown

### Added
- Added Wrath recipes
- Sends recipe links to players asking for `LF Enchanter`

## [2.0.0] - Unknown

### Changed
- Updated for Wrath APIs

## [1.4.0] - Unknown

### Added
- Added blacklist support
- Added `/e` as a slash-command alias

### Fixed
- Fixed a bug that caused custom tags to wipe the text field instead of editing the tag data
- Fixed a bug that could leave default and custom tags out of sync

## [1.3.0] - Unknown

### Added
- Added an auto-invite toggle
- Added a toggle for Nether-requiring recipes
- Added more recipes and tag improvements

## [1.2.0] - Unknown

### Added
- Added settings for custom tags and message prefix

## [1.1.0] - Unknown

### Changed
- Updated recipe tags

## [1.0.0] - Unknown

### Added
- Initial release
