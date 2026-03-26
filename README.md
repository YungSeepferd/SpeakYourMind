# SpeakYourMind

SpeakYourMind is a macOS menu bar dictation app built with SwiftUI, AppKit, and Swift Package Manager. It supports a floating overlay for guided transcription and an instant dictation flow for quickly injecting spoken text into the focused app.

## Features

- Global hotkeys for overlay mode and instant dictation
- On-device speech recognition with live transcription
- Automatic text injection with clipboard preservation
- Menu bar app with settings, logging, and install scripts
- XCTest coverage for core services and view models

## Requirements

- macOS 13+
- Swift 5.9+
- Microphone permission for dictation
- Accessibility permission for text injection workflows

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

## Build and Run

From the repository root:

```bash
swift package resolve
swift build
swift run
```

You can also launch the debug binary directly:

```bash
.build/debug/SpeakYourMind
```

## Install Locally

Build the release binary and create an app bundle in `~/Applications`:

```bash
./install.sh
open ~/Applications/SpeakYourMind.app
```

Remove build artifacts and the installed app:

```bash
./clean.sh
```

## Testing

Run the full suite:

```bash
swift test
```

Run a single test suite:

```bash
swift test --filter SpeechManagerTests
```

Run a single test method:

```bash
swift test --filter SpeechManagerTests/test_initialState_isNotListening
```

Additional QA guidance lives in `TESTING.md`.

## Logging

Stream app logs while testing:

```bash
./view-logs.sh
```

Export logs for reporting:

```bash
./export-logs.sh
```

You can also inspect logs directly with macOS tooling:

```bash
log show --predicate 'subsystem == "com.speakyourmind.app"' --last 24h --style compact
```

## Architecture

SpeakYourMind follows an MVVM-style structure:

- `Views/` render the overlay, settings UI, and supporting components
- `ViewModels/` manage UI-facing state and interaction logic
- `Services/` handle speech recognition, hotkeys, permissions, injection, logging, and coordination

See `ARCHITECTURE.md` for more detail.
