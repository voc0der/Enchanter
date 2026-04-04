# Releasing to CurseForge

## TBC Anniversary Support

Enchanter targets TBC Anniversary Classic. The TOC file specifies:

```
## Interface: 20505
```

## Workflow Prerequisites

Before automated release can work end-to-end, configure:

1. GitHub Actions secret `RELEASE_PAT`
   - Fine-grained token with repository `Contents: Read and write`
   - Needed so tag pushes created by GitHub Actions can trigger the downstream release workflow
2. GitHub Actions secret `CF_API_KEY`
   - CurseForge API token used by `BigWigsMods/packager`
3. CurseForge project metadata in addon TOC
   - Add `## X-Curse-Project-ID: <your_project_id>` to `Enchanter.toc`
   - Without this, packager can still build archives and GitHub releases but cannot upload to CurseForge

## Release Process

### Automated (GitHub Actions)

1. Update version in `Enchanter.toc`
2. Update `CHANGELOG.md` with release notes
3. Commit and push to `main`
4. CI automatically creates a tag from the TOC version and triggers the packager

### PR Build Artifacts

- Add the `build` label to a pull request when you want the PR packaging workflows to post a downloadable addon zip artifact comment for that PR head commit.

### Troubleshooting

- No new tag created:
  - Check `## Version:` in `Enchanter.toc` is bumped (for example `2.1.1`)
  - If the tag already exists (for example `v2.1.1`), the workflow skips by design
- Tag created but no CurseForge upload:
  - Confirm `CF_API_KEY` exists in repo secrets
  - Confirm `## X-Curse-Project-ID:` is set to a valid numeric project ID
- Tag workflow failing authentication:
  - Confirm `RELEASE_PAT` exists and has repo contents write permissions
  - If using org SSO, ensure the token is authorized for the org

### Manual Upload to CurseForge

1. Create a zip file:
   ```bash
   cd /home/vocoder/Code/Enchanter
   bash ./.github/scripts/stage-addon.sh ./dist/Enchanter
   cd dist
   zip -r Enchanter-v2.1.X.zip Enchanter
   ```
2. Upload at your CurseForge project files page.

## What Gets Released

Only runtime addon files should ship to players.

The PR package workflow stages files directly from `Enchanter.toc`, and the release workflow verifies that `.pkgmeta` produces the same runtime-only tree before uploading to GitHub and CurseForge.

For the current addon, the packaged game files are:
- `Enchanter.toc`
- `LibGPIOptions.lua`
- `LibGPIToolBox.lua`
- `Tags.lua`
- `Options.lua`
- `Enchanter.lua`
- `Enchanter.xml`

Non-game files such as docs, `tests/`, `.github/`, and fork-maintenance notes must stay out of the final addon archive.
