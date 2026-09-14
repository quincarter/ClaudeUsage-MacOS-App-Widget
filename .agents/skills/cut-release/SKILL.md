---
name: cut-release
description: >-
  Cuts a new version and publishes a release for ClaudeUsage in seconds using scripts/release.sh.
  Use this skill whenever the user asks to "cut a release", "publish a release", "bump version and release",
  "create a release", or "release a new version".
---

# Cut & Publish Release Workflow

Use this skill to deterministically bump the app version, synchronize project metadata, create git tags, and trigger GitHub Actions release packaging in seconds.

## Quick Reference Commands

| Release Goal | Command | Description |
| :--- | :--- | :--- |
| **Patch Release** (Default) | `./scripts/release.sh` | Increments patch version (e.g. `1.1.0` -> `1.1.1`, build `2` -> `3`). |
| **Minor Release** | `./scripts/release.sh minor` | Increments minor version (e.g. `1.1.0` -> `1.2.0`, build `2` -> `3`). |
| **Major Release** | `./scripts/release.sh major` | Increments major version (e.g. `1.1.0` -> `2.0.0`, build `2` -> `3`). |
| **Explicit Version** | `./scripts/release.sh <version>` | Sets an exact version (e.g. `./scripts/release.sh 1.2.5`). |
| **Local DMG Build** | `./scripts/release.sh --local` | Builds DMG locally and publishes via `gh release create`. |
| **Dry Run Preview** | `./scripts/release.sh --dry-run` | Previews version calculations without making any file or git changes. |

---

## Step-by-Step Procedure

### 1. Pre-Flight Verification
Always ensure tests pass before cutting a release:
```bash
xcodebuild test -scheme ClaudeUsageTests -destination 'platform=macOS'
```
Confirm the working tree is clean and on `main`:
```bash
git status
```

### 2. Execute the Release Script
Run the release cutter with the desired bump type (e.g. patch, minor, major, or explicit):
```bash
./scripts/release.sh [patch|minor|major|<version>]
```

The script automatically executes the following deterministic steps in ~2 seconds:
1. Reads current `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` from `project.yml`.
2. Calculates the next version and increments the build number.
3. Synchronizes `project.yml`, `README.md`, and `scripts/build_dmg.sh`.
4. Runs `xcodegen generate --quiet` to regenerate `ClaudeUsage.xcodeproj` and sync both app and widget `Info.plist`s.
5. Commits changes: `chore(release): cut vX.Y.Z (build N)`.
6. Creates annotated git tag `vX.Y.Z`.
7. Pushes the commit and tag to `origin/main`.

### 3. Verification
Verify that the tag was pushed and GitHub Actions was triggered:
```bash
git tag -l -n1 "v*"
gh run list --workflow=release.yml --limit 1
```

- **GitHub Actions Runner**: Automatically compiles the Release configuration on `macos-14`, packages `dist/ClaudeUsage-vX.Y.Z.dmg`, and publishes the GitHub Release with download assets.
- **Track Release URL**: `https://github.com/quincarter/ClaudeUsage-MacOS-App-Widget/releases`
