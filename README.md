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

Current version: `2.1.66`

## What It Does

- Run `/ec scan` once after learning recipes to build your known-enchant list
- Match trade-chat requests against configured recipe tags
- Avoid starting shorthand matches in the middle of unrelated tokens, so posts like `1815 resto druid LF 2's partner` do not trip `15 res`
- Tolerate official full enchant names even when callers omit the separator dash in messages like `Enchant Shield Major Stamina`
- Give scanned enchants outside the built-in shorthand table specific slot/effect fallback aliases, so old-world formulas can still match typed requests without broadening into generic asks
- Split multi-enchant chat lines into local request segments so one phrase does not pollute the whole message
- Expand attached quantity hints like `x2` / `2x` on matched enchants so duplicate asks queue repeated recipe rows and scale their mats totals correctly
- Auto-invite matched players when `Auto Invite` is enabled
- Mark yourself with a star raid icon as soon as a queued customer newly joins your party or raid, so they can find you quickly
- Auto-show the hidden workbench again when a queued customer newly joins your party or raid
- Whisper the matching enchant links with a configurable delay and message prefix
- Randomize recipe whisper prefixes by entering multiple `Message Prefix` choices separated with ` , ` in `/ec config`
- Optionally append `X/Y` to recipe whispers for incomplete orders, and optionally skip auto-handling those partial matches
- Optionally reply to generic `LF enchanter` requests with a custom whisper
- Automatically pause chat matching if you go AFK while it is running
- Optionally pause chat matching automatically once a chosen number of queued customers have joined your group
- Optionally auto-remove queued customers who decline your party invite after a configurable timer
- While the Auction House is open, optionally hand every missing enchant formula to Auctionator from the workbench in one exact-name bulk search
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
- Use the small cog button beside the close `X` to jump straight into `/ec config` from the workbench header.
- Use the padlock icon next to `X` to control whether the workbench frame can be dragged. A gold padlock means it is locked; the green-checked padlock means it is unlocked.
- Use the header `Scan`, `Start`, or `Stop` button to keep the addon ready without leaving the workbench.
- Queued and updated timestamps now use your client-local clock while still following the game's 12-hour or 24-hour display preference.
- If Auctionator is loaded and the Auction House is open, a `Search AH` button appears beside the header controls and bulk-searches your missing enchant formulas by exact `Formula: ...` item names; if your enchanting window is open too, Enchanter refreshes the scan first so the list stays current.
- Use the speaker icon beside `Clear` to decide whether workbench alerts should play a WoW-native sound. Sound waves mean normal alerts, sound waves with a gold `!` mean loud alerts, the muted speaker means alerts are off, and each enabled state plays a short preview through the `Master` channel so muted sound effects do not suppress the queue ping.
- When every requested enchant is verified, the workbench watches live trade gold automatically and retires the order on its own, even if the final tip is `0g`.
- A footer line near the resize grip keeps a rolling `orders / done / tips` summary across reloads and relogs.
- Use the header `Clear` button to wipe the current queue, reset the running totals, and clear the detail pane if you want a fresh slate.
- Drag the `Resize` handle in the lower-right corner to resize the workbench; the queue and detail panes will resize with it.
- When a matching trade is open, the recipe action changes to `Apply` and the detail pane switches into the trade-slot flow.
- `Apply` is an optional shortcut for picking the queued enchant; once both sides accept, the workbench records the trade gold, flips matching mats to green checks, and marks the applied enchant automatically when the trade slot reports it, including late completion updates.
- `Cast` / `Apply` now temporarily clears remembered enchanting profession searches and older Craft filters so queued enchants can still be selected reliably before the previous UI state is restored.
- If they tip during earlier mat trades before the final enchant trade, that gold stays attached to the order until the verified trade retires it automatically.
- Short queues now collapse to give the selected order more vertical room, and long detail panes stay inside the workbench frame with an internal scroll area.
- Requested enchants now show `?` until a settled trade confirms them, then flip to a green check automatically.
- Multi-enchant orders only turn green once every requested enchant has been confirmed automatically.
- Duplicate queued enchants from messages like `Crusader x2` stay as separate rows, so each copy verifies independently while the mats tracker totals both copies together.
- The workbench now watches the customer's current trade offer for matching mats and shows each material as `?` or a green check automatically.
- Use the row-level `Inv` and `Msg` buttons to manually re-invite or re-whisper a queued customer when needed.
- Queue rows turn red when an invite fails because the customer is already grouped, then flip back to the normal border once they join your party or raid.
- Customers who are already in your current group now get a green check in both the queue and the detail pane.
- Use `/ec simulate` or `/e simulate` to feed the workbench randomized fake customers without sending any real invites or whispers.
- Accepted trades keep partial mats and early tips attached to the queue entry, and the order retires automatically as soon as a settled trade verifies every requested enchant, even if the live trade offer clears while the window is closing.
- Click the per-order `X` when the order is done or you want to clear it from the queue.
- In settings, you can enable an automatic follow-up whisper for customers who were already in a group, set its delay and message, and optionally auto-expire those grouped queue entries after a chosen number of seconds (`0` keeps them until you clear them).
- In settings, you can set `Party declined removal timer` so customers who decline your group invite are removed from the queue after a chosen number of seconds (`0` leaves the timer disabled).
- In settings, you can also cap how many queued customers are allowed in your current group before Enchanter pauses itself and later auto-resumes once the group drops back under that limit, optionally send a direct `/thank` emote after a successful applied-enchant trade, and switch workbench sounds over to party-join alerts instead of first-queue-entry alerts.
- If ElvUI is loaded, the workbench adopts ElvUI frame, button, checkbox, and scrollbar styling automatically.

## Contributing

Development and contribution notes are in [`CONTRIBUTING.md`](CONTRIBUTING.md).
Release workflow notes are in [`RELEASING.md`](RELEASING.md).

## Scope

- Target client: TBC Anniversary Classic
- TOC interface: `20505`
- Runtime files are listed in [`Enchanter.toc`](Enchanter.toc)
