# Phase 3 Implementation Plan - New Features

## Overview
Build new user-facing features that increase the app's value and differentiate it from basic dictation tools.

## Phase 3 Goals
1. **Session management depth** - Rename, pin, export, search
2. **Enhanced AI integration** - Custom prompts, more actions
3. **Workflow automation** - Auto-copy, auto-inject, rules
4. **Multi-language support** - Switch dictation language easily
5. **Advanced text formatting** - Auto-punctuation, capitalization

---

## Feature 1: Session Renaming

### Files to Create
- `SpeakYourMind/Views/Components/RenameSessionSheet.swift`

### Files to Modify
- `SpeakYourMind/Views/Components/SessionRailView.swift`
- `SpeakYourMind/ViewModels/RecordingSessionStore.swift`

### Implementation
- Right-click context menu on session chip: "Rename"
- Sheet with text field pre-filled with current title
- Save button updates session displayTitle
- Persist renamed title in session data

### Acceptance Criteria
- Can rename any session
- Renamed title persists across relaunch
- Keyboard: Enter to save, Esc to cancel

---

## Feature 2: Session Pinning

### Files to Modify
- `SpeakYourMind/Models/RecordingSession.swift`
- `SpeakYourMind/ViewModels/RecordingSessionStore.swift`
- `SpeakYourMind/Views/Components/SessionRailView.swift`

### Implementation
- Add `isPinned: Bool` to RecordingSession
- Pin icon in session chip (📌)
- Pinned sessions stay at start of rail
- Pinned sessions protected from "Delete All"
- Context menu: "Pin Session" / "Unpin"

### Acceptance Criteria
- Pin/unpin via context menu
- Pinned sessions sorted first
- Visual indicator (pin icon)
- Cannot delete pinned via "Delete All"

---

## Feature 3: Export Sessions

### Files to Create
- `SpeakYourMind/Services/SessionExporter.swift`

### Files to Modify
- `SpeakYourMind/Views/Components/SessionRailView.swift`
- `SpeakYourMind/Views/MainView.swift`

### Implementation
- Export formats: TXT, Markdown
- Context menu: "Export…"
- Save panel with default filename
- Export includes metadata (date, duration, word count)

### Acceptance Criteria
- Export to TXT
- Export to MD
- Save dialog works
- File contains full transcript + metadata

---

## Feature 4: Search Sessions

### Files to Create
- `SpeakYourMind/Views/Components/SearchSessionsView.swift`

### Files to Modify
- `SpeakYourMind/ViewModels/RecordingSessionStore.swift`

### Implementation
- Search bar in session rail or menu
- Filter sessions by text content
- Highlight matches in results
- Keyboard: ⌘F to focus search

### Acceptance Criteria
- Search filters sessions in real-time
- Shows "No matches" when empty
- Clear button resets filter
- Keyboard accessible

---

## Feature 5: Custom AI Prompts

### Files to Create
- `SpeakYourMind/Models/CustomPrompt.swift`
- `SpeakYourMind/Views/Components/CustomPromptsView.swift`

### Files to Modify
- `SpeakYourMind/Views/Components/AIControlsView.swift`
- `SpeakYourMind/ViewModels/SettingsViewModel.swift`

### Implementation
- Settings tab: "Custom Prompts"
- Add/edit/delete custom prompts
- Prompt template: name + instruction
- Appears in AI menu under divider
- Persist in UserDefaults

### Acceptance Criteria
- Add custom prompts in settings
- Custom prompts appear in AI menu
- Edit/delete existing prompts
- Prompts persist across relaunch

---

## Feature 6: Auto-Copy on Stop

### Files to Modify
- `SpeakYourMind/ViewModels/SettingsViewModel.swift`
- `SpeakYourMind/Services/InstantRecordCoordinator.swift`

### Implementation
- Settings toggle: "Auto-copy to clipboard"
- When enabled: copy text on recording stop
- Toast feedback: "Copied to clipboard"
- Works in both overlay and instant modes

### Acceptance Criteria
- Toggle in settings
- Auto-copy works on stop
- Doesn't interfere with injection
- Preference persists

---

## Feature 7: Language Switcher

### Files to Create
- `SpeakYourMind/Views/Components/LanguagePicker.swift`

### Files to Modify
- `SpeakYourMind/Services/SpeechManager.swift`
- `SpeakYourMind/Views/MainView.swift`

### Implementation
- Language picker in overlay header or controls
- Uses `SFSpeechRecognizer` availableLocales
- Switch recognizer mid-session
- Show current language as badge

### Acceptance Criteria
- Picker shows available languages
- Switch language changes recognizer
- Language persists per-session
- Badge shows current language

---

## Feature 8: Auto-Punctuation

### Files to Create
- `SpeakYourMind/Services/PunctuationFormatter.swift`

### Files to Modify
- `SpeakYourMind/Services/SpeechManager.swift`

### Implementation
- Settings toggle: "Auto-punctuation"
- Post-process transcription
- Add periods, commas, capitals
- Toggle on/off per session

### Acceptance Criteria
- Toggle in settings
- Punctuation applied correctly
- Can disable per session
- Works with all languages

---

## Implementation Priority

**High Priority (MVP):**
1. Session renaming (Feature 1) - Basic usability
2. Session pinning (Feature 2) - Prevents data loss
3. Export sessions (Feature 3) - Data portability

**Medium Priority:**
4. Custom AI prompts (Feature 5) - Differentiation
5. Auto-copy (Feature 6) - Workflow improvement
6. Language switcher (Feature 7) - Accessibility

**Low Priority:**
7. Search sessions (Feature 4) - Nice-to-have
8. Auto-punctuation (Feature 8) - Requires ML integration

---

## Definition of Done (Phase 3)

- [ ] All 8 features implemented
- [ ] All tests pass (target: 100+ tests)
- [ ] No build warnings
- [ ] Manual validation of each feature
- [ ] QA Checklist updated with new features
- [ ] Performance: no regression
- [ ] Memory: no leaks

---

## Estimated Effort

| Feature | Complexity | Time |
|---------|------------|------|
| Renaming | Low | 2-3h |
| Pinning | Low | 2-3h |
| Export | Medium | 3-4h |
| Search | Medium | 3-4h |
| Custom Prompts | Medium | 4-5h |
| Auto-Copy | Low | 1-2h |
| Language | Medium | 3-4h |
| Auto-Punctuation | High | 6-8h |

**Total:** 24-33 hours

---

## Next Steps

1. Start with Feature 1-3 (high priority, low complexity)
2. Validate each feature manually
3. Add tests for new functionality
4. Update QA Checklist
5. Proceed to Feature 4-6
6. Evaluate Feature 7-8 based on user feedback
