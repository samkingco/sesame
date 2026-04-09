---
name: release
description: Release a new build (TestFlight or App Store review) or mark an approved build as shipped. Use when user says "release", "cut a release", "ship it", or wants to upload a build.
user_invocable: true
argument-hint: [marketing version override like "1.2.0" / "minor" / "major" / "patch"]
---

# /release — Release Flow

This project follows iOS conventions: no `CHANGELOG.md`. GitHub Releases are the only changelog. Tag scheme follows DuckDuckGo:

- **Every uploaded build** is tagged `vX.Y.Z-N` where `N` is `CURRENT_PROJECT_VERSION` after bumping.
- **The bare `vX.Y.Z` tag** is reserved for the build that Apple approved and shipped to users. It points at the same commit as the build tag it shipped from (two tags on one commit).

## Step 0: Ask Which Mode

First question — always ask before doing anything else:

```
Are we releasing an approved build? (i.e. Apple just shipped one — we're tagging it as the marketing version) [y/n]
```

- If **yes** → jump to **Ship Mode**.
- If **no** → run the **Build Mode** flow below.

---

# Build Mode

You're uploading a new build (TestFlight or App Store review). This bumps the build number, tags `vX.Y.Z-N`, creates a GitHub Release, and uploads to App Store Connect.

## Step 1: Pre-flight Checks

Run tests and build in parallel:

```bash
xcodebuild test -project app/Sesame.xcodeproj -scheme Sesame -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1
```

```bash
xcodebuild -project app/Sesame.xcodeproj -scheme Sesame -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1
```

If either fails, stop and report. Do not proceed with a broken build.

## Step 2: Determine Version, Build Number, and Release Notes

Read from `app/project.yml` (under the Sesame target settings):
- `MARKETING_VERSION` (e.g. `1.1.0`)
- `CURRENT_PROJECT_VERSION` (e.g. `3`)

**Build number always increments by 1.** Build numbers are monotonic — always increment from the current value, regardless of whether the marketing version bumps. This matches Signal-iOS conventions and gives you unambiguous build identifiers.

### Marketing version suggestion

The semver baseline is the most recent shipped marketing version tag:

```bash
git tag -l "v*" --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1
```

Gather commits since that tag:

```bash
git log <last-shipped-tag>..HEAD --oneline --no-decorate
```

Suggest a semver bump from those commits using conventional commit prefixes:
- any `!:` suffix or `BREAKING CHANGE` in body → **major** bump
- any `feat:` / `feat(` → **minor** bump
- only `fix:` / `chore:` / `docs:` / `refactor:` / `test:` → **patch** bump
- no relevant commits → **none** (build-only bump)

The suggestion is overridden by `$ARGUMENTS` if provided:
- `1.2.0` → set marketing version to `1.2.0` exactly
- `major` / `minor` / `patch` → use that bump level
- `none` / `build` → no marketing bump, just build bump
- (no argument) → present the suggestion and let the user choose

### Per-build release notes

Per-build release notes describe **what's new in this specific build**, not what's new in the marketing version. They should be the diff from the **previous tag** (any kind — could be the previous build tag or the previous marketing tag).

```bash
git describe --tags --abbrev=0 2>/dev/null || echo ""
```

Gather commits since that tag:

```bash
git log <previous-tag>..HEAD --oneline --no-decorate
```

Categorize using conventional commit prefixes:
- `feat:` / `feat(` → Features
- `fix:` / `fix(` → Fixes
- `chore:` / `docs:` / `refactor:` / `test:` → Other (typically omit from user-facing notes — internal stuff like tooling, CI, skill files)

Skip commits whose changes aren't user-facing (purely internal tooling, CI, build infrastructure, skill/docs files). Use judgment.

For the **first build of a new marketing version**, the previous tag will be the previous marketing version, so the notes naturally show everything new in this version. For **subsequent builds of the same marketing version**, the notes show only what changed since the last build (e.g. "fixed the camera permission button").

### Present to user

```
Current: 1.1.0 build 3
Last shipped marketing version: v1.0.0

Suggested: minor bump → 1.2.0 build 4 (tag v1.2.0-4)
  Reason: 4 feat: commits since v1.0.0

Other options:
  - patch  → 1.1.1 build 4
  - none   → 1.1.0 build 4 (just bump build, keep marketing version)
  - custom (specify a version)

Per-build release notes (diff from v1.1.0-3):
### Fixes
- Rename camera permission button to "Continue" (e9d9d3c)

Which version? (default: suggested)
```

Wait for the user to pick. If they accept suggested or specify another bump/version, resolve to a final marketing version + build number combination and confirm before continuing.

## Step 3: Bump Version

Update `app/project.yml`:
- Set `MARKETING_VERSION` to the resolved marketing version (in all 3 targets: `Sesame`, `SesameWidgets`, `SesameAutoFill`)
- Set `CURRENT_PROJECT_VERSION` to the new build number (in all 3 targets)

Run `cd app && xcodegen generate` to regenerate the Xcode project.

## Step 4: Screenshots (Optional)

Ask the user:

```
Generate new screenshots? (runs ./scripts/screenshots.sh — takes a few minutes)
```

If yes, run `./scripts/screenshots.sh` and report results. If no, skip.

## Step 5: Commit and Tag

Stage:
- `app/project.yml`
- Anything regenerated by `xcodegen` (e.g. `app/Sesame.xcodeproj/...`)

Commit with message: `release: vX.Y.Z build N`

Annotated tag at the new commit:

```bash
git tag -a vX.Y.Z-N -m "vX.Y.Z build N"
```

## Step 6: Push and GitHub Release

Ask the user:

```
Ready to push and create GitHub Release?
- git push origin main --tags
- GitHub Release "vX.Y.Z build N" from tag vX.Y.Z-N
```

Wait for confirmation. If confirmed:

```bash
git push origin main --tags
```

Create the GitHub Release using the cumulative notes generated in Step 2:

```bash
gh release create vX.Y.Z-N --title "vX.Y.Z build N" --notes "$(cat <<'EOF'
### Features
- ...

### Fixes
- ...
EOF
)"
```

Mark it as a prerelease so the bare `vX.Y.Z` release (created in ship mode) remains the "Latest" once Apple ships:

```bash
gh release edit vX.Y.Z-N --prerelease
```

## Step 7: App Store Upload (Optional)

Ask the user:

```
Upload to App Store Connect?
- Archive, export .ipa, upload via xcodebuild
- Requires App Store Connect API key (~/.appstoreconnect/private_keys/)
```

If no, skip to summary.

If yes, check that the API key is set up:

```bash
ls ~/.appstoreconnect/private_keys/AuthKey_*.p8 2>/dev/null
```

If no key found:

```
No App Store Connect API key found. To set up:
1. Go to App Store Connect → Users and Access → Integrations → App Store Connect API
2. Generate a new key with Admin role (required for cloud signing)
3. Save the .p8 file to ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8
4. Store your Issuer ID in ~/.appstoreconnect/issuer_id

Then re-run /release — it will pick up the key automatically.
```

If key found, proceed.

### Archive

```bash
xcodebuild archive \
  -project app/Sesame.xcodeproj \
  -scheme Sesame \
  -archivePath build/Sesame.xcarchive \
  -destination 'generic/platform=iOS' \
  2>&1
```

If archive fails, stop and report. Do not proceed.

### Export and Upload

Read the Key ID from the `.p8` filename (`AuthKey_<KEY_ID>.p8`).
Read the Issuer ID from `~/.appstoreconnect/issuer_id`. If the file doesn't exist, ask the user for it.
Read the Team ID from `app/Development.xcconfig` (`DEVELOPMENT_TEAM` value).

Create `build/ExportOptions.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>upload</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>TEAM_ID_HERE</string>
</dict>
</plist>
```

```bash
xcodebuild -exportArchive \
  -archivePath build/Sesame.xcarchive \
  -exportOptionsPlist build/ExportOptions.plist \
  -exportPath build/export \
  -allowProvisioningUpdates \
  -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8 \
  -authenticationKeyID <KEY_ID> \
  -authenticationKeyIssuerID <ISSUER_ID> \
  2>&1
```

Report success or failure.

### Clean up

```bash
rm -rf build/
```

## Step 8: Summary

Report:
- Version and build released (e.g. `1.1.0 build 4`)
- Git tag (`vX.Y.Z-N`)
- GitHub Release URL
- App Store upload status (uploaded / skipped / failed)
- If uploaded: "Build will appear in TestFlight after Apple processes it (usually 10-30 minutes)"
- Reminder: "Once Apple approves and ships this build, run `/release` again and answer 'y' to mark it as the shipped marketing version."

---

# Ship Mode

You answered "yes" at Step 0 — Apple approved a build and you're marking it as the shipped marketing version.

This mode does NOT modify any files in the repo. It only adds a tag at an existing build commit and creates a GitHub Release.

## Step S1: Find the Build to Ship

Make sure local main is up to date:

```bash
git checkout main && git pull --tags
```

Read the current `MARKETING_VERSION` from `app/project.yml`.

Find all build tags matching that marketing version:

```bash
git tag -l "v<MARKETING_VERSION>-*" --sort=-v:refname
```

Default candidate: the most recent one.

Show the user:

```
Latest build tag for v1.1.0:

  v1.1.0-4 — abc1234 release: v1.1.0 build 4

Mark this as the shipped build? (or specify a different build tag)
```

If the user picks a different one, verify it exists:

```bash
git rev-parse --verify <tag> 2>/dev/null
```

## Step S2: Handle Pre-existing Bare Tag

Check if the bare marketing tag already exists locally or on the remote:

```bash
git rev-parse --verify v<MARKETING_VERSION> 2>/dev/null
git ls-remote --tags origin "refs/tags/v<MARKETING_VERSION>"
```

If it exists, ask the user:

```
The bare tag v1.1.0 already exists. Delete it (and its GitHub Release if any) and recreate at the new build commit? [y/n]
```

- If **yes**:
  ```bash
  gh release view v<MARKETING_VERSION> >/dev/null 2>&1 && gh release delete v<MARKETING_VERSION> --yes
  git push origin :refs/tags/v<MARKETING_VERSION>
  git tag -d v<MARKETING_VERSION>
  ```
- If **no**: stop cleanly.

## Step S3: Generate Release Notes

Find the previous shipped marketing version tag:

```bash
git tag -l "v*" --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1
```

Gather commits between the previous shipped tag and the build commit:

```bash
git log <previous-shipped-tag>..<build-tag> --oneline --no-decorate
```

Categorize by conventional commit prefix (Features / Fixes / Other) — same logic as build mode.

Build the release notes:

```markdown
### Features
- Description (commit hash)

### Fixes
- Description (commit hash)
```

Show the notes to the user and ask for confirmation.

## Step S4: Confirm the Plan

Show:

```
About to:
1. Tag the build commit (abc1234) as v1.1.0
2. Push the v1.1.0 tag
3. Create GitHub Release "v1.1.0" from that tag (marked as Latest)

The v1.1.0 tag will sit on the same commit as v1.1.0-4.

Proceed?
```

Wait for confirmation.

## Step S5: Tag, Push, and Release

```bash
git tag -a vX.Y.Z <build-tag>^{commit} -m "vX.Y.Z (shipped, build N)"
git push origin vX.Y.Z
```

Create the GitHub Release. Do NOT pass `--prerelease` — this is the canonical release that should show as "Latest":

```bash
gh release create vX.Y.Z --title "vX.Y.Z" --notes "$(cat <<'EOF'
<release notes from Step S3>
EOF
)" --latest
```

## Step S6: Summary

Report:
- Marketing tag created (`vX.Y.Z`) at commit `abc1234` (same commit as `vX.Y.Z-N`)
- GitHub Release URL — now marked as Latest
- Confirmation that build mode prereleases for this marketing version (`vX.Y.Z-1` … `vX.Y.Z-N`) remain as historical markers

---

## Rules

- Never skip tests in build mode. A failing test suite blocks the release.
- Always wait for user confirmation before: version/build choice, release notes content, pushing, creating GitHub Release, App Store upload, and ship-mode tagging.
- If the user cancels at any gate, stop cleanly — don't leave half-applied changes.
- If cancelled after `project.yml` is written but before commit, warn the user about uncommitted release changes.
- Read the FULL test/build output before diagnosing any failures.
- This project does NOT use a `CHANGELOG.md`. GitHub Releases are the only changelog. Never create or modify a CHANGELOG.md file.
- In ship mode: never modify code or `project.yml`. Only tag and create a GitHub Release.
- In ship mode: the bare `vX.Y.Z` tag must point at the same commit as the build tag it ships from. Two tags on one commit.
- Build releases (`vX.Y.Z-N`) are marked as **prereleases** so the bare `vX.Y.Z` release stays as "Latest" on GitHub.
