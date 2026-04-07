# Project Conventions

These are project-specific patterns that should be enforced alongside the general SwiftUI rules. Flag violations the same way as any other issue.


## Sheet modifiers

This project uses a consistent set of view modifiers for all sheet-based UI. Flag any sheet content that is missing these.

- The outermost view of every sheet must use `.sesameSheet(currentDetent:)` to configure detents and presentation background.
- Every `Form`, `List`, or scrollable content view inside a sheet must use `.sesameSheetContent()` to hide the scroll background and clear the navigation container background.
- Every row inside a `Form` or `List` in a sheet must use `.sesameRowBackground()` for themed row backgrounds.
- Empty states inside sheets must use `ContentUnavailableView` with `.safeAreaPadding(.bottom, 20)` and `.sesameSheetContent()`. Full-height empty states (e.g. the main account list, not inside a sheet) use `.safeAreaPadding(.bottom, 80)` instead.

These modifiers are defined in `Sesame/Extensions/SesameModifiers.swift`.


## View extraction

- Row views inside `List`/`ForEach` should be extracted into their own `View` structs, not returned from methods.
- Button actions and business logic must not be inline in the view body; extract into methods.


## Error handling

- User-initiated destructive actions (e.g. delete) must surface Keychain or persistence errors via an alert, not swallow them with `try?`.
- Use the established pattern: `@State showError: Bool` + `@State errorMessage: String?` + `.alert("Title", isPresented:)`.
- Use `try?` only when failure is truly ignorable (e.g. `Task.sleep`).
- Use `do/catch` with `logger.error(...)` for anything where failure changes behaviour or leaves bad state.
- Always log errors using `os.Logger` with appropriate subsystem/category.


## Naming

- File names match primary type name.
- `*Sheet` suffix = standalone sheet wrapper with its own `NavigationStack`.
- `*View` suffix = everything else.

## Modifier ordering

- Standard button modifier order: `.bold()`, `.disabled()`, `.tint()`.

## Access control

- Properties not accessed outside their type should be `private`.

## Comments

- Only comment the "why", not the "what".
- Exception: `Task.detached` and other non-obvious patterns should have a brief inline comment explaining the reason.

## MARK usage

- Only use `// MARK:` in files over ~50 lines.
- MARKs should segment meaningfully different sections, not just label the obvious.

## Account mutations

- All account create/update/delete mutations must go through `AccountService`.
- Never post notifications manually for account changes.
- `AccountService` handles backup scheduling and AutoFill sync as side effects.

## Code generation & secrets

- All code generation goes through `CodeService`. Never call `TOTPGenerator` or `HOTPGenerator` directly — `CodeService` is the sole caller.
- Never read secrets from keychain directly in views. `CodeService` owns the secret cache and is the only in-app consumer of `KeychainServiceProtocol.read(for:)` for OTP secrets.
- `GetCodeIntent` creates its own `CodeService` instance since it runs outside the app lifecycle.

## Font usage

- Account issuer labels use `.font(.headline)`.
- Account name / secondary labels use `.font(.subheadline)` with `.foregroundStyle(.secondary)`.
- OTP codes use monospaced fonts at large sizes: `.title2.monospaced()` in list rows, larger in detail/confirmation views. Prefer larger sizes for codes — they are the primary content.
- Match these sizes in any view that displays account information.
