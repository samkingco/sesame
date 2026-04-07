# Sesame

An unremarkably good 2FA app for iPhone.

Get the app:
- [Website](https://opensesame.software)
- [App Store](https://apps.apple.com/us/app/sesame-2fa-authenticator/id6761735240)

## Why Sesame?

Feels like it came with your phone. 2FA the way it should be. Fast, light, and familiar.

Profiles for personal, work, side projects, or however you organise your life.

Enable iCloud backups to give you peace of mind. Or backup to an encrypted file you can store wherever you like.

Works with Siri and Spotlight. Search is instant. Fully private and secure.

Free and open source. Read it, build it, audit it.

## Features

### Codes
- TOTP and HOTP code generation
- Scan QR codes or enter accounts manually
- Tap to copy, with auto-clear clipboard on a timer

### Profiles
- Group accounts into profiles — keep work separate from personal, or organize however you like
- Color-coded profiles with drag-and-drop reordering
- Search across all profiles at once

### Backup & Restore
- **iCloud backup** — encrypted backups stored in your iCloud Drive, synced across your devices
- **Export to file** — save an encrypted `.sesame` backup file anywhere you want
- **Restore** — import from iCloud or from a file
- Encryption uses AES-GCM with Argon2id key derivation. Your backup is useless without your password.
- The repo includes a [standalone decrypt tool](#sesame-decrypt) — you can recover your data without the app, on any Mac, using only open source code. No lock-in.

### Apple Integrations
- **Siri & Shortcuts** — ask Siri for a code or build automations with the Shortcuts app
- **AutoFill** — fill one-time codes directly into login screens without switching apps
- **Spotlight** — find accounts from your home screen

### Security
- Biometric lock (Face ID / Touch ID) with configurable auto-lock delay
- Privacy screen — blurs the app when you switch away
- Recently deleted accounts with a 48-hour recovery window

## Requirements

- iOS 18+
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/xcodegen)

## Building

Sesame uses XcodeGen to generate the Xcode project from `app/project.yml`.

```bash
# Generate the Xcode project
cd app && xcodegen generate && cd ..

# Build
xcodebuild -project app/Sesame.xcodeproj -scheme Sesame -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run tests
xcodebuild test -project app/Sesame.xcodeproj -scheme Sesame -destination 'platform=iOS Simulator,name=iPhone 16'
```

To run on a physical device, copy `app/Development.xcconfig.example` to `app/Development.xcconfig` and fill in your Apple Developer Team ID.

### Build flags

Some features require a paid Apple Developer account and specific entitlements. These are gated behind compilation flags so contributors can build and test without them.

| Flag | What it enables | Requires paid account? |
|------|----------------|----------------------|
| `ICLOUD_CAPABLE` | iCloud Drive backup and restore | Yes |
| `AUTOFILL_CAPABLE` | AutoFill credential provider extension | Yes |
| `APPGROUP_CAPABLE` | Shared container between app and extensions | Yes |
| `DEMO_ENABLED` | Demo mode for screenshots and videos (Debug only) | No |

All four are set in `app/project.yml` under `SWIFT_ACTIVE_COMPILATION_CONDITIONS`. The default config enables all of them, but builds will succeed without the paid-account features — those code paths compile out cleanly. The AutoFill extension target (`SesameAutoFill`) is commented out by default in the scheme for the same reason.

## sesame-decrypt

A standalone command-line tool that decrypts `.sesame` backup files and outputs the JSON payload. No app required — just a Mac and your backup password.

This exists so you can verify what's in your backups and recover your data even if the app disappears.

```bash
# Build
cd app && xcodegen generate && cd ..
xcodebuild -project app/Sesame.xcodeproj -scheme SesameDecrypt -configuration Release build

# Find the binary
BINARY=$(xcodebuild -project app/Sesame.xcodeproj -scheme SesameDecrypt -configuration Release -showBuildSettings | grep -m1 BUILT_PRODUCTS_DIR | awk '{print $3}')/sesame-decrypt

# Decrypt a backup (prompts for password)
$BINARY backup.sesame

# Or pipe the password
echo 'your-password' | $BINARY backup.sesame

# Pipe to jq to extract specific fields
$BINARY backup.sesame | jq '.accounts[] | {issuer, name}'
```

## Contributing

Contributions are welcome. Open an issue first to discuss what you'd like to change.

## License

[MIT](LICENSE)
