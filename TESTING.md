# SpeakYourMind Testing Strategy

## Automated Tests

### Unit Tests

Test individual service components in isolation:

#### SpeechManagerTests
```swift
- testStartListeningReturnsTrueWhenMicrophoneAvailable()
- testStopListeningStopsAudioEngine()
- testResetTranscriptionClearsText()
- testClearAndContinueRestartsSession()
```

#### TextInjectorTests
```swift
- testInjectSavesAndRestoresClipboard()
- testInjectPostsCmdVEvent()
- testInjectHandlesEmptyString()
```

#### PermissionsManagerTests
```swift
- testAXIsProcessTrustedReturnsCorrectly()
- testRequestAccessShowsSystemPrompt()
```

### Integration Tests

Test component interactions:

```swift
- testHotkeyTriggersOverlayPanel()
- testInstantRecordShowsIndicator()
- testRecordingInjectsTextAtCursor()
```

## Manual QA Scenarios

### Core Functionality

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| MQ-01 | Overlay activation | Press ⌥ Space | Panel appears, mic indicator pulses |
| MQ-02 | Instant activation | Press ⌥⇧ Space | Red dot indicator appears top-right |
| MQ-03 | Transcription accuracy | Speak clearly for 10s | Text appears with >90% accuracy |
| MQ-04 | Text injection | Dictate in TextEdit, stop | Text appears at cursor position |
| MQ-05 | Copy to clipboard | Click Copy button (⇧⌘C) | Text in system clipboard |
| MQ-06 | Reset while recording | Click Reset during recording | Text clears, mic continues |
| MQ-07 | Delete all | Click Delete button | All text cleared |
| MQ-08 | Text editor toggle | Press ⌘E | Keyboard navigation enabled |
| MQ-09 | Close overlay | Press Esc | Panel dismissed, recording stopped |

### Permission Flows

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| MP-01 | First mic permission | Launch app fresh | System prompt shown |
| MP-02 | Mic denied | Deny in system dialog | App shows "Microphone access required" |
| MP-03 | First AX permission | Use instant mode first time | System prompt shown |
| MP-04 | AX denied | Deny in system dialog | Instant mode blocked, overlay works |
| MP-05 | Grant after denial | Add in System Settings | Feature works on next attempt |

### Edge Cases

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| ME-01 | No frontmost app | Instant mode with no app focused | Graceful fail, no crash |
| ME-02 | App switch during recording | Switch apps while recording | Inject to original focused app |
| ME-03 | 60+ second session | Record for 70s | `clearAndContinue()` restarts session |
| ME-04 | Hotkey conflict | Set duplicate hotkey | KeyboardShortcuts shows warning |
| ME-05 | Background noise | Record in noisy environment | Transcription continues (best effort) |
| ME-06 | Rapid toggle | Toggle instant mode 5x quickly | No race conditions, stable state |

## Performance Benchmarks

| Metric | Target | Measurement |
|--------|--------|-------------|
| Hotkey → Panel latency | <100ms | Manual timing |
| Transcription latency | <500ms | Speak → text appears |
| Injection latency | <200ms | Stop → text injected |
| Memory footprint | <50MB | Activity Monitor |
| CPU usage (idle) | <1% | Activity Monitor |

## Regression Test Suite

Before each release, verify:

### Hotkey Functionality
- [ ] ⌥ Space opens overlay
- [ ] ⌥⇧ Space toggles instant recording
- [ ] Hotkeys configurable in Settings
- [ ] Hotkeys work across all apps

### Speech Recognition
- [ ] On-device transcription works
- [ ] Live updates appear in real-time
- [ ] 60+ second sessions handled
- [ ] Reset while recording works

### Text Injection
- [ ] Text appears at cursor position
- [ ] Works in TextEdit, Notes, Safari, etc.
- [ ] Clipboard restored after injection
- [ ] Fails gracefully without AX permission

### UI/UX
- [ ] Overlay non-intrusive
- [ ] Recording indicator click-through
- [ ] Esc closes overlay
- [ ] Settings window functional

## Test Automation Roadmap

### Phase 1: Unit Test Coverage (Current)
- Service layer tests
- Mock dependencies for isolation

### Phase 2: UI Test Automation (Future)
- XCTest UI tests for panel flows
- Accessibility identifier queries

### Phase 3: CI Integration (Future)
- GitHub Actions on macOS runner
- Run tests on each PR
- Build and archive .app bundle

## Reporting Issues

When filing a bug, include:

1. **macOS version**: `sw_vers`
2. **App version**: git commit or tag
3. **Steps to reproduce**: Exact sequence
4. **Expected vs actual**: What should happen vs what did
5. **Logs**: Console output or screenshots

## Test Data

### Sample Dictation Phrases
```
"Hello, this is a test of the speech recognition system."
"The quick brown fox jumps over the lazy dog."
"Please transcribe this sentence accurately."
```

### Test Apps for Injection
- TextEdit (rich text)
- Notes (plain text)
- Safari (address bar, search fields)
- Terminal (command input)
- VS Code (editor, terminal)
