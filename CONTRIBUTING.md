# Contributing to SpeakYourMind

## Getting Started

### Prerequisites
- macOS 13.0+ (Ventura or later)
- Xcode 15.0+ or Swift 5.9+ toolchain
- Git

### Build Instructions

```bash
# Clone repository
git clone <repo-url>
cd lpointer

# Build with Swift Package Manager
swift build

# Open in Xcode (optional)
open SpeakYourMind/SpeakYourMind.xcodeproj
```

### Running the App

1. Build and run in Xcode or via `swift run`
2. Grant microphone permission when prompted
3. For instant dictation mode, grant Accessibility permission:
   - System Settings → Privacy & Security → Accessibility → Add SpeakYourMind

## Development Workflow

### Branch Strategy
- `main`: Production-ready code
- `feature/*`: New features
- `fix/*`: Bug fixes
- `release/*`: Release preparation

### Pull Request Guidelines

1. **Small, focused changes**: One feature or fix per PR
2. **Builds cleanly**: `swift build` must succeed with zero warnings
3. **Test coverage**: Add tests for new functionality
4. **Documentation**: Update README.md if behavior changes

### Code Style

```swift
// Public API: Document with header comment
/// Starts the speech recognition session.
/// - Returns: true if successful, false if microphone unavailable
func startListening() -> Bool

// Private implementation: Brief comment if non-obvious
// Workaround for 60-second SFSpeechRecognizer limit
func clearAndContinue() { ... }

// Actor isolation: Explicitly annotate main-thread requirements
@MainActor
func updateUI() { ... }
```

### Naming Conventions

- **Services**: `*Manager`, `*Coordinator` (e.g., `SpeechManager`, `TextInjector`)
- **Views**: `*View`, `*Panel` (e.g., `MainView`, `OverlayPanel`)
- **Hotkeys**: `KeyboardShortcuts.Name` extension in `HotkeyManager`

## Testing

### Running Tests

```bash
# Run all tests
swift test

# Run specific test class
swift test --filter SpeechManagerTests
```

### Writing Tests

```swift
final class TextInjectorTests: XCTestCase {
    func testInjectSavesAndRestoresClipboard() {
        // Given
        let originalClipboard = NSPasteboard.general.string(forType: .string)
        
        // When
        TextInjector.inject("test text")
        
        // Then
        // Clipboard restored after 200ms
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertEqual(NSPasteboard.general.string(forType: .string), originalClipboard)
        }
    }
}
```

### Manual QA Checklist

| Feature | Test Steps | Expected |
|---------|------------|----------|
| Overlay hotkey | Press ⌥ Space | Panel appears, mic starts |
| Instant hotkey | Press ⌥⇧ Space | Recording indicator shows |
| Text injection | Dictate in TextEdit | Text appears at cursor |
| Reset while recording | Click Reset during recording | Text clears, mic continues |
| Accessibility gate | Deny AX permission | Instant mode blocked with prompt |

## Architecture Decisions

### Why KeyboardShortcuts Library?
- Wraps Carbon `RegisterEventHotKey` (battle-tested)
- Provides SwiftUI `Recorder` view for user configuration
- No Accessibility permission needed for hotkey alone

### Why Clipboard + CGEvent for Injection?
- Industry standard (TextExpander, Raycast, Alfred)
- Works across all apps that accept text input
- Simpler than Accessibility API `AXUIElement` approach

### Why SFSpeechRecognizer?
- On-device processing (privacy, no network)
- Built into macOS (no dependencies)
- Good accuracy for English dictation

## Adding Features

### New Hotkey
1. Add `KeyboardShortcuts.Name` extension in `HotkeyManager.swift`
2. Wire to AppDelegate handler
3. Add to SettingsView if user-configurable

### New Speech Engine
1. Create protocol `SpeechRecognitionService`
2. Implement for new engine (e.g., `VoskSpeechManager`)
3. Swap implementation in AppDelegate

### New UI Panel
1. Subclass `NSPanel` with `canBecomeKey` as needed
2. Set `level = .floating` for always-on-top
3. Handle escape key for dismissal

## Debugging

### Common Issues

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| Hotkey not working | App not running | Check menu bar icon visible |
| No transcription | Microphone denied | Check System Settings → Privacy |
| Injection fails | AX permission denied | Add app to Accessibility list |
| Build errors | SPM dependencies | `rm -rf .build && swift build` |

### Logging

Add temporary print statements for debugging:

```swift
print("[SpeechManager] Started listening")
print("[TextInjector] Injecting: \(text)")
```

## Release Process

1. Update version in `Package.swift`
2. Update CHANGELOG.md
3. Create git tag: `git tag -a v1.0.0 -m "Release 1.0.0"`
4. Push tag: `git push origin v1.0.0`
5. Create GitHub release with attached .app bundle

## Questions?

Open an issue for:
- Build problems
- Feature requests
- Architecture discussions
