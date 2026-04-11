# Contributing

Thanks for working on `Enchanter`.

This repo stays focused on matching enchanting requests, the minimal UI needed to configure that behavior, and the release pipeline required to ship a clean addon package.

## Local Setup

- Target client: TBC Anniversary Classic
- Addon install path: `World of Warcraft/_anniversary_/Interface/AddOns/`
- Main runtime files are listed in [Enchanter.toc](Enchanter.toc)

## Development

Keep a local Blizzard UI mirror at `../wow-ui-source`. If you do not already have it checked out:

```bash
git clone https://github.com/Gethe/wow-ui-source ../wow-ui-source
```

Refresh the Blizzard UI reference before you start work:

```bash
git -C ../wow-ui-source pull --ff-only
```

Use `../wow-ui-source` first for TOC, interface number, FrameXML, and Blizzard UI/API questions before changing addon code or guessing at client behavior.

Run the local smoke tests:

```bash
lua tests/run.lua
```

Run a syntax check before opening a PR:

```bash
luac -p Enchanter.lua Workbench.lua LibGPIOptions.lua LibGPIToolBox.lua Options.lua Tags.lua tests/run.lua
```

If you change packaging or release behavior, verify the runtime-only package contents too:

```bash
bash ./.github/scripts/verify-release-package.sh
```

## Project Expectations

- Keep the addon focused on enchanting request detection and response.
- Prefer small, targeted changes over broad rewrites.
- If you add a new runtime file, include it in [Enchanter.toc](Enchanter.toc).
- Player-facing packages should only include files the game client actually needs.
- README art and screenshots belong under `assets/`, and `assets/` should stay ignored in `.pkgmeta` so docs do not ship in addon packages.
- Validate changes against the current TBC Anniversary client whenever behavior depends on Blizzard UI or profession APIs.
- When touching the workbench, sanity-check the header `Scan` / `Start` / `Stop` flow, queue refresh behavior, and the active-trade `Apply` / `Use Trade` / verification flow in game when possible.

## Pull Requests

- Use conventional commit titles such as `feat(...)`, `fix(...)`, `docs(...)`, or `ci(...)`.
- Include a short summary of what changed and how you verified it.
- If the change affects game UI, include screenshots or a brief description of the visible behavior.
- Add the `build` label when you want the PR package workflow to post a downloadable addon zip artifact on the PR.
- Keep PRs scoped to one logical change when possible.

## Releases

- Release-specific steps are documented in [RELEASING.md](RELEASING.md).
- Version bumps should update the addon version in [Enchanter.toc](Enchanter.toc), plus any matching references in `README.md`, `CHANGELOG.md`, and release-process docs when they changed.
- Keep `README.md` aligned with the current workbench behavior so release notes do not drift from the actual in-game flow.
- If you change packaging or release workflow expectations, update [RELEASING.md](RELEASING.md) and this file together so contributor instructions do not drift.
- Packaging changes should keep working with both the PR artifact workflow and the GitHub/CurseForge release workflow.
