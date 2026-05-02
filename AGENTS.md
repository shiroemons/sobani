# Repository Guidelines

## Project Structure & Module Organization

Sobani is a macOS 14+ AppKit application written in Swift 6. Main app code lives in `Sobani/`, with feature areas split into focused files and extensions such as `AppDelegate+Hotkey.swift`, `ImageWindow+Positioning.swift`, and `ManagementPanel/`. Unit tests live in `SobaniTests/` and mirror app components with `*Tests.swift` names. User and developer documentation is under `docs/guide/`; the static website assets are in `docs/`. Xcode project settings are in `Sobani.xcodeproj/`. App icons and bundled images are in `Sobani/Assets.xcassets/`.

## Build, Test, and Development Commands

- `./build.sh`: runs `swiftlint --strict`, builds the Release app, and copies `Sobani.app` to the repo root.
- `SKIP_CODESIGN=1 ./build.sh`: builds locally without Developer ID signing.
- `xcodebuild test -project Sobani.xcodeproj -scheme Sobani -destination 'platform=macOS' CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO`: runs the test suite.
- `./test-coverage.sh`: runs tests with coverage and writes logs/reports to `tmp/`.
- `./reset_for_first_launch.sh`: resets local app state for first-launch testing.

## Coding Style & Naming Conventions

Follow SwiftLint rules in `.swiftlint.yml`; line length warns at 160 and errors at 200. Prefer small, named types and extensions grouped by behavior. Use clear Swift names, avoid force unwraps, and keep comments focused on why a non-obvious choice exists. All user-facing UI/menu text should be Japanese. Keep `CLAUDE.md` and `.claude/` local-only; they are ignored and should not be committed.

## Testing Guidelines

Use XCTest in `SobaniTests/`. Name files and types after the unit under test, for example `WindowStateManagerTests.swift`. Focus tests on deterministic logic and persistence behavior; UI-layer classes such as `NSWindow` and `NSImageView` are generally excluded from unit coverage. Add or update tests for bug fixes, edge cases, and error paths. Run the direct `xcodebuild test` command before opening a PR; use `./test-coverage.sh` when changing shared logic.

## Commit & Pull Request Guidelines

Git history uses Conventional Commits in Japanese, for example `feat: ...`, `fix: ...`, `docs: ...`, `test: ...`, `refactor: ...`, and `chore: ...`. Keep commits atomic and descriptive. Branch names should use `feature/` for new work. PRs should include a concise summary, test results, linked issues when applicable, and screenshots or short recordings for visible UI changes.

## Security & Release Notes

Do not hardcode Apple credentials, Sparkle keys, or notarization secrets; use environment variables and GitHub Secrets. Changes to `Sobani/Assets.xcassets/character.imageset/` require owner approval via `.github/CODEOWNERS`. Release tags use `vYYYYMM.N`, and release automation builds a notarized universal app.
