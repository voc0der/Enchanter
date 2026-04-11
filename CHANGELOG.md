## [2.1.41] - 2026-04-11

### Fixed
- Stopped cold-cache reagent scans from saving empty `[]` material names, so queued mats like `Truesilver Bar` stay keyed by item ID, hydrate automatically when item data arrives, and still match live trade offers correctly

## [2.1.40] - 2026-04-11

### Fixed
- Kept scanned enchants with no built-in shorthand table as exact-name-only matches, so linked recipes and full names like `Enchant Cloak - Lesser Agility` now whisper correctly without broadening aliases such as `agility to back`

## [2.1.39] - 2026-04-11

### Fixed
- Expanded attached quantity hints like `x2` and `2x` into repeated queued recipe rows, so orders such as `Crusader x2` now total duplicate mats correctly and verify one copy at a time across separate trades
- Kept reagent rows even when the client only exposes the item link text for a mat during the scan, which avoids intermittent snapshots that dropped mats like `Righteous Orb`

## [2.1.38] - 2026-04-10

### Fixed
- Loud workbench alerts now use the ready-check sound on the `Master` channel, with additional client-defined fallbacks, so the added loud state is not lost when SFX is muted or the raid-warning cue is too quiet
- Loud mode now adds a gold `!` marker to the speaker button instead of relying only on a subtle wave tint
- Adjacent linked enchant names now scope blacklist checks to the matching bracketed recipe text, so one linked enchant does not suppress the next linked enchant in the same request

## [2.1.37] - 2026-04-10

### Changed
- Sound button now cycles through three states — normal, loud, and muted — instead of a simple on/off toggle. Loud mode plays the raid-warning sound on the SFX channel so the alert cuts through clearly on setups where the default sound is too quiet

## [2.1.36] - 2026-04-09

### Added
- Mark yourself with a star raid icon as soon as a queued customer newly joins your party or raid, so fresh invite accepts can spot you faster

### Changed
- Automatically pause chat matching if you go AFK while `/ec start` scanning is active

## [2.1.35] - 2026-04-09

### Changed
- Reduced per-message chat parsing work by pre-bucketing recipe tags, reusing per-segment blacklist checks, and precomputing normalized generic request phrases so auto-invites can react faster without changing matching behavior

## [2.1.34] - 2026-04-08

### Fixed
- Stopped shorthand recipe tags from starting in the middle of unrelated chat tokens, so arena posts like `1815 resto druid LF 2's partner` no longer trigger false `15 res` resilience matches

## [2.1.33] - 2026-04-08

### Changed
- Swapped the workbench settings button over to Blizzard's brown options cog so it reads like a config control instead of a gear-manager button

## [2.1.32] - 2026-04-08

### Added
- Added a small workbench header gear button beside the close `X` that opens `/ec config`

### Fixed
- Matched official full enchant names even when callers omit the separator dash, so requests like `Enchant Shield Major Stamina` no longer miss the shield stamina recipe

## [2.1.31] - 2026-04-08

### Added
- Added a `Play sound on party join instead` setting so the workbench sound toggle can wait for a queued customer to actually join your party or raid instead of pinging on first queue entry

### Fixed
- Renamed the Auctionator workbench button from the awkward `AH Missing` shorthand to the clearer `Search AH`
- Fixed the post-enchant `/thank` option so it resolves the actual customer instead of falling back to a generic untargeted emote when you are not manually targeting them
- Fixed the grouped-customer cap so auto-paused chat scanning resumes by itself when the queued customer count falls back under the configured limit, while still respecting a manual stop

## [2.1.30] - 2026-04-08

### Added
- Added a `Max customers in group` setting so Enchanter can pause chat matching automatically once a chosen number of queued customers have actually joined your party or raid; `0` keeps the old unlimited behavior
- Added an `Emote /thank after successful cast` setting that sends a direct `THANK` emote to the customer once a trade settles with a confirmed applied enchant
- Added an Auctionator-powered workbench header button that appears while the Auction House is open and bulk-searches every missing enchant formula by exact `Formula: ...` item name, refreshing from the live enchanting window first when it is available

### Changed
- Reworked the unlocked workbench lock button state into a cleaner native padlock plus green-check treatment instead of the old blocky hand-drawn open shackle

## [2.1.29] - 2026-04-07

### Fixed
- Refreshed the open workbench immediately when grouped queue entries expire, so timed-out already-grouped orders disappear from the visible queue without needing to close and reopen the window
- Added a small expiry-timer buffer plus tighter queue-row cleanup so grouped-order timeouts land past the configured deadline and stale rows are cleared more reliably

## [2.1.28] - 2026-04-07

### Added
- Added a red grouped-order outline in the workbench queue plus green in-group checks in the queue and detail pane so already-grouped customers are easy to spot and track once they join you
- Added a configurable grouped-queue expiry setting so `/ec config` can retire already-grouped orders automatically after a chosen number of seconds when they never join your group

### Changed
- The workbench now tracks already-grouped invite failures even when the optional grouped follow-up whisper is disabled, so queue state stays accurate without forcing the extra whisper

## [2.1.27] - 2026-04-06

### Added
- Added a searchable `Recipe Customizations` settings subcategory with per-recipe search phrases and additive per-recipe blacklist phrases
- Added built-in default blacklist phrases for the highest-collision enchant families, plus an expanded request-scenario regression suite with 10+ valid and 10+ invalid matching cases

### Changed
- Switched enchant request parsing over to segment-aware matching so comma-, slash-, plus-, and `and`-separated asks are evaluated locally instead of as one giant message blob
- Updated the workbench header to show the addon version and icon-based lock and sound toggles

### Fixed
- Stopped nested or overlapping recipe tags from inflating incomplete-order counts like `1/2` when the customer only asked for one enchant
- Tightened per-recipe blacklist handling so opposite-slot phrases block only the local request segment they belong to instead of suppressing unrelated enchants elsewhere in the same message

## [2.1.26] - 2026-04-05

### Changed
- Retired fully verified workbench orders automatically so the old per-order `Complete` step is no longer needed after the final enchant trade settles

### Fixed
- Preserved accepted split-trade mats and tip snapshots even when `TRADE_CLOSED` arrives before the late trade completion signal, which keeps follow-up enchant trades from dropping green checks back to `?`
- Carried earlier split-trade gold forward into the final verifying trade before the order auto-completes, so the running totals still bank the right tip amount

## [2.1.25] - 2026-04-05

### Fixed
- Latched accepted trade state so received mats and detected in-window enchants still persist even if the client clears trade accept flags during the close sequence
- Updated the workbench detail view to show a trade-detected enchant as verified immediately while the trade is still open

## [2.1.24] - 2026-04-05

### Fixed
- Hardened recipe reagent scans so workbench material snapshots keep the full reagent list even on clients that depend on confirmed profession-frame selection or expose extra reagent info fields; owning one reagent yourself no longer collapses queued mats down to that single item

## [2.1.23] - 2026-04-05

### Fixed
- Made the workbench `Lock` / `No Lock` toggle tolerate clients whose button templates do not expose `SetTextInsets`, which fixes the blank load-time Lua error when opening the workbench

## [2.1.22] - 2026-04-05

### Fixed
- Replaced the workbench queue alert's fragile reforging sound with Blizzard UI sounds that exist on Vanilla, TBC, and Wrath client trees, so `Sound` uses a much safer default alert
- Made the workbench `Sound` toggle play an immediate preview ping and print a warning if none of the alert sound fallbacks can play, so silent clients are much easier to diagnose

### Changed
- Reworked the workbench lock control into a compact padlock button next to the close `X`, and made it behave like the `Sound` toggle by showing `Lock` / `No Lock` state text directly on the button

## [2.1.19] - 2026-04-05

### Fixed
- Made recipe scans temporarily clear Blizzard trade-skill and craft filters so `/ec scan` can capture your real enchanting list even when the profession UI is filtered or searched
- Stopped printing `Scan Completed` when the scan captured zero supported recipes; failed scans now stay on `Scan` with a more accurate warning instead
- Replaced the workbench `Resize` text button with the native diagonal resize grip so the corner affordance reads like a real window handle again

## [2.1.18] - 2026-04-05

### Fixed
- Stopped the workbench header button from getting stuck on `Scan` just because some saved recipes are missing reagent snapshots; once scanned recipes exist, the header now returns to `Start` or `Stop` as expected

## [2.1.17] - 2026-04-05

### Added
- Added `Warn if Incomplete Order`, enabled by default, so recipe whispers can prepend `matched/requested` counts like `3/4` before the links when a request includes enchants you cannot cover
- Added `Invite Incomplete Order`, enabled by default, so partial matches can be left unflagged and unhandled automatically when you only want to auto-respond to fully covered orders

## [2.1.16] - 2026-04-05

### Fixed
- Preferred the trade-skill recipe API consistently when the client exposes both trade-skill and legacy craft data, which keeps recipe links and reagent snapshots aligned during scans
- Hardened the legacy craft fallback used by workbench `Cast` / `Apply` so it temporarily clears Blizzard's craft filters, uses the Craft UI selection helper, and avoids invalid reagent tooltip selections

## [2.1.15] - 2026-04-05

### Fixed
- Replaced the workbench recipe checkbox with automatic `?` / green-check status so accepted trades confirm completed enchants without manual clicks
- Matched applied enchants from the trade-slot API, even when you did not start the cast from Enchanter's own `Apply` button
- Preserved the last accepted trade-mat snapshot so finished material handoffs stay checked even if Blizzard clears the trade offer before `TRADE_CLOSED`
- Re-checked the trade enchant state on completion so late trade-slot enchant updates still auto-verify the finished recipe
- Dropped the extra `No tip` button so verified orders can be completed directly at `0g` when nobody tips
- Synced the saved workbench visibility with the real frame state so `/ec workbench` now opens or closes correctly in one command after using the `X` button

## [2.1.13] - 2026-04-05

### Fixed
- Replaced the workbench material checklist controls with automatic `?` / green-check status indicators so trade mats are tracked visually without manual clicks
- Hid the old material action buttons from the detail pane now that accepted trades and live offers keep the mat state updated automatically

## [2.1.12] - 2026-04-05

### Changed
- Switched workbench trade completion over to the live trade APIs so accepted trades now use `TRADE_MONEY_CHANGED`, `TRADE_ACCEPT_UPDATE`, and the trade slots instead of guessing from the player's post-trade wallet
- Let accepted trades carry forward offered mats, applied enchants, and repeated split-tip payments while the order stays queued until you click `Complete`

### Fixed
- Stopped showing manual `No tip` and `Complete` controls during an active trade so the detail pane no longer invites premature clicks while the trade is still settling
- Only auto-verified an applied enchant once Blizzard reports a real enchantment in the trade slot, instead of treating an unmodified slot item as finished work
- Accumulated shared reagent counts across multiple accepted trades, which fixes multi-enchant orders that are paid out in separate mat handoffs
- Replaced the material checklist controls with automatic `?` / green-check status indicators so mat tracking is no longer manual

## [2.1.11] - 2026-04-05

### Fixed
- Routed workbench queue alerts through the `Master` sound channel so the `Sound` toggle can still ping when sound effects are muted
- Added a compatibility fallback so queue alerts still play on clients that reject an explicit sound channel argument

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
