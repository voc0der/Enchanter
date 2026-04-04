# Release Process

## Automated Process

Every push to `main` triggers an automatic release via GitHub Actions:
- Reads the version from `Enchanter.toc`
- Creates a git tag if one does not already exist for that version
- Tag push triggers the packager workflow
- `BigWigsMods/packager` builds the release zip and uploads to GitHub and CurseForge when CurseForge metadata is configured

Update the version in `Enchanter.toc` before pushing.

## Prerequisites

- `RELEASE_PAT` repository secret:
  - Fine-grained PAT with repo `Contents: Read and write`
  - Required so workflow-created tag pushes can trigger downstream workflows
- `CF_API_KEY` repository secret:
  - Required for CurseForge upload in the packager step
- `## X-Curse-Project-ID: <id>` in `Enchanter.toc`:
  - Required by packager to know which CurseForge project to publish to

## Manual Steps (For Major/Minor Releases)

### 1. Update Version

Update `## Version:` in `Enchanter.toc` to a version that is not already tagged.

### 2. Update CHANGELOG.md

```markdown
## [Unreleased]

### Added
- New feature description

### Fixed
- Bug fix description
```

### 3. Commit and Push

```bash
git add Enchanter.toc CHANGELOG.md
git commit -m "Release v2.1.X"
git push
```

The CI pipeline handles tagging and packaging automatically.

If no new tag appears, check whether the tag for that version already exists.

## Version Numbering

Follow [Semantic Versioning](https://semver.org/):
- MAJOR (`v3.0.0`): Breaking changes
- MINOR (`v2.2.0`): New features, backwards-compatible
- PATCH (`v2.1.1`): Bug fixes, backwards-compatible
