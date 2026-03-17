# SpeakYourMind Architecture

## System Overview

SpeakYourMind is a macOS menu bar application that provides global hotkey-driven voice dictation with two distinct interaction modes:

1. **Overlay Mode** (`⌥ Space`): Floating transcription panel with manual controls
2. **Instant Dictation Mode** (`⌥⇧ Space`): Background recording with automatic text injection

## Component Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        App Entry Point                          │
│                    SpeakYourMindApp.swift                       │
│              @main + AppDelegate + MenuBar                      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       HotkeyManager                             │
│          KeyboardShortcuts wrapper for global hotkeys           │
│              ⌥ Space (Overlay) / ⌥⇧ Space (Instant)             │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
┌───────────────────────────┐   ┌─────────────────────────────────┐
│     OverlayPanel          │   │    InstantRecordCoordinator     │
│   + MainView (UI)         │   │   + TextInjector                │
│   + SpeechManager         │   │   + PermissionsManager          │
│   + RecordingIndicator    │   │   + SpeechManager               │
└───────────────────────────┘   └─────────────────────────────────┘
              │                               │
              └───────────────┬───────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       SpeechManager                             │
│           AVAudioEngine + SFSpeechRecognizer                   │
│              On-device speech-to-text pipeline                  │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

### Overlay Mode Flow
```
1. User presses ⌥ Space
2. HotkeyManager → AppDelegate.showOverlay()
3. OverlayPanel becomes key and visible
4. SpeechManager.startListening()
   ├─ AVAudioEngine.start()
   ├─ SFSpeechRecognitionTask created
   └─ onFinalResult callback registered
5. Live transcription updates MainView
6. User clicks Copy → NSPasteboard general pasteboard
7. User closes overlay → SpeechManager.stopListening()
```

### Instant Dictation Mode Flow
```
1. User presses ⌥⇧ Space
2. HotkeyManager → AppDelegate.toggleInstantRecord()
3. InstantRecordCoordinator checks AX permission
   ├─ If denied → show system prompt
   └─ If granted → proceed
4. SpeechManager.startListening()
5. RecordingIndicatorPanel shows (non-activating)
6. User presses ⌥⇧ Space again
7. SpeechManager.stopListening() → final text
8. TextInjector.inject()
   ├─ Save current clipboard
   ├─ Set clipboard to transcription
   ├─ CGEvent post Cmd+V
   └─ Restore clipboard (200ms delay)
```

## Key Design Decisions

### Hotkey Library: KeyboardShortcuts
- Wraps Carbon `RegisterEventHotKey` for keyDown
- Wraps `NSEvent.addGlobalMonitorForEvents` for keyUp
- Provides SwiftUI `Recorder` view for user configuration
- No Accessibility permission needed for hotkey alone

### Text Injection: Clipboard + CGEvent
- Industry standard (TextExpander, Raycast, Alfred)
- Requires Accessibility permission (`AXIsProcessTrusted`)
- Saves clipboard → sets text → simulates Cmd+V → restores
- 200ms delay ensures paste completes before restore

### Speech Recognition: SFSpeechRecognizer
- On-device processing (no network, privacy-preserving)
- ~60 second session limit per Apple's implementation
- `clearAndContinue()` method works around limit
- Live partial results via `onFinalResult` callback

### Panel Architecture
- **OverlayPanel**: `canBecomeKey = true` (user interacts)
- **RecordingIndicatorPanel**: `canBecomeKey = false`, `ignoresMouseEvents = true` (click-through, never steals focus)

## Threading Model

- `SpeechManager`: Runs on background thread for audio processing
- `MainView`: `@MainActor` for UI updates
- `InstantRecordCoordinator`: Not `@MainActor` (called from AppDelegate)
- `TextInjector`: Synchronous, main thread for CGEvent posting

## Error Handling Strategy

| Component | Failure Mode | Recovery |
|-----------|--------------|----------|
| SpeechManager | No microphone | Show system permission prompt |
| SpeechManager | Recognition fails | Empty result, silent fail |
| TextInjector | No AX permission | Gate behind permission check |
| TextInjector | No frontmost app | Inject to last known focus |
| HotkeyManager | Key conflict | KeyboardShortcuts handles |

## Extension Points

1. **Alternative Speech Engines**: Swap `SpeechManager` implementation (e.g., Vosk)
2. **Injection Methods**: Replace `TextInjector` with Accessibility API approach
3. **UI Themes**: Modify `MainView` styling
4. **Hotkey Schemes**: Extend `HotkeyManager` with additional bindings

## Build & Run

```bash
# Build
swift build

# Run in Xcode
open SpeakYourMind/SpeakYourMind.xcodeproj

# Install dependencies
# KeyboardShortcuts resolved automatically by SPM
```

## Testing Strategy

- Unit tests for service layer (SpeechManager, TextInjector, PermissionsManager)
- Integration tests for hotkey → record → inject flow
- Manual QA for end-to-end user scenarios

## Security Considerations

- Microphone permission: Runtime prompt via `AVAudioEngine`
- Accessibility permission: Runtime check via `AXIsProcessTrusted`
- No Info.plist keys required for either (purely runtime)
- Clipboard data cleared after injection (200ms window)
