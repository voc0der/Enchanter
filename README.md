<p align="center">
  <img src="assets/enchanter-icon.svg" alt="Enchanter icon" width="180" />
</p>

<p align="center">
  TBC Anniversary Classic trade-chat matching with an in-game enchanting workbench.
</p>

# Enchanter

- Helps enchanters catch trade-chat requests that match recipes they actually know
- Scans your known enchanting recipes and stores match tags per character
- Can auto-invite matched players and whisper recipe links for the enchants you can perform
- Adds a manual workbench queue so matched orders do not disappear once trade chat gets noisy
- Includes an Anniversary-oriented settings panel and packaging workflow for fork maintenance

Current version: `2.1.28`

## What It Does

- Run `/ec scan` once after learning recipes to build your known-enchant list
- Match trade-chat requests against configured recipe tags
- Split multi-enchant chat lines into local request segments so one phrase does not pollute the whole message
- Auto-invite matched players when `Auto Invite` is enabled
- Whisper the matching enchant links with a configurable delay and message prefix
- Optionally append `X/Y` to recipe whispers for incomplete orders, and optionally skip auto-handling those partial matches
- Optionally reply to generic `LF enchanter` requests with a custom whisper
- Search and tune per-recipe search phrases plus additive per-recipe blacklist phrases from the settings panel
- Queue matched customers into a workbench window with per-order recipe and materials snapshots
- Flag already-grouped customers in the workbench until they join you, with an optional auto-expire timeout for those stalled queue entries
- Resize the workbench to fit your screen or chat flow, with the layout saved per character
- Keep queued orders visible through the full trade flow so accepted trades can carry mats and verify each requested enchant automatically, even across split handoff/enchant trades, before you clear the order

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
- Use the padlock icon next to `X` to control whether the workbench frame can be dragged. A closed padlock means it is locked; the open padlock means it is unlocked.
- Use the header `Scan`, `Start`, or `Stop` button to keep the addon ready without leaving the workbench.
- Use the speaker icon beside `Clear` to decide whether brand new queued orders should play a WoW-native alert. Sound waves mean it is on, the muted speaker means it is off, it starts muted, and enabling it plays a short preview through the `Master` channel so muted sound effects do not suppress the queue ping.
- When every requested enchant is verified, the workbench watches live trade gold automatically and retires the order on its own, even if the final tip is `0g`.
- A footer line near the resize grip keeps a rolling `orders / done / tips` summary across reloads and relogs.
- Use the header `Clear` button to wipe the current queue, reset the running totals, and clear the detail pane if you want a fresh slate.
- Drag the `Resize` handle in the lower-right corner to resize the workbench; the queue and detail panes will resize with it.
- When a matching trade is open, the recipe action changes to `Apply` and the detail pane switches into the trade-slot flow.
- `Apply` is an optional shortcut for picking the queued enchant; once both sides accept, the workbench records the trade gold, flips matching mats to green checks, and marks the applied enchant automatically when the trade slot reports it, including late completion updates.
- If the client falls back to Blizzard's older Craft window, `Cast` / `Apply` now temporarily clears the Craft filters so queued enchants can still be selected reliably before the filters are restored.
- If they tip during earlier mat trades before the final enchant trade, that gold stays attached to the order until the verified trade retires it automatically.
- Short queues now collapse to give the selected order more vertical room, and long detail panes stay inside the workbench frame with an internal scroll area.
- Requested enchants now show `?` until a settled trade confirms them, then flip to a green check automatically.
- Multi-enchant orders only turn green once every requested enchant has been confirmed automatically.
- The workbench now watches the customer's current trade offer for matching mats and shows each material as `?` or a green check automatically.
- Use the row-level `Inv` and `Msg` buttons to manually re-invite or re-whisper a queued customer when needed.
- Queue rows turn red when an invite fails because the customer is already grouped, then flip back to the normal border once they join your party or raid.
- Customers who are already in your current group now get a green check in both the queue and the detail pane.
- Use `/ec simulate` or `/e simulate` to feed the workbench randomized fake customers without sending any real invites or whispers.
- Accepted trades keep partial mats and early tips attached to the queue entry, and the order retires automatically as soon as a settled trade verifies every requested enchant, even if the live trade offer clears while the window is closing.
- Click the per-order `X` when the order is done or you want to clear it from the queue.
- In settings, you can enable an automatic follow-up whisper for customers who were already in a group, set its delay and message, and optionally auto-expire those grouped queue entries after a chosen number of seconds (`0` keeps them until you clear them).
- If ElvUI is loaded, the workbench adopts ElvUI frame, button, checkbox, and scrollbar styling automatically.

## Contributing

Development and contribution notes are in [`CONTRIBUTING.md`](CONTRIBUTING.md).
Release workflow notes are in [`RELEASING.md`](RELEASING.md).

## Scope

- Target client: TBC Anniversary Classic
- TOC interface: `20505`
- Runtime files are listed in [`Enchanter.toc`](Enchanter.toc)
