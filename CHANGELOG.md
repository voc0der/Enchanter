## [2.1.10] - 2026-04-05

### Changed
- Replaced the manual workbench tip entry with automatic trade-gold tracking plus an inline `No tip` confirmation before manual completion

### Fixed
- Let short queues collapse so the selected order gets more room in the detail pane
- Kept long order details inside the workbench with a scrollable detail area instead of letting recipes or mats bleed past the frame

## [2.1.9] - 2026-04-05

### Changed
- Moved the workbench running `orders / done / tips` summary out of the crowded header and into a footer line near the resize handle

### Fixed
- Kept the workbench title row on a single line again by moving the new completion totals out of the header controls area

## [2.1.8] - 2026-04-05

### Added
- Added a workbench header toggle that switches between `No Sound` and `Sound`, with queue alerts disabled by default
- Added a WoW-native queue alert sound for newly queued customers so fresh orders are easier to notice without reusing the normal whisper alert
- Added a verified-order `Complete` flow with a tip entry box plus persisted workbench totals for completed orders and tips earned

### Changed
- The workbench header now keeps a running `orders / done / tips` summary, and `Clear` resets both the queue and those totals

### Fixed
- Reworked the workbench `Cast` flow so it selects the exact trade-skill recipe, uses the Blizzard create call shape, and retries longer after opening enchanting

## [2.1.7] - 2026-04-04

### Fixed
- Restored usable widths for workbench detail recipe and material rows so the selected order no longer shows a blank checklist area even when recipe and mats data exist
- Let active-trade syncing retry the recipient lookup after the trade window opens so live `Use Trade` tracking can recover when the client populates the partner name late
- Expanded local regression coverage around the detail checklist rendering and delayed trade-partner detection path

## [2.1.6] - 2026-04-04

### Added
- Added a header control that switches between `Scan`, `Start`, and `Stop` based on whether the addon has recipe data and whether chat matching is paused
- Added per-recipe verification checkboxes so you can explicitly mark each requested enchant as fully paid and finished
- Added active-trade workbench guidance so matching recipe actions switch to `Apply` and explain the trade-slot enchant flow
- Added a `Use Trade` action that copies mats currently offered in the trade window into the order checklist
- Added live trade-mat detection so the workbench can compare the customer's current trade offer against the queued material list

### Changed
- Multi-enchant orders now only show the green verified state when every requested enchant has been checked off
- Closing a trade no longer auto-removes the order after a single cast or payment hint; verified orders stay visible until you clear them yourself

## [2.1.5] - 2026-04-04

### Added
- Added a header-level `Clear` action to wipe the queued orders and reset the selected detail pane when the workbench gets into a stale or noisy state

### Fixed
- Made `/ec simulate` tolerate clients that do not expose `math.randomseed` or `math.random`, falling back cleanly instead of throwing a Lua error
- Gave refreshed queue rows an explicit width so workbench orders no longer disappear even while the queue count keeps increasing
- Clamp stale queue scroll offsets during refresh so the list cannot stay scrolled into blank space after the queued order count changes

## [2.1.4] - 2026-04-04

### Added
- Added `/ec simulate` and `/e simulate` so you can queue randomized fake customers for workbench testing, with one fake order generated immediately and another every 3 minutes while the simulation is running
- Added simulation safeguards so fake customers never send real invites, recipe whispers, or grouped follow-up whispers

### Fixed
- Made workbench refresh tolerate clients that do not expose `SetShown` on font strings, which could otherwise leave the queue count updated while the visible order rows never redraw
- Reformat legacy stored workbench timestamps when loading saved orders so older `13:11` entries no longer stay burned in after switching to the in-game 12-hour clock style
- Expanded regression coverage for the workbench hotfixes and the new simulation flow

## [2.1.3] - 2026-04-04

### Fixed
- Anchored the workbench queue scroll child so queued customers render reliably in the list instead of only appearing in the detail pane
- Made `/ec scan` explicitly select each enchant before reading reagents so material snapshots are captured on Anniversary clients that require recipe selection
- Changed workbench queued and updated timestamps to follow the in-game clock style instead of a fixed 24-hour format

## [2.1.2] - 2026-04-04

### Added
- Added a resizable workbench frame with saved per-character size so the queue can be scaled for busier trade-chat sessions
- Added ElvUI skin support for the workbench frame and its interactive controls when ElvUI is loaded

### Changed
- Let the queue and detail panes grow and shrink with the main workbench window instead of staying at a fixed size
- Updated contributor and release docs so their validation and packaged-file examples include `Workbench.lua`

### Fixed
- Moved the workbench header controls onto the draggable header layer so `Unlock` and close buttons stay clickable on TBC Anniversary

## [2.1.1] - 2026-04-04

### Added
- Added a manual workbench queue that tracks matched customers, their requested enchants, and the last raw trade-chat message
- Added slash toggles for the workbench via `/ec`, `/ec workbench`, and `/e workbench`
- Added row-level `Inv`, `Msg`, and `X` actions plus best-effort `Cast` actions and a manual materials checklist for each queued order
- Added workbench debug logging so `/ec debug` also reports queue and UI activity
- Added automatic workbench completion on trade close when there is strong completion evidence such as payment, a workbench cast, or a fully checked mats list
- Added an optional already-grouped follow-up whisper with its own delay and configurable message when an invite fails because the customer is already grouped

### Changed
- Store reagent snapshots during `/ec scan` so queued orders can show aggregated mats totals
- Cleaned up the XML load order so the main addon file is not loaded twice
- Expanded local regression coverage around the workbench flow, grouped follow-up handling, and conservative trade/order matching

### Fixed
- Made workbench trade completion ignore unrelated trade partners instead of falling back to the currently selected order

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
