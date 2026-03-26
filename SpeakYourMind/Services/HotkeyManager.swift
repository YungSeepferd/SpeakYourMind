import KeyboardShortcuts
import AppKit
import Combine

/// Defines keyboard shortcuts for SpeakYourMind functionality.
extension KeyboardShortcuts.Name {
    /// Opens the overlay panel for manual record/stop/edit/copy workflow.
    /// 
    /// Default shortcut: Control + Option + Command + Space (⌃⌥⌘ Space)
    static let openOverlay = Self("openOverlay", default: .init(.space, modifiers: [.control, .option, .command]))

    /// Instantly toggles recording — text is injected at cursor when stopped.
    /// 
    /// This hotkey provides a quick record-to-inject workflow. Press to start recording,
    /// press again to stop and automatically inject the transcribed text at the cursor.
    /// 
    /// Default shortcut: Control + Option + Command (⌃⌥⌘) - modifier-only hotkey
    /// Note: Modifier-only hotkeys require Accessibility permission and use a custom handler.
    /// This shortcut is handled by ModifierOnlyHotkeyMonitor, not KeyboardShortcuts directly.
    static let instantRecord = Self("instantRecord")
}

/// Monitors for modifier-only hotkey combinations (⌃⌥⌘ without any non-modifier key)
final class ModifierOnlyHotkeyMonitor: ObservableObject {
    static let shared = ModifierOnlyHotkeyMonitor()
    
    /// The modifier flags we're monitoring for (⌃⌥⌘)
    private let targetModifiers: NSEvent.ModifierFlags = [.control, .option, .command]
    
    /// Flag to track if the target modifiers are currently held
    @Published private(set) var isModifierComboHeld = false
    
    /// Callback when modifier-only combo is triggered (pressed and released without other keys)
    var onTrigger: (() -> Void)?
    
    private var eventMonitor: Any?
    private var flagsChangedMonitor: Any?
    private var lastModifiers: NSEvent.ModifierFlags = []
    private var wasTargetHeld = false
    
    private init() {}
    
    func start() {
        // Monitor for modifier flags changes
        flagsChangedMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        
        // Also add local monitor for when app is active
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
    }
    
    func stop() {
        if let monitor = flagsChangedMonitor {
            NSEvent.removeMonitor(monitor)
            flagsChangedMonitor = nil
        }
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func handleFlagsChanged(_ event: NSEvent) {
        let currentModifiers = event.modifierFlags.intersection([.control, .option, .command, .shift, .capsLock, .numericPad, .function])
        
        // Check if exactly our target modifiers are held (no extra modifiers)
        let isTargetNowHeld = currentModifiers == targetModifiers
        
        // Detect press (transition from not held to held)
        if isTargetNowHeld && !wasTargetHeld {
            wasTargetHeld = true
        }
        
        // Detect release (transition from held to not held)
        if !isTargetNowHeld && wasTargetHeld {
            wasTargetHeld = false
            // Only trigger if no other non-modifier keys were pressed
            onTrigger?()
        }
        
        isModifierComboHeld = isTargetNowHeld
        lastModifiers = currentModifiers
    }
}

/// Manages keyboard shortcuts for the app
final class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()
    
    @Published var isInstantRecordActive = false
    
    private var cancellables = Set<AnyCancellable>()
    private let modifierMonitor = ModifierOnlyHotkeyMonitor.shared
    
    private init() {
        setupHotkeys()
    }
    
    func setupHotkeys() {
        // Listen to KeyboardShortcuts for the regular hotkey
        KeyboardShortcuts.onKeyUp(for: .instantRecord) { [weak self] in
            // This handles cases where user sets a non-modifier shortcut
            self?.handleInstantRecordTrigger()
        }
    }
    
    private func handleInstantRecordTrigger() {
        isInstantRecordActive.toggle()
        NotificationCenter.default.post(
            name: .instantRecordHotkey,
            object: nil,
            userInfo: ["isActive": isInstantRecordActive]
        )
    }
    
    func cleanup() {
        modifierMonitor.stop()
    }
}

extension Notification.Name {
    static let instantRecordHotkey = Notification.Name("instantRecordHotkey")
}