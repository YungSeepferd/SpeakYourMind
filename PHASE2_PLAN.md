# Phase 2 Implementation Plan - SpeakYourMind

## Overview
Transform the functional prototype into a polished, production-ready UX with coherent interaction model across all entry points.

## Phase 2 Goals
1. **Clarify mode/state visibly** - Users always know what mode they're in and what will happen
2. **Make sessions first-class** - Visible session workspace, not hidden menu
3. **Reduce control ambiguity** - Group controls by purpose with clear affordances
4. **Harden edge trigger** - Reliable behavior across monitors/workspaces
5. **Add comprehensive QA** - Manual checklist + automated tests

---

## Task 1: Extract MainView into Composable Subviews

### Files to Create
- `SpeakYourMind/Views/Components/OverlayHeaderView.swift`
- `SpeakYourMind/Views/Components/TranscriptSurfaceView.swift`
- `SpeakYourMind/Views/Components/RecordingControlsView.swift`
- `SpeakYourMind/Views/Components/SessionRailView.swift`
- `SpeakYourMind/Views/Components/AIControlsView.swift`

### Changes to `MainView.swift`
- Replace monolithic body with composed subviews
- Reduce file from ~450 lines to ~200 lines
- Move business logic to ViewModel (Task 2)

### Acceptance Criteria
- All existing functionality preserved
- Build succeeds with no warnings
- All 19 existing tests pass

---

## Task 2: Create OverlayViewModel for State Management

### Files to Create
- `SpeakYourMind/ViewModels/OverlayViewModel.swift`

### State Machine
```swift
enum OverlayMode: String {
    case idle = "Ready"
    case overlayDictation = "Overlay Dictation"
    case instantDictation = "Instant Dictation"
    case edgeCapture = "Edge Capture"
    case processingAI = "Processing…"
    case error = "Error"
}

enum OutputAction {
    case saveSessionOnly
    case injectOnStop
    case copyToClipboard
}
```

### Published Properties
- `currentMode: OverlayMode`
- `outputAction: OutputAction`
- `isRecording: Bool`
- `isPaused: Bool`
- `hasText: Bool`
- `ollamaAvailable: Bool`
- `statusMessage: String`

### Changes to `MainView.swift`
- Replace inline state logic with `@ObservedObject var viewModel: OverlayViewModel`
- Remove direct SpeechManager instantiation (use shared instance)

### Acceptance Criteria
- Mode displayed in header updates correctly
- Output action clear to user before stopping
- State transitions testable in isolation

---

## Task 3: Make Session History Visible (Session Rail)

### Files to Modify
- `SpeakYourMind/Views/Components/SessionRailView.swift` (new)
- `SpeakYourMind/Views/MainView.swift`

### UI Changes
- Replace hidden session menu with visible horizontal rail or vertical sidebar
- Show session chips with: title, word count, duration, active indicator
- Add "New Session" button always visible
- Add session context menu: rename, duplicate, delete

### Session Chip Design
```swift
struct SessionChip: View {
    let session: RecordingSession
    let isActive: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(active ? .accentColor : .clear)
                .frame(width: 6, height: 6)
            Text(session.displayTitle)
                .font(.system(size: 11))
                .lineLimit(1)
            Text("\(session.wordCount) words")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(active ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05))
        .cornerRadius(6)
    }
}
```

### Acceptance Criteria
- Sessions visible without opening menu
- Active session clearly indicated
- Can create/switch/delete sessions in ≤2 clicks
- Persists across app relaunch

---

## Task 4: Debounce Session Persistence

### Files to Modify
- `SpeakYourMind/ViewModels/RecordingSessionStore.swift`

### Changes
- Add debounce timer (2 seconds after last change)
- Only save on major state changes (stop recording, session switch, app terminate)
- Add `saveQueued` flag to prevent duplicate saves

```swift
private var saveTimer: Timer?
private var pendingChanges = false

func updateCurrentText(_ text: String) {
    // ... update logic
    pendingChanges = true
    saveTimer?.invalidate()
    saveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
        self?.saveSessions()
        self?.pendingChanges = false
    }
}
```

### Acceptance Criteria
- No performance lag during live transcription
- Sessions persist correctly after app relaunch
- No duplicate UserDefaults writes

---

## Task 5: Harden EdgeTriggerMonitor

### Files to Modify
- `SpeakYourMind/Services/EdgeTriggerMonitor.swift`

### Fixes Needed
1. **Multi-monitor support** - Track which screen cursor is on
2. **Tracking area lifecycle** - Rebuild on screen configuration change
3. **Global monitor cleanup** - Ensure no retain cycles
4. **State recovery** - Handle stuck overlay state gracefully
5. **Add "Send to Main Overlay" button** - Escalate from edge to full overlay

### EdgeOverlayView Additions
- Add "Expand" button to open full overlay with current session
- Add mode indicator: "Edge Capture"
- Show session count badge

### Acceptance Criteria
- Edge trigger works on all monitors
- Overlay hides reliably on Escape/click/timer
- No stuck states after sleep/wake
- Can escalate to main overlay seamlessly

---

## Task 6: Add Mode Indicator to All Views

### Files to Modify
- `SpeakYourMind/Views/Components/OverlayHeaderView.swift`
- `SpeakYourMind/Services/EdgeTriggerMonitor.swift` (EdgeOverlayView)
- `SpeakYourMind/Views/RecordingIndicatorPanel.swift`

### Header Addition
```swift
HStack {
    Circle()
        .fill(modeColor)
        .frame(width: 8, height: 8)
    Text(viewModel.statusMessage)
        .font(.system(size: 11, weight: .medium))
    Spacer()
    Text(viewModel.currentMode.rawValue)
        .font(.system(size: 9))
        .foregroundColor(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(4)
}
```

### Acceptance Criteria
- Mode always visible in header
- Edge overlay shows "Edge Capture"
- Instant dictation shows "Instant Dictation"
- Overlay hotkey shows "Overlay Dictation"

---

## Task 7: Group Controls by Purpose

### Files to Modify
- `SpeakYourMind/Views/Components/RecordingControlsView.swift`

### Visual Grouping
```swift
HStack(spacing: 16) {
    // Capture Group
    GroupBox {
        recordButton
        pauseButton
    }
    
    // Edit Group
    GroupBox {
        clearButton
        deleteButton
    }
    
    Spacer()
    
    // Output Group
    GroupBox {
        copyButton
        injectButton (if applicable)
    }
    
    // AI Group (when enabled)
    if ollamaEnabled {
        GroupBox {
            aiMenu
        }
    }
}
```

### Acceptance Criteria
- Controls visually grouped by purpose
- Destructive actions (delete) visually distinct
- Primary action (record) most prominent

---

## Task 8: Add Comprehensive QA Checklist

### File to Create
- `QA_CHECKLIST.md` (see below)

### Usage
- Run after each Phase 2 task
- Run before release
- Track pass/fail in document

---

## Task 9: Add Automated Test Coverage

### Files to Create
- `SpeakYourMindTests/OverlayViewModelTests.swift`
- `SpeakYourMindTests/RecordingSessionStoreTests.swift`
- `SpeakYourMindTests/EdgeTriggerMonitorTests.swift`

### Test Coverage Goals
- OverlayViewModel state transitions: 100%
- RecordingSessionStore CRUD: 100%
- EdgeTriggerMonitor geometry: 80%
- SpeechManager pause/resume: 100%

### Acceptance Criteria
- All new tests pass
- Code coverage ≥80% for new files
- No test flakiness

---

## Task 10: Polish Pass

### Files to Modify
- All component views

### Polish Items
- Consistent spacing (8/12/16/20 scale)
- Typography hierarchy (11/12/14/16 scale)
- Color consistency (semantic colors)
- Motion tuning (0.2-0.5s animations)
- Focus ring visibility
- Keyboard navigation flow
- Tooltip completeness

### Acceptance Criteria
- Visual consistency across all views
- Keyboard navigation works end-to-end
- All buttons have tooltips with shortcuts
- Animations feel responsive, not sluggish

---

## Implementation Order

1. **Task 1** - Extract MainView (foundation for all other work)
2. **Task 2** - Create OverlayViewModel (state management)
3. **Task 3** - Session Rail (visible sessions)
4. **Task 4** - Debounce persistence (performance)
5. **Task 5** - Harden EdgeTrigger (reliability)
6. **Task 6** - Mode indicators (clarity)
7. **Task 7** - Control grouping (affordance)
8. **Task 8** - QA Checklist (verification)
9. **Task 9** - Automated Tests (regression prevention)
10. **Task 10** - Polish Pass (production quality)

---

## Definition of Done (Phase 2)

- [ ] All 10 tasks complete
- [ ] All existing tests pass (19 tests)
- [ ] All new tests pass (target: +30 tests)
- [ ] QA Checklist executed with ≥95% pass rate
- [ ] No build warnings
- [ ] Manual validation on 2+ monitor setups
- [ ] Performance: no lag during live transcription
- [ ] Memory: no leaks (Instruments verification)
- [ ] Edge trigger reliable across sleep/wake cycles
