# Contributing

Thanks for working on `Enchanter`.

This repo stays focused on matching enchanting requests, the minimal UI needed to configure that behavior, and the release pipeline required to ship a clean addon package.

## Local Setup

- Target client: TBC Anniversary Classic
- Addon install path: `World of Warcraft/_anniversary_/Interface/AddOns/`
- Main runtime files are listed in [Enchanter.toc](Enchanter.toc)

## Development

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
- Version bumps should update the addon version in [Enchanter.toc](Enchanter.toc), plus any matching references in docs or changelog entries.
- Keep `README.md` aligned with the current workbench behavior so release notes do not drift from the actual in-game flow.
- Packaging changes should keep working with both the PR artifact workflow and the GitHub/CurseForge release workflow.
