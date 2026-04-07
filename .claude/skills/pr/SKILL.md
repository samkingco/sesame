---
name: pr
description: Pre-flight checks, SwiftUI review, and open a PR with a changelog-ready description. Use when user says "pr", "open pr", "pull request", or wants to submit their branch for review.
user_invocable: true
argument-hint: [base branch, defaults to main]
---

# /pr — Pull Request Flow

Interactive PR skill. Runs quality checks, then opens a PR with a description written for humans and structured for `/release` changelog generation.

The base branch defaults to `main`. If `$ARGUMENTS` contains a branch name, use that instead.

## Step 0: Branch Check

Verify the current branch is not `main`. If it is, stop:

```
You're on main. Create a feature branch first.
```

Check that there are commits ahead of the base branch:

```bash
git log main..HEAD --oneline
```

If no commits, stop:

```
No commits ahead of main. Nothing to open a PR for.
```

## Step 1: Build

Build the project:

```bash
xcodebuild -project app/Sesame.xcodeproj -scheme Sesame -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1
```

If build fails, stop and report. Do not proceed.

## Step 2: Lint and Format

Run in parallel:

```bash
cd app && swiftlint lint --quiet 2>&1
```

```bash
cd app && swiftformat --lint . 2>&1
```

- **SwiftLint violations**: Show them. If errors (not just warnings), stop.
- **SwiftFormat violations**: Show the files that would change. Offer to run `swiftformat .` to auto-fix, then re-check.

If either tool is not installed, warn and skip that check (don't block the PR).

## Step 3: Tests

Run tests:

```bash
xcodebuild test -project app/Sesame.xcodeproj -scheme Sesame -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1
```

If tests fail, stop and report. Do not proceed.

## Step 4: SwiftUI Pro Review

Check if the `/swiftui-pro` skill was already invoked earlier in this conversation. Look for its output in prior messages (the structured review with before/after code blocks).

- **If already run**: Skip. Tell the user: `SwiftUI review already done this session — skipping.`
- **If not run**: Run the `/swiftui-pro` skill now against all changed `.swift` files in the diff vs the base branch. Present findings to the user. If there are actionable issues, ask if they want to fix them before continuing.

## Step 5: Screenshot Impact

Determine which files changed relative to the base branch:

```bash
git diff main..HEAD --name-only
```

Check if any changed files could affect the screenshotted screens. The screenshot screens and their likely source files:

| Screenshot | Relevant paths (substring match) |
|---|---|
| PersonalList | AccountList, AccountRow, CodeService, CodeCard |
| ProfileSwitcher | Profile, ProfilePicker |
| CopyToast | Toast, Copy, AccountList |
| AddAccount | AddAccount, QRScanner, OTPAuth, ManualEntry |
| ManageProfiles | Profile, ManageProfile |
| Search | Search, AccountList |
| Settings | Settings |

If any changed files match, report:

```
Screenshots potentially affected:
- PersonalList — AccountListView.swift changed
- AddAccount — AddAccountSheet.swift changed

Run ./scripts/screenshots.sh before or after merge to update.
```

If no matches: `No screenshot-affecting changes detected.`

This is advisory only — never block the PR for screenshots.

## Step 5b: TODO/FIXME Check

Scan the diff for any added `TODO` or `FIXME` comments:

```bash
git diff main..HEAD -U0 | grep '^\+' | grep -iE '\bTODO\b|\bFIXME\b' || true
```

If any found, list them:

```
New TODOs/FIXMEs added:
- AccountListView.swift: // TODO: handle empty state
- ProfileService.swift: // FIXME: race condition on delete
```

Ask the user if these are intentional or should be resolved before opening the PR. Advisory only — don't block.

If none found: `No new TODOs or FIXMEs.`

## Step 6: Write PR Description

Gather the full diff and commit history:

```bash
git log main..HEAD --format="%h %s" --reverse
```

```bash
git diff main..HEAD --stat
```

Write the PR title and body following these rules:

### Title
- Short, under 70 characters
- Imperative mood ("Add X" not "Added X" or "Adds X")
- No conventional commit prefix in the title — save that for commits

### Body

Use this template:

```markdown
## What

<1-3 sentences: what this PR does, stated plainly>

## Why

<1-3 sentences: the motivation — what problem it solves or what it enables>

## Changes

<Bulleted list of the meaningful changes. Group by area if touching multiple parts. Skip trivial changes like import reordering.>

## Screenshots impact

<One of: "None" / list of affected screens from Step 5>

## Test plan

- [ ] <How to verify this works — specific steps a reviewer can follow>
```

### Changelog alignment

The commit messages on the branch should already use conventional commit prefixes (`feat:`, `fix:`, `chore:`, etc.). The PR body's "What" and "Changes" sections should give the `/release` skill enough context to write a good changelog entry. If the commits don't use conventional prefixes, note this to the user — don't rewrite history, just flag it.

### Show the draft

Present the full title and body to the user. Wait for approval or edits. Do not create the PR without confirmation.

## Step 7: Push and Create PR

After the user approves the description:

```bash
git push -u origin HEAD
```

```bash
gh pr create --base main --title "<title>" --body "$(cat <<'EOF'
<body>
EOF
)"
```

Report the PR URL when done.

## Rules

- Never skip build or tests. Failures block the PR.
- Lint/format failures with errors block; warnings don't.
- Always wait for user confirmation before creating the PR.
- If the user cancels at any step, stop cleanly.
- If `gh` is not installed or not authenticated, tell the user and stop.
- Read the FULL build/test output before diagnosing failures.
- Don't amend or rewrite commits. Flag issues, let the user decide.
