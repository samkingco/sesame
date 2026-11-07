# Architecture

Sesame is a SwiftUI app for iOS 18+, with no third-party dependencies. The Xcode project is generated from `app/project.yml` with XcodeGen, so add files and targets there, not in Xcode.

## Targets

- `Sesame`: the app.
- `SesameWidgets`: the copied-code Live Activity and Dynamic Island.
- `SesameAutoFill`: the AutoFill extension that fills one-time codes into login screens.
- `SesameDecrypt`: a Mac command-line tool that decrypts `.sesame` backups without the app.
- `CArgon2`: the vendored Argon2 reference implementation, used for backup encryption.
- `SesameTests`, `SesameUITests`, `SesameScreenshots`: unit tests, UI tests, and the App Store screenshot run.

The extensions compile a few files from `app/Sesame` directly. `project.yml` lists them.

## Data

Account and profile metadata lives in SwiftData, in an App Group container so the AutoFill extension can read it (`SharedModelContainer`). Secrets never go in SwiftData. Each account's secret lives in the Keychain, keyed by the account's ID (`KeychainService`).

Deleted accounts stay in Recently Deleted for 48 hours, then `PurgeService` removes them.

## Services

The rules that keep data consistent live in `app/Sesame/Services`:

- All account changes go through `AccountService`. It saves the secret, schedules a backup and syncs AutoFill after each change.
- All profile changes go through `ProfileService`, which schedules a backup.
- All codes come from `CodeService`. It owns the in-memory secret cache, so views never read the Keychain or call `TOTPGenerator` / `HOTPGenerator` themselves.

Two places run outside the app and set up their own access: `GetCodeIntent` (Siri and Shortcuts) creates its own `CodeService`, and the AutoFill extension reads the Keychain and generates codes itself.

## Backups

`app/Sesame/Backup` builds an encrypted payload (AES-GCM, Argon2id key) and writes it to iCloud Drive or a `.sesame` file. `BackupStore` debounces automatic backups after changes. `RestoreService` reads them back, and `SesameDecrypt` can read the same format.

## UI

There is one main screen, the account list. Profiles show in a sidebar when there is room (iPad, iPhone Duo open) and in a toolbar menu otherwise. Everything else opens in a sheet. The shared sheet styling is in `app/Sesame/Extensions/SesameModifiers.swift`.

## Tests

Unit tests use `StubKeychain` and `SpyKeychain` from `app/SesameTests/Support/SesameTestHelpers.swift`, an in-memory `ModelContainer`, and their own `UserDefaults(suiteName:)`, so no test touches real data.

## Scripts

- `scripts/screenshots.sh`: App Store screenshots for each device size, into `media/appstore`. It deletes the old set first.
- `scripts/record-video.sh`: marketing videos.
- `scripts/recipe.sh`: screenshots of single app states by name (for example `enlarged-code-warning`), into `media/recipes`.
