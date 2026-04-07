# Contributing

Thanks for considering contributing to Sesame.

## Before you start

Open an issue before writing code. This lets us discuss the approach and avoid wasted effort. Bug reports and small fixes don't need this — just open a PR.

## What we're looking for

- Bug fixes
- Accessibility improvements
- Performance improvements
- Test coverage

## What we'll probably decline

- **Third-party dependencies.** Sesame has zero runtime dependencies and we intend to keep it that way. The only vendored code is the Argon2 reference implementation for backup encryption.
- **Cloud features or accounts.** Sesame is deliberately offline-first with no backend.
- **Cross-platform support.** iOS only, built with SwiftUI. No abstraction layers.
- **Feature bloat.** Sesame is a 2FA app. If a feature doesn't directly serve that purpose, it probably doesn't belong here.

## Setting up

1. Install [XcodeGen](https://github.com/yonaskolb/xcodegen): `brew install xcodegen`
2. Generate the Xcode project: `cd app && xcodegen generate`
3. Open `app/Sesame.xcodeproj` in Xcode
4. To run on a physical device, copy `app/Development.xcconfig.example` to `app/Development.xcconfig` and fill in your Team ID

## Running tests

```bash
xcodebuild test -project app/Sesame.xcodeproj -scheme Sesame -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Pull requests

- Keep PRs focused. One concern per PR.
- Make sure tests pass before submitting.
- Follow the existing code style — read the code around what you're changing and match it.
- No generated file changes. `Sesame.xcodeproj` is gitignored and generated from `app/project.yml`. If you need to add files or targets, edit `project.yml`.

## Code style

- Optimise for readability. Code should be easy to skim.
- Use early returns.
- Avoid cleverness.
- Don't add abstractions for single use cases.
- Don't add comments that restate what the code does. Add comments that explain why.
