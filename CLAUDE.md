# CLAUDE.md

## Target

- iOS 18+
- Swift 6.2 with modern concurrency
- SwiftUI, SwiftData
- SPM only. No third-party frameworks without asking first.
- Avoid UIKit unless a specific API genuinely requires it.

## Architecture

- SwiftData for account metadata, profiles, settings
- Keychain for TOTP/HOTP secret keys
- Custom OTP generation (TOTP + HOTP)
- AVFoundation for QR code scanning
- `@Observable` view models, no MVVM ceremony
- Single `NavigationStack`, all interactions via sheets

## Project structure

- `app/project.yml` — XcodeGen spec. Run `cd app && xcodegen generate` after changes.
- `app/Sesame/` — app source, feature-based folders
  - `Models/` — Account, Profile, enums
  - `Services/` — KeychainService, AccountService, ProfileService, CodeService
  - `Parsers/`, `Extensions/`
- `app/SesameTests/` — unit tests
- `scripts/` — screenshot and video recording

## Sheet modifiers

All interactions use sheets.

- Outermost wrapper: `.sesameSheet(currentDetent:)`
- Form/List/content inside: `.sesameSheetContent()`
- Individual rows: `.sesameRowBackground()`
- Empty states inside sheets: `ContentUnavailableView` + `.safeAreaPadding(.bottom, 20)` + `.sesameSheetContent()`
- Full-height empty states (main account list): `.safeAreaPadding(.bottom, 80)`

Defined in `app/Sesame/Extensions/SesameModifiers.swift`.

## SwiftUI conventions

- Row views inside `List`/`ForEach`: extract into their own `View` structs, not methods.
- Button actions and business logic: extract into methods, not inline in view body.
- Button modifier order: `.bold()`, `.disabled()`, `.tint()`.
- One type per Swift file. File name matches primary type.
- `*Sheet` suffix = standalone sheet wrapper with its own `NavigationStack`. `*View` suffix = everything else.
- `// MARK:` only in files over ~50 lines.

## Fonts

- Account issuer: `.font(.headline)`.
- Account name / secondary: `.font(.subheadline)` + `.foregroundStyle(.secondary)`.
- OTP codes: monospaced, large. `.title2.monospaced()` in list rows; larger in detail/confirmation.

## Error handling

- Destructive actions surface errors via alert, not `try?`.
- Alert pattern: `@State showError: Bool` + `@State errorMessage: String?` + `.alert("Title", isPresented:)`.
- `try?` only for truly ignorable failures (`Task.sleep`).
- `do/catch` with `logger.error(...)` when failure changes behaviour.
- `os.Logger` with appropriate subsystem/category.

## Invariants

- All account mutations go through `AccountService`. Never post notifications manually.
- All profile mutations go through `ProfileService`.
- `AccountService` handles backup scheduling and AutoFill sync as side effects. `ProfileService` handles backup scheduling.
- All code generation goes through `CodeService`. Never call `TOTPGenerator` / `HOTPGenerator` directly.
- Views never read secrets from keychain directly. `CodeService` owns the secret cache.
- `GetCodeIntent` creates its own `CodeService` (runs outside app lifecycle).

## Tests

- Shared doubles in `SesameTests/Support/SesameTestHelpers.swift`. Use `StubKeychain` / `SpyKeychain`.
- In-memory `ModelContainer` + isolated `UserDefaults(suiteName:)` for test isolation.
- UI tests required before release tag, not for regular builds.

## Commands

```bash
cd app && xcodegen generate                    # after editing project.yml
xcodebuild -project app/Sesame.xcodeproj -scheme Sesame -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild test -project app/Sesame.xcodeproj -scheme Sesame -destination 'platform=iOS Simulator,name=iPhone 16'
./scripts/screenshots.sh                       # App Store screenshots
./scripts/record-video.sh                      # marketing videos
```
