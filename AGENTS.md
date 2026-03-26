# AGENTS.md - SpeakYourMind Agent Guide

## Project Snapshot
- Repo: `lpointer`
- Product: `SpeakYourMind`, a macOS menu bar dictation app
- Stack: Swift 5.9+, SwiftUI, AppKit, Swift Package Manager
- Target platform: macOS 13+
- Package shape: one executable target and one test target

## Repository Rules Scan
- Existing root `AGENTS.md` was present and has been refreshed.
- No `.cursor/rules/` directory was found.
- No `.cursorrules` file was found.
- No `.github/copilot-instructions.md` file was found.
- Do not assume any extra editor-specific rules beyond this file.

## Source of Truth
- `Package.swift` - package manifest, targets, dependencies, platform
- `SpeakYourMind/` - production app code
- `SpeakYourMindTests/` - XCTest suite
- `TESTING.md` - automated and manual QA notes
- `clean.sh` and `install.sh` - local maintenance scripts

## Important Repo Reality
- This is a SwiftPM-first repo.
- No `.xcodeproj` exists in the repository.
- `CONTRIBUTING.md` mentions `SpeakYourMind.xcodeproj`; treat that as stale.
- Prefer commands that work directly from repo root.

## Build, Run, Test, and Maintenance

### Resolve Dependencies
```bash
swift package resolve
```

### Build
```bash
swift build
swift build -c release
```

### Run
```bash
swift run
.build/debug/SpeakYourMind
open ~/Applications/SpeakYourMind.app
```

### Test
```bash
swift test
swift test --filter SpeechManagerTests
swift test --filter SpeechManagerTests/test_initialState_isNotListening
swift test --filter PermissionsManagerTests
swift test --filter TextInjectorTests
```

### Single-Test Guidance
- Run one suite: `swift test --filter <TestClass>`
- Run one method: `swift test --filter <TestClass>/<testMethod>`
- Verified example: `swift test --filter SpeechManagerTests/test_initialState_isNotListening`

### Local Scripts
```bash
./clean.sh
./install.sh
```
- `./clean.sh` removes `.build`, removes `~/Applications/SpeakYourMind.app`, and kills a running app instance.
- `./install.sh` builds release output and recreates `~/Applications/SpeakYourMind.app`.

## Lint and Formatting Status
- No dedicated lint command is configured.
- No `SwiftLint` config file was found.
- No repo-local `swiftformat` config file was found.
- Optional formatter command referenced in docs:
```bash
swiftformat . --swiftversion 5.9
```
- Only run `swiftformat` if installed.
- Do not invent a `swiftlint` step unless the repo adds it.

## Recommended Verification Order
1. `swift build`
2. `swift test --filter <relevant suite or method>`
3. `swift test`
4. `swift build -c release` when touching packaging or install behavior

## Package and Target Names
- Executable target: `SpeakYourMind`
- Test target: `SpeakYourMindTests`
- Dependencies: `KeyboardShortcuts`, `LaunchAtLogin-Modern` via product `LaunchAtLogin`

## Project Layout
```text
SpeakYourMind/
├── Models/
├── Services/
├── Utils/
├── ViewModels/
├── Views/
└── Info.plist

SpeakYourMindTests/
```

## Architecture Conventions
- Follow MVVM: Views -> ViewModels -> Services.
- Keep orchestration in focused services such as `InstantRecordCoordinator`.
- Shared helpers often use singleton access, e.g. `Logger.shared` and `UserFeedbackManager.shared`.
- Prefer focused services over pushing business logic into SwiftUI views.

## Import Conventions
- Keep imports at the top of the file.
- Use minimal imports and remove unused ones.
- Production files typically import Apple frameworks first, then package imports.
- Common imports here: `Foundation`, `AppKit`, `SwiftUI`, `Combine`.
- In tests, place `@testable import SpeakYourMind` after framework imports.

## Formatting Conventions
- Use 4 spaces for indentation.
- Use K&R brace style.
- Prefer lines around 100 characters or less.
- Use one blank line between logical blocks.
- Use `// MARK: - Section Name` in longer files.
- Match surrounding wrapping and comma style instead of reformatting unrelated code.

## Naming Conventions
- Types: `PascalCase`
- Variables, properties, methods: `camelCase`
- Test classes: `<Subject>Tests`
- Test methods: `test_<scenario>_<expectedOutcome>`
- Views often end in `View` or `Panel`.
- Services often end in `Manager`, `Coordinator`, or utility names like `TextInjector`.
- Notification names are defined in `extension Notification.Name`.

## Type and API Design
- Prefer `final class` for new reference types unless subclassing is intentional.
- Use `struct` for plain data models.
- Use enums for finite UI modes, domain states, and error categories.
- Use `ObservableObject` and `@Published` for UI-observed state.
- Prefer simple closure callbacks over protocols when that keeps the design smaller.

## Error Handling
- Prefer domain-specific error enums conforming to `LocalizedError`.
- Implement `errorDescription`, `failureReason`, and `recoverySuggestion` when useful.
- Wrap feature-level failures in `AppError` when routing centrally.
- Send user-visible failures through `UserFeedbackManager`.
- Log operational failures with `Logger.shared`.

## Logging and Feedback
- Use `Logger.shared.debug/info/warning/error/fault`.
- Include useful context, but avoid noisy logs in hot paths.
- Non-critical feedback is usually a toast.
- Critical errors use `NSAlert` through `UserFeedbackManager`.

## Concurrency and Memory
- Existing code mixes `Task {}` with `DispatchQueue.main.async`.
- Keep UI mutations on the main thread.
- Use `async/await` when it simplifies permission polling or async flows.
- Use `[weak self]` in long-lived escaping closures.
- Invalidate timers and remove observers when workflows stop.

## SwiftUI Guidance
- Keep views declarative and relatively thin.
- Move non-trivial state transitions into view models or services.
- Use `@ObservedObject`, `@StateObject`, `@State`, and `@Binding` consistently.
- Match existing design-system usage such as `DS.Spacing`, `DS.IconSize`, and `DS.Colors`.

## Testing Conventions
- Use XCTest.
- Follow Arrange -> Act -> Assert.
- Use `XCTestExpectation` for callback-driven async tests.
- Shared helpers live in `SpeakYourMindTests/TestHelpers.swift`.
- Current suites include `SpeechManagerTests`, `PermissionsManagerTests`, `TextInjectorTests`, `OverlayViewModelTests`, and `RecordingSessionStoreTests`.

## App-Specific Guardrails
- Do not block the main thread during recording or UI updates.
- Check Accessibility permission before text injection behavior.
- Be careful with clipboard preservation and restore timing in `TextInjector`.
- Do not regress `SpeechManager` recording state transitions.
- Preserve feedback flows for start, stop, copy, pause, resume, and error cases.

## When Updating Docs or Commands
- Prefer commands verified from repo root.
- If docs conflict with code or file layout, trust the codebase.
- Update this file when new rules, lint commands, or test entry points are added.
