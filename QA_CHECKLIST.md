# QA Checklist - SpeakYourMind

## How to Use
- Run this checklist after each Phase 2 task
- Mark each item as ✅ Pass, ❌ Fail, or ⚠️ Partial
- Log failures with steps to reproduce
- Target: ≥95% pass rate before release

---

## Recording Lifecycle

### Basic Recording
- [ ] Start recording via Record button
- [ ] Speak for 10-15 seconds
- [ ] Verify live transcription updates
- [ ] Stop recording
- [ ] Verify toast: "Recording saved"
- [ ] Verify session persisted in session rail

### Pause/Resume
- [ ] Start recording
- [ ] Click Pause button
- [ ] Verify toast: "Paused"
- [ ] Verify state indicator shows "Paused"
- [ ] Click Resume button
- [ ] Verify toast: "Resumed"
- [ ] Continue speaking
- [ ] Stop recording
- [ ] Verify transcript preserved across pause

### Clear Text (Keep Recording)
- [ ] Start recording
- [ ] Speak some text
- [ ] Click Clear button
- [ ] Verify toast: "Text cleared"
- [ ] Verify transcript cleared
- [ ] Verify recording continues
- [ ] Speak more text
- [ ] Verify new text appears

### Delete All
- [ ] Start recording
- [ ] Speak some text
- [ ] Press ⌘⌫
- [ ] Verify toast: "All text deleted"
- [ ] Verify transcript cleared
- [ ] Verify recording stopped

### Close Overlay While Recording
- [ ] Start recording in overlay
- [ ] Close overlay (Esc or X button)
- [ ] Verify recording stops
- [ ] Verify session saved
- [ ] Reopen overlay
- [ ] Verify session preserved

---

## Entry Point Consistency

### Menu Bar Click
- [ ] Click menu bar icon
- [ ] Verify overlay opens centered
- [ ] Verify overlay makes key
- [ ] Verify app activates
- [ ] Verify state: "Ready"
- [ ] Press Record
- [ ] Verify menu bar icon turns red

### Overlay Hotkey (⌃⌥⌘ Space)
- [ ] Press hotkey
- [ ] Verify overlay opens centered
- [ ] Verify overlay makes key
- [ ] Verify app activates
- [ ] Verify state: "Ready"

### Instant Dictation Hotkey (⌃⌥⌘)
- [ ] Press modifier combo (hold all three, release)
- [ ] Verify recording starts immediately
- [ ] Verify recording indicator appears (red dot)
- [ ] Verify menu bar icon turns red
- [ ] Verify toast: "Recording started"
- [ ] Press hotkey again
- [ ] Verify recording stops
- [ ] Verify text injected OR saved to session (based on mode)
- [ ] Verify toast: "Recording saved" or "Text injected"

### Edge Trigger
- [ ] Move cursor to top edge of screen
- [ ] Verify edge overlay appears within 100ms
- [ ] Verify state: "Edge Capture"
- [ ] Click Record
- [ ] Verify recording starts
- [ ] Verify toast: "Recording started"
- [ ] Move cursor away from edge
- [ ] Wait 2 seconds
- [ ] Verify overlay hides
- [ ] Verify recording continues (background)
- [ ] Return cursor to edge
- [ ] Verify overlay reappears
- [ ] Verify transcript preserved

### Edge Trigger - Multi-Monitor
- [ ] Test on primary monitor
- [ ] Test on secondary monitor
- [ ] Test on tertiary monitor (if available)
- [ ] Verify edge trigger works on all monitors
- [ ] Verify overlay positions correctly on each

### Settings Window
- [ ] Click menu bar → Settings
- [ ] Verify settings window opens
- [ ] Verify all sections visible
- [ ] Change a setting
- [ ] Close settings
- [ ] Reopen settings
- [ ] Verify setting preserved

---

## Permission Handling

### No Microphone Permission
- [ ] Revoke microphone permission in System Settings
- [ ] Relaunch app
- [ ] Press Record
- [ ] Verify system permission prompt appears
- [ ] Verify toast: error message
- [ ] Verify state: "Error"

### No Speech Recognition Permission
- [ ] Revoke speech recognition permission
- [ ] Relaunch app
- [ ] Press Record
- [ ] Verify system permission prompt appears
- [ ] Verify toast: error message

### No Accessibility Permission
- [ ] Revoke accessibility permission
- [ ] Relaunch app
- [ ] Trigger instant dictation
- [ ] Verify system permission prompt appears
- [ ] Verify injection blocked
- [ ] Verify toast: error message

### Permission Granted Mid-Session
- [ ] Start with permission denied
- [ ] Grant permission in System Settings
- [ ] Return to app
- [ ] Press Record
- [ ] Verify recording starts successfully

---

## Output Behaviors

### Copy to Clipboard
- [ ] Record some text
- [ ] Stop recording
- [ ] Click Copy button (or ⇧⌘C)
- [ ] Verify toast: "Copied to clipboard"
- [ ] Paste into text editor
- [ ] Verify text matches

### Inject into Active App
- [ ] Configure: Direct injection mode
- [ ] Focus TextEdit or similar
- [ ] Trigger instant dictation
- [ ] Speak some text
- [ ] Stop recording
- [ ] Verify text injected at cursor
- [ ] Verify toast: "Text injected"
- [ ] Verify clipboard restored

### Overlay Mode (No Injection)
- [ ] Configure: Overlay mode
- [ ] Focus TextEdit
- [ ] Trigger instant dictation
- [ ] Speak some text
- [ ] Stop recording
- [ ] Verify text NOT injected
- [ ] Verify text in overlay
- [ ] Verify toast: "Recording saved"
- [ ] Manually copy/inject from overlay

### Streaming vs Batch Injection
- [ ] Configure: Streaming mode
- [ ] Record text
- [ ] Verify text injected incrementally (if enabled)
- [ ] Configure: Batch mode
- [ ] Record text
- [ ] Verify text injected all at once at end

---

## Session Management

### New Session
- [ ] Click Sessions menu → New Session
- [ ] Verify toast: "New session"
- [ ] Verify session appears in session rail
- [ ] Verify session active (highlighted)
- [ ] Verify transcript cleared

### Switch Session
- [ ] Create 2+ sessions
- [ ] Click session chip in rail
- [ ] Verify session becomes active
- [ ] Verify transcript updates to session text
- [ ] Verify session count badge updates

### Delete Current Session
- [ ] Select a session
- [ ] Click Delete (or context menu)
- [ ] Verify toast: "Session deleted"
- [ ] Verify session removed from rail
- [ ] Verify next session becomes active

### Clear All Sessions
- [ ] Create multiple sessions
- [ ] Click Sessions menu → Clear All
- [ ] Verify toast: "All sessions cleared"
- [ ] Verify all sessions removed
- [ ] Verify session rail empty

### Session Persistence
- [ ] Create session with text
- [ ] Stop recording
- [ ] Quit app completely
- [ ] Relaunch app
- [ ] Verify session preserved
- [ ] Verify text preserved
- [ ] Verify session selectable

### Session Rename (Future)
- [ ] Right-click session
- [ ] Select Rename
- [ ] Enter new name
- [ ] Verify name updates
- [ ] Verify name persists

---

## Ollama Integration

### Ollama Disabled
- [ ] Ensure Ollama disabled in Settings
- [ ] Open overlay
- [ ] Verify AI menu hidden
- [ ] Verify no Ollama status indicator

### Ollama Enabled - Server Offline
- [ ] Enable Ollama in Settings
- [ ] Ensure Ollama server not running
- [ ] Open overlay
- [ ] Verify Ollama status: orange warning
- [ ] Verify AI menu disabled
- [ ] Verify toast on attempt: "AI failed: Not configured"

### Ollama Enabled - Server Online
- [ ] Start Ollama server (`ollama serve`)
- [ ] Open overlay
- [ ] Verify Ollama status: green checkmark
- [ ] Verify AI menu enabled

### Model Refresh
- [ ] Click Refresh Models button
- [ ] Verify toast: "Fetching models..."
- [ ] Verify models populate in picker
- [ ] Verify status updates

### AI Processing - Success
- [ ] Record some text
- [ ] Select AI action (e.g., "Correct Spelling")
- [ ] Verify loading overlay appears
- [ ] Verify processing completes
- [ ] Verify text updated
- [ ] Verify toast: "[Action] complete"

### AI Processing - Failure
- [ ] Record some text
- [ ] Select AI action
- [ ] Simulate failure (stop server mid-request)
- [ ] Verify error alert appears
- [ ] Verify toast: "AI failed: [error]"
- [ ] Verify original text preserved

---

## Edge Trigger Robustness

### Hide on Escape
- [ ] Trigger edge overlay
- [ ] Press Escape
- [ ] Verify overlay hides immediately
- [ ] Verify recording continues (if active)

### Hide on Outside Click
- [ ] Trigger edge overlay
- [ ] Click outside overlay
- [ ] Verify overlay hides
- [ ] Verify recording continues (if active)

### Hide on Timer
- [ ] Trigger edge overlay
- [ ] Move cursor away from edge
- [ ] Wait 2 seconds
- [ ] Verify overlay hides
- [ ] Verify recording continues (if active)

### No Stuck States
- [ ] Trigger edge overlay
- [ ] Put Mac to sleep
- [ ] Wake Mac
- [ ] Verify overlay not stuck on screen
- [ ] Verify edge trigger still functional

### Escalate to Main Overlay
- [ ] Trigger edge overlay
- [ ] Record some text
- [ ] Click "Expand" button (if implemented)
- [ ] Verify main overlay opens
- [ ] Verify session transferred
- [ ] Verify transcript preserved

---

## Performance

### Live Transcription Lag
- [ ] Start recording
- [ ] Speak continuously for 60 seconds
- [ ] Verify no UI lag
- [ ] Verify transcription updates in real-time
- [ ] Verify no stuttering

### Memory Leaks
- [ ] Open Instruments → Allocations
- [ ] Start/stop recording 20 times
- [ ] Verify no monotonic memory growth
- [ ] Verify deallocation on stop

### Session Persistence Performance
- [ ] Create 10 sessions
- [ ] Switch between sessions rapidly
- [ ] Verify no lag on switch
- [ ] Verify UserDefaults not hammered (debounce working)

---

## Keyboard Navigation

### Overlay Keyboard Flow
- [ ] Open overlay
- [ ] Tab through all controls
- [ ] Verify focus ring visible on each
- [ ] Verify focus order logical
- [ ] Press ⌘R - verify record/stop
- [ ] Press ⌘P - verify pause/resume
- [ ] Press ⌘⌫ - verify clear
- [ ] Press Esc - verify close

### Edge Overlay Keyboard Flow
- [ ] Trigger edge overlay
- [ ] Tab through controls
- [ ] Verify focus ring visible
- [ ] Press ⌘R or Space - verify record/stop
- [ ] Press ⌘P - verify pause/resume
- [ ] Press Esc - verify close

### Settings Keyboard Flow
- [ ] Open settings
- [ ] Tab through all controls
- [ ] Verify focus ring visible
- [ ] Verify all controls accessible

---

## Visual Polish

### Icon Sizes
- [ ] Verify primary icons (record/stop): 24px
- [ ] Verify secondary icons (pause/reset/delete): 22px
- [ ] Verify tertiary icons (AI/editor/copy): 20px
- [ ] Verify status icons: 12px
- [ ] Verify consistency across views

### Typography
- [ ] Verify header text: 12px medium
- [ ] Verify body text: 14px regular
- [ ] Verify caption text: 11px regular
- [ ] Verify badge text: 10px
- [ ] Verify consistency across views

### Spacing
- [ ] Verify section padding: 16px
- [ ] Verify control spacing: 12-20px
- [ ] Verify element padding: 8-12px
- [ ] Verify visual rhythm consistent

### Color Consistency
- [ ] Verify recording state: red
- [ ] Verify paused state: orange
- [ ] Verify idle state: gray
- [ ] Verify success toast: green
- [ ] Verify info toast: blue
- [ ] Verify warning toast: orange
- [ ] Verify error: NSAlert

### Animations
- [ ] Verify recording pulse: 0.5s easeInOut
- [ ] Verify toast appear: 0.2-0.3s spring
- [ ] Verify toast disappear: 0.2s easeOut
- [ ] Verify no janky motion

---

## Tooltips & Help

### All Buttons Have Tooltips
- [ ] Record button: "Record / Stop ⌘R"
- [ ] Pause button: "Pause/Resume Recording ⌘P"
- [ ] Clear button: "Reset text, keep recording"
- [ ] Delete button: "Delete all ⌘⌫"
- [ ] Copy button: "Copy to clipboard ⇧⌘C"
- [ ] Editor button: "Toggle editor ⌘E"
- [ ] AI button: "AI Processing (Ollama)"
- [ ] Sessions button: "Recording Sessions"
- [ ] Close button: "Close"
- [ ] Verify all tooltips include shortcuts where applicable

---

## Error Recovery

### Speech Recognition Failure
- [ ] Simulate recognition failure
- [ ] Verify error toast appears
- [ ] Verify state resets to "Ready"
- [ ] Verify can restart recording

### Injection Failure
- [ ] Simulate injection failure (no frontmost app)
- [ ] Verify error toast appears
- [ ] Verify clipboard preserved
- [ ] Verify can retry

### Ollama Failure
- [ ] Stop Ollama server mid-processing
- [ ] Verify error alert appears
- [ ] Verify original text preserved
- [ ] Verify can retry when server restarts

---

## Final Validation

### Build Verification
- [ ] `swift build` succeeds with no warnings
- [ ] `swift test` passes all tests (target: 50+ tests)
- [ ] No deprecation warnings
- [ ] No LSP errors

### Manual Smoke Test
- [ ] Fresh app launch
- [ ] Grant all permissions
- [ ] Record 30 seconds of speech
- [ ] Stop recording
- [ ] Verify session saved
- [ ] Copy text
- [ ] Paste into document
- [ ] Verify text correct
- [ ] Quit app
- [ ] Relaunch
- [ ] Verify session restored

### Cross-Scenario Testing
- [ ] Test with overlay mode + edge trigger
- [ ] Test with instant dictation + overlay open
- [ ] Test with Ollama processing during recording
- [ ] Test with multiple sessions active
- [ ] Verify no state corruption

---

## Sign-Off

**Tester:** ________________  
**Date:** ________________  
**Version:** ________________  
**Pass Rate:** _____% (target: ≥95%)  

**Blockers:**  
- List any ❌ Fail items preventing release

**Known Issues:**  
- List any ⚠️ Partial items acceptable for release

**Release Approval:**  
- [ ] Approved for release
- [ ] Not approved - fix blockers first
