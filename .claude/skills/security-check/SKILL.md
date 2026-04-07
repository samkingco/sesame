---
name: security-check
description: Audit vendored dependencies and crypto parameters against upstream sources and known CVEs. Use when user says "security check", "audit deps", "check for CVEs", or wants to verify vendored code is current and secure.
user_invocable: true
---

# /security-check — Security Audit

Audit vendored dependencies and cryptographic parameters against upstream and known vulnerabilities.

## Step 1: Inventory Vendored Dependencies

Scan `app/Vendor/` for vendored code. For each dependency, identify:
- What it is (name, version, upstream repo)
- Which files were vendored
- The commit it was vendored from (check `git log --all -- app/Vendor/` for the commit that added it)

## Step 2: Check Upstream for Changes

For each vendored dependency:
1. Clone the upstream repo to `/tmp` (shallow, depth 1)
2. Compare the vendored files against upstream using `diff -r` (ignore `.git`)
3. Check `git log --oneline -20` on upstream for any commits since the vendored version
4. Report: **up to date** or **N commits behind** with a summary of what changed
5. Clean up the temp clone

## Step 3: Search for CVEs

For each vendored dependency:
1. Web search for `"<dependency name>" CVE site:nvd.nist.gov`
2. Web search for `"<dependency name>" vulnerability <current year>`
3. Report any CVEs found with severity, affected versions, and whether our vendored version is affected

Also search for CVEs against the crypto primitives in use (e.g., AES-256-GCM, Argon2id, CryptoKit).

## Step 4: Verify Crypto Parameters

Read the project's crypto implementation and check parameters against current recommendations:

- **Argon2id**: Web search `OWASP argon2 recommendations <current year>` for latest guidance. Our params should meet or exceed minimums.
- **AES-256-GCM**: Verify nonce size (12 bytes), key size (256 bits), tag size (128 bits / 16 bytes).
- **Salt**: Verify length >= 16 bytes, generated with secure random.
- **Nonce**: Verify generated with secure random, never reused.

## Step 5: Verify File Integrity

For each vendored dependency:
1. Hash all vendored source files with `shasum -a 256`
2. Hash the same files from the upstream clone
3. Flag any files that differ (could indicate accidental modification)

## Step 6: Report

Output a summary:

```
## Security Audit — <date>

### Vendored Dependencies
| Dependency | Version | Upstream Status | CVEs | Action Needed |
|------------|---------|-----------------|------|---------------|

### Crypto Parameters
| Parameter | Current Value | Recommendation | Status |
|-----------|--------------|----------------|--------|

### File Integrity
| Dependency | Files Checked | Modified | Status |
|------------|---------------|----------|--------|
```

If any action is needed, list specific next steps.

## Rules

- Always check the latest upstream, not a cached version
- Be specific about CVE IDs and affected versions
- Don't alarm on CVEs that don't affect the vendored version
- If web search fails, note it explicitly rather than silently skipping
- Clean up any temp clones after the check
