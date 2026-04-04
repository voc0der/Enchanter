# Enchanter

- Helps enchanters catch trade-chat requests that match recipes they actually know
- Scans your known enchanting recipes and stores match tags per character
- Can auto-invite matched players and whisper recipe links for the enchants you can perform
- Adds a manual workbench queue so matched orders do not disappear once trade chat gets noisy
- Includes an Anniversary-oriented settings panel and packaging workflow for fork maintenance

Current version: `2.1.7`

## What It Does

- Run `/ec scan` once after learning recipes to build your known-enchant list
- Match trade-chat requests against configured recipe tags
- Auto-invite matched players when `Auto Invite` is enabled
- Whisper the matching enchant links with a configurable delay and message prefix
- Optionally reply to generic `LF enchanter` requests with a custom whisper
- Queue matched customers into a workbench window with per-order recipe and materials snapshots
- Resize the workbench to fit your screen or chat flow, with the layout saved per character
- Keep queued orders visible through the full trade flow so you can verify each requested enchant before clearing the order

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
- Use the header `Scan`, `Start`, or `Stop` button to keep the addon ready without leaving the workbench.
- Use the header `Clear` button to wipe the current queue and reset the detail pane if you want to flush stale or finished orders quickly.
- Drag the `Resize` handle in the lower-right corner to resize the workbench; the queue and detail panes will resize with it.
- When a matching trade is open, the recipe action changes to `Apply` and the detail pane explains the trade-slot flow.
- Click `Apply`, then click the customer's item in the trade window to finish the enchant manually without over-automating it.
- Check the green checkbox next to each requested enchant once you have verified that specific enchant is fully paid and done.
- Multi-enchant orders only turn green once every requested enchant has been checked off.
- The workbench now watches the customer's current trade offer for matching mats and can show live progress against the queued material list.
- Click `Use Trade` to copy the mats currently offered in the trade window into the persistent checklist.
- Use the row-level `Inv` and `Msg` buttons to manually re-invite or re-whisper a queued customer when needed.
- Use `/ec simulate` or `/e simulate` to feed the workbench randomized fake customers without sending any real invites or whispers.
- Closing the trade no longer retires the order by itself; the queue stays visible until you verify the whole order and clear it manually.
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
