# Enchanter

- Helps enchanters catch trade-chat requests that match recipes they actually know
- Scans your known enchanting recipes and stores match tags per character
- Can auto-invite matched players and whisper recipe links for the enchants you can perform
- Adds a manual workbench queue so matched orders do not disappear once trade chat gets noisy
- Includes an Anniversary-oriented settings panel and packaging workflow for fork maintenance

Current version: `2.1.18`

## What It Does

- Run `/ec scan` once after learning recipes to build your known-enchant list
- Match trade-chat requests against configured recipe tags
- Auto-invite matched players when `Auto Invite` is enabled
- Whisper the matching enchant links with a configurable delay and message prefix
- Optionally append `X/Y` to recipe whispers for incomplete orders, and optionally skip auto-handling those partial matches
- Optionally reply to generic `LF enchanter` requests with a custom whisper
- Queue matched customers into a workbench window with per-order recipe and materials snapshots
- Resize the workbench to fit your screen or chat flow, with the layout saved per character
- Keep queued orders visible through the full trade flow so trades can verify each requested enchant automatically before you clear the order

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
- Click an order to inspect the requested enchants, the raw message, and an aggregated materials tracker.
- Use the small `Lock` or `Unlock` button to control whether the workbench frame can be dragged.
- Use the header `Scan`, `Start`, or `Stop` button to keep the addon ready without leaving the workbench.
- Use the small `No Sound` or `Sound` header button to decide whether brand new queued orders should play a WoW-native alert; it starts in `No Sound` and now plays through the `Master` channel so muted sound effects do not suppress the queue ping.
- When every requested enchant is verified, the workbench watches live trade gold automatically, but you still choose when to click `Complete`, even if the final tip is `0g`.
- A footer line near `Resize` keeps a rolling `orders / done / tips` summary across reloads and relogs.
- Use the header `Clear` button to wipe the current queue, reset the running totals, and clear the detail pane if you want a fresh slate.
- Drag the `Resize` handle in the lower-right corner to resize the workbench; the queue and detail panes will resize with it.
- When a matching trade is open, the recipe action changes to `Apply` and the detail pane switches into the trade-slot flow.
- `Apply` is an optional shortcut for picking the queued enchant; once both sides accept, the workbench records the trade gold, flips matching mats to green checks, and marks the applied enchant automatically when the trade slot reports it, including late completion updates.
- If the client falls back to Blizzard's older Craft window, `Cast` / `Apply` now temporarily clears the Craft filters so queued enchants can still be selected reliably before the filters are restored.
- If they tip during earlier mat trades or across multiple follow-up trades, that gold stays attached to the order until you click `Complete`.
- Short queues now collapse to give the selected order more vertical room, and long detail panes stay inside the workbench frame with an internal scroll area.
- Requested enchants now show `?` until a settled trade confirms them, then flip to a green check automatically.
- Multi-enchant orders only turn green once every requested enchant has been confirmed automatically.
- The workbench now watches the customer's current trade offer for matching mats and shows each material as `?` or a green check automatically.
- Use the row-level `Inv` and `Msg` buttons to manually re-invite or re-whisper a queued customer when needed.
- Use `/ec simulate` or `/e simulate` to feed the workbench randomized fake customers without sending any real invites or whispers.
- Accepted trades never retire the order by themselves; partial mats trades, repeated tip trades, and applied enchants stay attached to the queue entry until you click `Complete`, even if the live trade offer clears while the window is closing.
- Click the per-order `X` when the order is done or you want to clear it from the queue.
- In settings, you can also enable an automatic follow-up whisper for customers who were already in a group, with its own delay and custom message.
- If ElvUI is loaded, the workbench adopts ElvUI frame, button, checkbox, and scrollbar styling automatically.

## Contributing

Development and contribution notes are in [`CONTRIBUTING.md`](CONTRIBUTING.md).
Release workflow notes are in [`RELEASING.md`](RELEASING.md).

## Scope

- Target client: TBC Anniversary Classic
- TOC interface: `20505`
- Runtime files are listed in [`Enchanter.toc`](Enchanter.toc)
