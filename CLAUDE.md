# CLAUDE.md

Sesame is a native iOS 2FA authenticator built with Swift and SwiftUI. Fast, native, open source. No accounts, no telemetry, no cloud backend. Your secrets stay on your device by default.

## SwiftUI Patterns

Before writing or editing SwiftUI code, read `.claude/skills/swiftui-pro/references/` and follow those patterns while writing.

## Development Philosophy

- **Simplicity First**: Start with the minimal solution. Add complexity only when proven necessary.
- **No Over-Engineering**: Build only what's needed now, not what might be needed later.
- **Self-Documenting Code**: Prefer clear, readable code with good naming over extensive comments.
- **Avoid Abstraction Layers**: Don't create abstractions for single use cases.
- **Direct Solutions**: If a problem can be solved directly, don't add indirection.

## Target

- iOS 18+
- Swift, SwiftUI, SwiftData
- SPM for dependencies

## Architecture

- **SwiftData** for account metadata, profiles, settings
- **Keychain** for TOTP/HOTP secret keys
- **Custom OTP generation** (TOTP + HOTP)
- **AVFoundation** for QR code scanning
- `@Observable` view models, no MVVM ceremony
- Single `NavigationStack`, all interactions via sheets

## Commands

```bash
# Generate Xcode project (after changing app/project.yml)
cd app && xcodegen generate && cd ..

# Build
xcodebuild -project app/Sesame.xcodeproj -scheme Sesame -destination 'platform=iOS Simulator,name=iPhone 16' build

# Tests
xcodebuild test -project app/Sesame.xcodeproj -scheme Sesame -destination 'platform=iOS Simulator,name=iPhone 16'

# App Store screenshots
./scripts/screenshots.sh

# Record marketing videos
./scripts/record-video.sh
```

## Sheet Conventions

All interactions use sheets. Apply these modifiers consistently:

- **Outermost sheet wrapper:** `.sesameSheet(currentDetent:)` — configures detents, background
- **Form/List/content inside a sheet:** `.sesameSheetContent()` — hides scroll background, clears nav container
- **Individual rows:** `.sesameRowBackground()` — themed row background
- **Empty states:** `ContentUnavailableView` + `.safeAreaPadding(.bottom, 20)` + `.sesameSheetContent()`
- **Full-height empty states** (e.g. main account list): `.safeAreaPadding(.bottom, 80)` instead

See `app/Sesame/Extensions/SesameModifiers.swift` for definitions.

## Project Structure

- `app/` — Xcode project source
  - `project.yml` — XcodeGen spec (generates `Sesame.xcodeproj`)
  - `Sesame/` — app source
    - `Models/` — Account, Profile, enums (SwiftData + Codable)
    - `Services/` — KeychainService
    - `Parsers/` — OTPAuthParser
  - `SesameTests/` — unit tests
- `scripts/` — screenshot and video recording scripts
- `site/` — marketing website

## Error Handling

- Use `try?` only when failure is truly ignorable (e.g. `Task.sleep`)
- Use `do/catch` with `logger.error(...)` for anything where failure changes behaviour or leaves bad state
- Always log at `.error` level using `os.Logger` with appropriate subsystem/category
- User-facing destructive actions (e.g. delete) must surface errors via an alert, not swallow them

## Modifier Ordering

- Standard button modifier order: `.bold()`, `.disabled()`, `.tint()`
- Sheet content views always apply `.sesameSheetContent()`
- Sheet wrappers always apply `.sesameSheet(currentDetent:)`

## Naming

- File names match primary type name
- `*Sheet` suffix = standalone sheet wrapper with its own `NavigationStack`
- `*View` suffix = everything else
- Test doubles: `Stub*` for data stubs, `Spy*` for call trackers. Always `final class`.

## MARK Usage

- Only use `// MARK:` in files over ~50 lines
- MARKs should segment meaningfully different sections, not just label the obvious

## Access Control

- Properties not accessed outside their type should be `private`

## Comments

- Only comment the "why", not the "what"
- Exception: `Task.detached` and other non-obvious patterns should have a brief inline comment explaining the reason

## Account Mutations

- All account create/update/delete mutations must go through `AccountService`
- All profile create/update/delete mutations must go through `ProfileService`
- Never post notifications manually for account changes
- `AccountService` handles backup scheduling and AutoFill sync as side effects
- `ProfileService` handles backup scheduling as a side effect

## Code Generation & Secrets

- All code generation goes through `CodeService`. Never call `TOTPGenerator` or `HOTPGenerator` directly — only `CodeService` calls them
- Never read secrets from keychain directly in views. `CodeService` owns the secret cache and reads from keychain once per account per session
- `GetCodeIntent` creates its own `CodeService` instance since it runs outside the app lifecycle

## Test Patterns

- Use shared test doubles from `SesameTests/Support/SesameTestHelpers.swift`
- Don't create local keychain test doubles — use `StubKeychain` or `SpyKeychain`
- Use in-memory `ModelContainer` and isolated `UserDefaults(suiteName:)` for test isolation
- UI tests must pass before tagging a release — not required for regular development builds
