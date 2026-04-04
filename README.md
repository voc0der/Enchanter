# Enchanter

- Helps enchanters catch trade-chat requests that match recipes they actually know
- Scans your known enchanting recipes and stores match tags per character
- Can auto-invite matched players and whisper recipe links for the enchants you can perform
- Adds a manual workbench queue so matched orders do not disappear once trade chat gets noisy
- Includes an Anniversary-oriented settings panel and packaging workflow for fork maintenance

Current version: `2.1.4`

## What It Does

- Run `/ec scan` once after learning recipes to build your known-enchant list
- Match trade-chat requests against configured recipe tags
- Auto-invite matched players when `Auto Invite` is enabled
- Whisper the matching enchant links with a configurable delay and message prefix
- Optionally reply to generic `LF enchanter` requests with a custom whisper
- Queue matched customers into a workbench window with per-order recipe and materials snapshots
- Resize the workbench to fit your screen or chat flow, with the layout saved per character
- Auto-complete queued orders when a trade closes with strong completion evidence such as a workbench cast, full mats checklist, or payment

## Install

1. Download the latest GitHub release when one is available.
2. Extract the `Enchanter` folder into:
   `World of Warcraft/_anniversary_/Interface/AddOns/`
3. Start the game and make sure the addon is enabled.

## Usage

- `/ec scan`: Scan and store your known enchanting recipes. Run this before `/ec start` and any time you learn a new recipe.
- `/ec` or `/ec workbench`: Toggle the workbench queue window.
- `/ec start`: Start matching chat messages.
- `/ec stop` or `/ec pause`: Stop matching chat messages.
- `/ec config`: Open the addon settings.
- `/ec debug`: Toggle debug output.
- `/ec simulate`: Toggle fake workbench orders for testing. It queues one right away, then one every 3 minutes.
- `/ec summary`: Print session earnings from completed trades.
- `/ec about`: Print usage help.

## Workbench

- New matched orders are added to a queue instead of being lost in chat spam.
- Click an order to inspect the requested enchants, the raw message, and an aggregated materials checklist.
- Use the small `Lock` or `Unlock` button to control whether the workbench frame can be dragged.
- Drag the `Resize` handle in the lower-right corner to resize the workbench; the queue and detail panes will resize with it.
- Click `Cast` next to a queued enchant for a best-effort profession cast without fully automating the trade.
- Use the row-level `Inv` and `Msg` buttons to manually re-invite or re-whisper a queued customer when needed.
- Use `/ec simulate` or `/e simulate` to feed the workbench randomized fake customers without sending any real invites or whispers.
- When a trade closes, the addon now retires the queued order automatically if it has enough evidence the enchant was actually completed.
- Click the per-order `X` when the order is done or you want to clear it from the queue.
- In settings, you can also enable an automatic follow-up whisper for customers who were already in a group, with its own delay and custom message.
- If ElvUI is loaded, the workbench adopts ElvUI frame, button, checkbox, and scrollbar styling automatically.

## Contributing

Development and contribution notes are in [`CONTRIBUTING.md`](CONTRIBUTING.md).
Release workflow notes are in [`RELEASING.md`](RELEASING.md).
Fork-specific migration notes are in [`TBC_ANNIVERSARY_NOTES.md`](TBC_ANNIVERSARY_NOTES.md).

## Scope

- Target client: TBC Anniversary Classic
- TOC interface: `20505`
- Runtime files are listed in [`Enchanter.toc`](Enchanter.toc)
