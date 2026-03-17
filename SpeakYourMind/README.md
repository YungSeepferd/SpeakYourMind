# SpeakYourMind — macOS Voice Dictation Helper

A lightweight macOS menu bar app with two global hotkeys for instant voice dictation.
Press a key, speak, press again — text appears at your cursor. No clicking required.

## Two Modes

### Mode 1: Instant Dictation (`⌃⌥⌘`)
Press and hold Control + Option + Command together, then release. A tiny pulsing 
indicator appears. Speak. Press and release the same modifier combination again. 
Your words are pasted at the cursor in whatever app had focus — VS Code, Slack, 
Notes, anything.

**Note:** This is a modifier-only hotkey. It requires Accessibility permission 
and works by detecting when all three modifiers (⌃⌥⌘) are held and then released 
without pressing any other key.

### Mode 2: Overlay (`⌃⌥⌘ Space`)
Opens a floating panel with live transcription, a built-in text editor for
corrections, copy-to-clipboard, reset, and delete controls. Dismiss with `Esc`
or the same hotkey.

Both hotkeys are fully customizable in Settings.

## Features

- **Global Hotkeys** — works from any app, configurable in Settings
- **Instant Cursor Injection** — text appears where you're typing, clipboard auto-restored
- **Live Transcription** — see words appear in real-time
- **Built-in Text Editor** — toggle editor mode (`⌘E`) to correct words with keyboard
- **Reset While Recording** — clear text without stopping the mic (next-thought workflow)
- **Delete All** — wipe transcription (`⌘⌫`)
- **Copy to Clipboard** — manual copy (`⇧⌘C`)
- **Pulsing Recording Indicator** — non-intrusive, click-through, visible on all Spaces
- **Offline Recognition** — Apple Speech framework, no internet required
- **Sound Feedback** — audio cues on start/stop (configurable)
- **Menu Bar Icon** — settings and quit access

## Project Structure

```
lpointer/
├── Package.swift                           # SPM manifest + KeyboardShortcuts dep
└── SpeakYourMind/
    ├── SpeakYourMindApp.swift              # @main, AppDelegate, hotkey wiring
    ├── Info.plist                          # Permissions (mic, speech, LSUIElement)
    ├── Services/
    │   ├── HotkeyManager.swift            # KeyboardShortcuts.Name definitions
    │   ├── SpeechManager.swift            # AVAudioEngine + SFSpeechRecognizer
    │   ├── InstantRecordCoordinator.swift  # Toggle record → inject at cursor
    │   ├── TextInjector.swift             # Clipboard save → Cmd+V → restore
    │   └── PermissionsManager.swift       # Accessibility permission check
    └── Views/
        ├── MainView.swift                 # Overlay UI: transcription + controls
        ├── OverlayPanel.swift             # Floating NSPanel (Spotlight-style)
        ├── RecordingIndicatorPanel.swift   # Non-activating pulsing dot
        └── SettingsView.swift             # Hotkey recorder + preferences
```

## Technology Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9+ |
| UI | SwiftUI + AppKit (NSPanel) |
| Speech | Apple Speech framework (SFSpeechRecognizer) |
| Audio | AVFoundation (AVAudioEngine) |
| Hotkeys | [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus |
| Text Injection | CGEvent (simulated Cmd+V) + NSPasteboard |
| Permissions | Accessibility (AXIsProcessTrusted), Microphone, Speech Recognition |

## Build & Run

```bash
cd lpointer
swift build
.build/debug/SpeakYourMind
```

### Requirements
- macOS 13.0+
- Swift 5.9+ / Xcode 15+

### Permissions (granted on first launch)
- **Microphone** — for audio capture
- **Speech Recognition** — for STT processing
- **Accessibility** — for instant dictation mode (text injection via CGEvent)

## Keyboard Shortcuts

### Global (work from any app)
| Shortcut | Action | Configurable |
|---|---|---|
| `⌃⌥⌘ Space` | Toggle overlay panel | Yes |
| `⌃⌥⌘` (hold + release) | Toggle instant dictation | No (modifier-only) |

**Note on modifier-only hotkeys:** The Instant Dictation hotkey (`⌃⌥⌘`) is a 
modifier-only combination. Hold all three modifiers (Control, Option, Command) 
together, then release to trigger. This requires Accessibility permission and 
cannot be customized through the standard KeyboardShortcuts recorder.

### Inside Overlay
| Shortcut | Action |
|---|---|
| `⌘R` | Start / stop recording |
| `⌘E` | Toggle text editor mode |
| `⇧⌘C` | Copy to clipboard |
| `⌘⌫` | Delete all text |
| `Esc` | Close overlay |

## Architecture Notes

### Text Injection (Instant Mode)
Uses the industry-standard clipboard+paste approach (same as TextExpander, Raycast, Alfred):
1. Save current clipboard contents
2. Set transcribed text on clipboard
3. Simulate `Cmd+V` via CGEvent
4. Restore original clipboard after 200ms

### Window Focus
- **OverlayPanel** — `canBecomeKey = true`, steals focus (user needs to interact)
- **RecordingIndicatorPanel** — `canBecomeKey = false`, never steals focus, click-through

### Speech Recognition
- Apple's on-device SFSpeechRecognizer (~60s limit per session)
- `clearAndContinue()` resets text without stopping the mic for seamless multi-thought flow

## Future Enhancements
- Hold-to-record mode (press and hold hotkey, release to inject)
- Vosk integration for unlimited offline sessions
- Multi-language support / language switcher
- Transcription history
- Custom vocabulary / domain-specific terms
- Auto-capitalization and punctuation