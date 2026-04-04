# Enchanter

- Helps enchanters catch trade-chat requests that match recipes they actually know
- Scans your known enchanting recipes and stores match tags per character
- Can auto-invite matched players and whisper recipe links for the enchants you can perform
- Includes an Anniversary-oriented settings panel and packaging workflow for fork maintenance

Current version: `2.1.0`

## What It Does

- Run `/ec scan` once after learning recipes to build your known-enchant list
- Match trade-chat requests against configured recipe tags
- Auto-invite matched players when `Auto Invite` is enabled
- Whisper the matching enchant links with a configurable delay and message prefix
- Optionally reply to generic `LF enchanter` requests with a custom whisper

## Install

1. Download the latest GitHub release when one is available.
2. Extract the `Enchanter` folder into:
   `World of Warcraft/_anniversary_/Interface/AddOns/`
3. Start the game and make sure the addon is enabled.

## Usage

- `/ec scan`: Scan and store your known enchanting recipes. Run this before `/ec start` and any time you learn a new recipe.
- `/ec start`: Start matching chat messages.
- `/ec stop` or `/ec pause`: Stop matching chat messages.
- `/ec config`: Open the addon settings.
- `/ec debug`: Toggle debug output.
- `/ec summary`: Print session earnings from completed trades.
- `/ec about`: Print usage help.

## Contributing

Development and contribution notes are in [`CONTRIBUTING.md`](CONTRIBUTING.md).
Release workflow notes are in [`RELEASING.md`](RELEASING.md).
Fork-specific migration notes are in [`TBC_ANNIVERSARY_NOTES.md`](TBC_ANNIVERSARY_NOTES.md).

## Scope

- Target client: TBC Anniversary Classic
- TOC interface: `20505`
- Runtime files are listed in [`Enchanter.toc`](Enchanter.toc)
