---
name: release
description: Walk through a full release — tests, version bump, changelog, screenshots, git tag, GitHub Release. Use when user says "release", "cut a release", "ship it", or wants to publish a new version.
user_invocable: true
argument-hint: [version override, e.g. "1.2.0" or "major"]
---

# /release — Release Flow

Interactive release skill. Guides through the full release process, confirming at each gate.

## Step 1: Pre-flight Checks

Run tests and build in parallel:

```bash
xcodebuild test -project app/Sesame.xcodeproj -scheme Sesame -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1
```

```bash
xcodebuild -project app/Sesame.xcodeproj -scheme Sesame -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1
```

If either fails, stop and report. Do not proceed with a broken build.

## Step 2: Determine Version

Read the current version from `app/project.yml` (`MARKETING_VERSION` under the Sesame target settings).

Find the last git tag matching `v*`. If no tags exist, treat all commits as new.

Gather commits since the last tag:

```bash
git log <last-tag>..HEAD --oneline --no-decorate
```

Categorize commits using conventional commit prefixes:

- `feat:` or `feat(` → minor bump
- `fix:` or `fix(` → patch bump
- `BREAKING CHANGE` in body, or `!:` suffix → major bump
- `chore:`, `docs:`, `refactor:`, `test:` → no bump (but still included in changelog)

Suggest the highest applicable bump. For example, if there are both `feat:` and `fix:` commits, suggest minor.

If `$ARGUMENTS` contains a version string (e.g. `1.2.0`) or a bump level (`major`, `minor`, `patch`), use that instead of the suggestion.

Present to the user:

```
Current version: X.Y.Z
Suggested bump: minor → X.(Y+1).0

Commits since last release:
### Features
- feat: description
### Fixes
- fix: description
### Other
- chore: description

Proceed with X.(Y+1).0? (or specify a different version)
```

Wait for confirmation. Do not proceed without it.

## Step 3: Update Changelog

Read `CHANGELOG.md` if it exists. If not, create it.

Add a new entry at the top (below the heading) in this format:

```markdown
## [X.Y.Z] — YYYY-MM-DD

### Features
- Description (commit hash)

### Fixes
- Description (commit hash)

### Other
- Description (commit hash)
```

Only include sections that have entries. Use the commit's short description, not the full message. Include the short hash as a reference.

Show the user the changelog entry and ask for confirmation before writing.

## Step 4: Bump Version

Update `app/project.yml`:
- Set `MARKETING_VERSION` to the new version
- Increment `CURRENT_PROJECT_VERSION` by 1

Run `cd app && xcodegen generate` to regenerate the Xcode project.

## Step 5: Screenshots (Optional)

Ask the user:

```
Generate new screenshots? (runs ./scripts/screenshots.sh — takes a few minutes)
```

If yes, run `./scripts/screenshots.sh` and report results.
If no, skip.

## Step 6: Commit and Tag

Stage the changed files:
- `CHANGELOG.md`
- `app/project.yml`

Commit with message: `release: vX.Y.Z`

Create an annotated tag:

```bash
git tag -a vX.Y.Z -m "vX.Y.Z"
```

## Step 7: Push and GitHub Release

Ask the user:

```
Ready to push and create GitHub Release?
- git push origin main --tags
- GitHub Release from tag vX.Y.Z with changelog as body
```

Wait for confirmation.

If confirmed:

```bash
git push origin main --tags
```

Create the GitHub Release using the changelog entry as the body:

```bash
gh release create vX.Y.Z --title "vX.Y.Z" --notes "$(cat <<'EOF'
<changelog entry content>
EOF
)"
```

## Step 8: App Store Upload (Optional)

Ask the user:

```
Upload to App Store Connect?
- Archive, export .ipa, upload via altool
- Requires App Store Connect API key (~/.appstoreconnect/private_keys/)
```

If no, skip to summary.

If yes, first check that the API key is set up:

```bash
ls ~/.appstoreconnect/private_keys/AuthKey_*.p8 2>/dev/null
```

If no key found, tell the user:

```
No App Store Connect API key found. To set up:
1. Go to App Store Connect → Users and Access → Integrations → App Store Connect API
2. Generate a new key (Admin role)
3. Save the .p8 file to ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8
4. Note your Key ID and Issuer ID

Then re-run /release — it will pick up the key automatically.
```

If key found, proceed:

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

### Export IPA

Create `build/ExportOptions.plist` with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>destination</key>
    <string>upload</string>
</dict>
</plist>
```

```bash
xcodebuild -exportArchive \
  -archivePath build/Sesame.xcarchive \
  -exportOptionsPlist build/ExportOptions.plist \
  -exportPath build/export \
  2>&1
```

### Upload

Read the API key ID from the filename (`AuthKey_<KEY_ID>.p8`) and ask the user for their Issuer ID if not previously stored.

```bash
xcrun altool --upload-app \
  --type ios \
  --file build/export/Sesame.ipa \
  --apiKey <KEY_ID> \
  --apiIssuer <ISSUER_ID> \
  2>&1
```

Report success or failure. If successful, note that the build will appear in App Store Connect / TestFlight after processing.

### Clean up

```bash
rm -rf build/
```

## Step 9: Summary

Report:
- Version released
- Git tag
- GitHub Release URL
- App Store upload status (uploaded / skipped / failed)
- If uploaded: "Build will appear in TestFlight after Apple processes it (usually 10-30 minutes)"

## Rules

- Never skip tests. A failing test suite blocks the release.
- Always wait for user confirmation before: version choice, changelog content, pushing, creating GitHub Release.
- If the user cancels at any gate, stop cleanly — don't leave half-applied changes.
- If cancelled after changelog/version changes are written but before commit, warn the user about uncommitted release changes.
- Read the FULL test/build output before diagnosing any failures.
