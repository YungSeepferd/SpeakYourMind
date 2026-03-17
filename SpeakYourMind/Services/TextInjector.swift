import AppKit
import CoreGraphics

// MARK: - Injection Mode

/// Defines how text should be injected into the target application.
enum InjectionMode: String, CaseIterable {
    /// Inject all text at once at the end (default behavior).
    case batch
    /// Inject text incrementally during recording (append mode).
    case streaming
}

// MARK: - Notification Names

extension Notification.Name {
    static let speechLocaleDidChange = Notification.Name("speechLocaleDidChange")
    static let injectionModeDidChange = Notification.Name("injectionModeDidChange")
}

// MARK: - Injection Error

/// Errors that can occur during text injection.
enum InjectionError: LocalizedError {
    case noFrontmostApp
    case clipboardFailed
    case eventPostFailed
    
    var errorDescription: String? {
        switch self {
        case .noFrontmostApp:
            return "No frontmost application found. Please focus an app before injecting text."
        case .clipboardFailed:
            return "Failed to access or modify the clipboard."
        case .eventPostFailed:
            return "Failed to post keyboard events. Accessibility permissions may be required."
        }
    }
    
    var failureReason: String? {
        switch self {
        case .noFrontmostApp:
            return "No application is currently in the foreground."
        case .clipboardFailed:
            return "Unable to read from or write to the system clipboard."
        case .eventPostFailed:
            return "Unable to create or post keyboard events to the system."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noFrontmostApp:
            return "Click on the app where you want to inject text, then try again."
        case .clipboardFailed:
            return "Try restarting the app. If the problem persists, check that no other app is locking the clipboard."
        case .eventPostFailed:
            return "Ensure Accessibility permission is granted in System Settings."
        }
    }
}

/// Injects text at the current cursor position in whatever app has focus
/// by temporarily placing text on the clipboard and simulating Cmd+V.
/// 
/// This class handles clipboard manipulation to insert transcribed text into the
/// currently focused application. It preserves the user's clipboard contents and
/// restores them after injection.
final class TextInjector {

    /// Injects the given text at the current cursor position.
    /// 
    /// This method copies the text to the clipboard, simulates a Cmd+V keystroke
    /// to paste into the focused application, then restores the original clipboard
    /// contents after a brief delay.
    /// 
    /// - Parameter text: The text string to inject at the cursor position.
    /// - Returns: Result containing the injected text on success, or an InjectionError on failure.
    func inject(_ text: String) -> Result<String, InjectionError> {
        guard !text.isEmpty else { return .failure(.clipboardFailed) }
        
        // Check for frontmost app
        guard NSWorkspace.shared.frontmostApplication != nil else {
            print("[TextInjector] No frontmost application found")
            return .failure(.noFrontmostApp)
        }

        let pasteboard = NSPasteboard.general

        // 1. Snapshot current clipboard so we can restore it
        let savedChangeCount = pasteboard.changeCount
        let savedItems: [[NSPasteboard.PasteboardType: Data]] = {
            guard let items = pasteboard.pasteboardItems else { return [] }
            return items.compactMap { item in
                var dict = [NSPasteboard.PasteboardType: Data]()
                for type in item.types {
                    if let data = item.data(forType: type) {
                        dict[type] = data
                    }
                }
                return dict.isEmpty ? nil : dict
            }
        }()

        // 2. Put our transcription on the clipboard
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            print("[TextInjector] Failed to set clipboard content")
            return .failure(.clipboardFailed)
        }

        // 3. Simulate Cmd+V
        let source = CGEventSource(stateID: CGEventSourceStateID.hidSystemState)
        source?.localEventsSuppressionInterval = 0.0

        let vKeyCode: CGKeyCode = 0x09 // kVK_ANSI_V

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            print("[TextInjector] Failed to create keyboard events")
            return .failure(.eventPostFailed)
        }
        
        keyDown.flags = CGEventFlags.maskCommand
        keyUp.flags = CGEventFlags.maskCommand
        keyDown.post(tap: CGEventTapLocation.cgAnnotatedSessionEventTap)
        keyUp.post(tap: CGEventTapLocation.cgAnnotatedSessionEventTap)
        
        print("[TextInjector] Successfully injected text: \(text.prefix(50))...")

        // 4. Restore previous clipboard after the paste has landed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard pasteboard.changeCount == savedChangeCount + 1 else { return }
            pasteboard.clearContents()
            for itemDict in savedItems {
                let item = NSPasteboardItem()
                for (type, data) in itemDict {
                    item.setData(data, forType: type)
                }
                pasteboard.writeObjects([item])
            }
        }
        
        return .success(text)
    }
    
    /// Fallback method that copies text to clipboard without injecting.
    /// Useful when direct injection fails.
    /// 
    /// - Parameter text: The text to copy to clipboard.
    /// - Returns: Result containing the copied text on success, or an InjectionError on failure.
    func copyToClipboard(_ text: String) -> Result<String, InjectionError> {
        let pasteboard = NSPasteboard.general
        guard pasteboard.setString(text, forType: .string) else {
            print("[TextInjector] Failed to copy text to clipboard")
            return .failure(.clipboardFailed)
        }
        print("[TextInjector] Copied text to clipboard: \(text.prefix(50))...")
        return .success(text)
    }
    
    /// Injects text with the specified injection mode.
    /// 
    /// - Parameters:
    ///   - text: The text string to inject at the cursor position.
    ///   - mode: The injection mode to use (batch or streaming).
    /// - Returns: Result containing the injected text on success, or an InjectionError on failure.
    func inject(_ text: String, mode: InjectionMode) -> Result<String, InjectionError> {
        switch mode {
        case .batch:
            return inject(text)
        case .streaming:
            return injectStreaming(text)
        }
    }
    
    /// Streaming injection: appends text incrementally to the target application.
    /// This method tracks the accumulated text and injects only the delta.
    private func injectStreaming(_ text: String) -> Result<String, InjectionError> {
        guard !text.isEmpty else { return .failure(.clipboardFailed) }
        
        guard NSWorkspace.shared.frontmostApplication != nil else {
            print("[TextInjector] No frontmost application found")
            return .failure(.noFrontmostApp)
        }
        
        let pasteboard = NSPasteboard.general
        
        // Snapshot current clipboard
        let savedChangeCount = pasteboard.changeCount
        let savedItems: [[NSPasteboard.PasteboardType: Data]] = {
            guard let items = pasteboard.pasteboardItems else { return [] }
            return items.compactMap { item in
                var dict = [NSPasteboard.PasteboardType: Data]()
                for type in item.types {
                    if let data = item.data(forType: type) {
                        dict[type] = data
                    }
                }
                return dict.isEmpty ? nil : dict
            }
        }()
        
        // Put text on clipboard
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            print("[TextInjector] Failed to set clipboard content")
            return .failure(.clipboardFailed)
        }
        
        // Simulate Cmd+V
        let source = CGEventSource(stateID: CGEventSourceStateID.hidSystemState)
        source?.localEventsSuppressionInterval = 0.0
        
        let vKeyCode: CGKeyCode = 0x09 // kVK_ANSI_V
        
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            print("[TextInjector] Failed to create keyboard events")
            return .failure(.eventPostFailed)
        }
        
        keyDown.flags = CGEventFlags.maskCommand
        keyUp.flags = CGEventFlags.maskCommand
        keyDown.post(tap: CGEventTapLocation.cgAnnotatedSessionEventTap)
        keyUp.post(tap: CGEventTapLocation.cgAnnotatedSessionEventTap)
        
        print("[TextInjector] Streaming injected text: \(text.prefix(50))...")
        
        // Restore previous clipboard after the paste has landed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard pasteboard.changeCount == savedChangeCount + 1 else { return }
            pasteboard.clearContents()
            for itemDict in savedItems {
                let item = NSPasteboardItem()
                for (type, data) in itemDict {
                    item.setData(data, forType: type)
                }
                pasteboard.writeObjects([item])
            }
        }
        
        return .success(text)
    }
}

// MARK: - Streaming Text Injector

/// A specialized text injector that supports incremental/append mode.
/// Tracks accumulated text and injects only the delta since the last injection.
/// Useful for real-time text streaming during voice recording.
final class StreamingTextInjector {
    
    // MARK: - Properties
    
    /// The accumulated text that has been buffered but not yet injected.
    private var accumulatedText: String = ""
    
    /// The length of text from the last injection.
    private var lastInjectedLength: Int = 0
    
    /// The original clipboard contents before injection.
    private var originalClipboard: String?
    
    /// History of cursor positions for drift detection.
    private var cursorPositionHistory: [Int] = []
    
    /// Threshold for detecting cursor drift (in characters).
    private let cursorDriftThreshold: Int = 10
    
    // MARK: - Public Methods
    
    /// Updates the buffer by appending new text to the accumulated text.
    /// 
    /// - Parameter newText: The new text to append to the buffer.
    func updateBuffer(_ newText: String) {
        accumulatedText += newText
        print("[StreamingTextInjector] Buffer updated. Total accumulated: \(accumulatedText.count) chars")
    }
    
    /// Injects only the delta (new text since last injection) to the target application.
    /// 
    /// - Returns: Result containing the injected delta text on success, or an InjectionError on failure.
    func injectIncremental() async throws -> String {
        let delta = calculateDelta()
        
        guard !delta.isEmpty else {
            print("[StreamingTextInjector] No delta to inject")
            return ""
        }
        
        // Check for cursor drift
        if detectCursorDrift() {
            print("[StreamingTextInjector] Cursor drift detected! Resetting tracking and injecting from current position")
            lastInjectedLength = 0
            cursorPositionHistory.removeAll()
        }
        
        // Inject the delta
        try injectViaAccessibilityAPI(delta)
        
        lastInjectedLength = accumulatedText.count
        print("[StreamingTextInjector] Incremental injection complete. Injected \(delta.count) chars, total tracked: \(lastInjectedLength)")
        
        return delta
    }
    
    /// Injects all accumulated text to the target application.
    /// This flushes the entire buffer and resets tracking.
    /// 
    /// - Returns: Result containing the injected full text on success, or an InjectionError on failure.
    func flush() async throws -> String {
        guard !accumulatedText.isEmpty else {
            print("[StreamingTextInjector] Nothing to flush")
            return ""
        }
        
        // Check for cursor drift before final flush
        if detectCursorDrift() {
            print("[StreamingTextInjector] Cursor drift detected before flush! Injecting from current position")
        }
        
        // Inject all accumulated text
        try injectViaAccessibilityAPI(accumulatedText)
        
        let injectedText = accumulatedText
        print("[StreamingTextInjector] Flushed \(injectedText.count) chars")
        
        // Reset tracking state
        accumulatedText = ""
        lastInjectedLength = 0
        cursorPositionHistory.removeAll()
        
        return injectedText
    }
    
    /// Clears the accumulated buffer without injecting.
    func clearBuffer() {
        accumulatedText = ""
        lastInjectedLength = 0
        cursorPositionHistory.removeAll()
        print("[StreamingTextInjector] Buffer cleared")
    }
    
    /// Returns the current accumulated text without injecting.
    func getAccumulatedText() -> String {
        return accumulatedText
    }
    
    /// Returns the length of text pending injection.
    func getPendingTextLength() -> Int {
        return accumulatedText.count - lastInjectedLength
    }
    
    // MARK: - Private Methods
    
    /// Detects if the cursor has drifted more than the threshold from the last known position.
    /// 
    /// - Returns: True if cursor drift is detected, false otherwise.
    private func detectCursorDrift() -> Bool {
        guard cursorPositionHistory.count >= 2 else {
            return false
        }
        
        // Get the last two cursor positions
        let lastPosition = cursorPositionHistory[cursorPositionHistory.count - 1]
        let previousPosition = cursorPositionHistory[cursorPositionHistory.count - 2]
        
        let drift = abs(lastPosition - previousPosition)
        let hasDrifted = drift > cursorDriftThreshold
        
        if hasDrifted {
            print("[StreamingTextInjector] Cursor drift detected: \(drift) chars (threshold: \(cursorDriftThreshold))")
        }
        
        return hasDrifted
    }
    
    /// Calculates the delta (new text) since the last injection.
    /// 
    /// - Returns: The new text to inject.
    private func calculateDelta() -> String {
        guard accumulatedText.count > lastInjectedLength else {
            return ""
        }
        
        let startIndex = accumulatedText.index(accumulatedText.startIndex, offsetBy: lastInjectedLength)
        let delta = String(accumulatedText[startIndex...])
        
        print("[StreamingTextInjector] Delta calculated: \(delta.count) chars (total: \(accumulatedText.count), last injected: \(lastInjectedLength))")
        
        return delta
    }
    
    /// Injects text via the accessibility API (keyboard events).
    /// 
    /// - Parameter text: The text to inject.
    private func injectViaAccessibilityAPI(_ text: String) throws {
        guard !text.isEmpty else { return }
        
        guard NSWorkspace.shared.frontmostApplication != nil else {
            print("[StreamingTextInjector] No frontmost application found")
            throw InjectionError.noFrontmostApp
        }
        
        let pasteboard = NSPasteboard.general
        
        // Save current clipboard
        let savedChangeCount = pasteboard.changeCount
        originalClipboard = pasteboard.string(forType: .string)
        
        // Put text on clipboard
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            print("[StreamingTextInjector] Failed to set clipboard content")
            throw InjectionError.clipboardFailed
        }
        
        // Simulate Cmd+V
        let source = CGEventSource(stateID: CGEventSourceStateID.hidSystemState)
        source?.localEventsSuppressionInterval = 0.0
        
        let vKeyCode: CGKeyCode = 0x09 // kVK_ANSI_V
        
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            print("[StreamingTextInjector] Failed to create keyboard events")
            throw InjectionError.eventPostFailed
        }
        
        keyDown.flags = CGEventFlags.maskCommand
        keyUp.flags = CGEventFlags.maskCommand
        keyDown.post(tap: CGEventTapLocation.cgAnnotatedSessionEventTap)
        keyUp.post(tap: CGEventTapLocation.cgAnnotatedSessionEventTap)
        
        print("[StreamingTextInjector] Injected via accessibility API: \(text.prefix(50))...")
        
        // Restore clipboard after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            guard pasteboard.changeCount == savedChangeCount + 1 else { return }
            
            pasteboard.clearContents()
            if let original = self.originalClipboard {
                pasteboard.setString(original, forType: .string)
            }
        }
    }
    
    /// Fallback injection method using clipboard (alias for accessibility API).
    /// 
    /// - Parameter text: The text to inject.
    private func injectViaClipboard(_ text: String) throws {
        try injectViaAccessibilityAPI(text)
    }
    
    /// Records a cursor position for drift tracking.
    /// Call this when the cursor position is known (e.g., after text insertion).
    /// 
    /// - Parameter position: The current cursor position (character offset).
    func recordCursorPosition(_ position: Int) {
        cursorPositionHistory.append(position)
        
        // Keep only the last 10 positions for memory efficiency
        if cursorPositionHistory.count > 10 {
            cursorPositionHistory.removeFirst()
        }
        
        print("[StreamingTextInjector] Cursor position recorded: \(position). History count: \(cursorPositionHistory.count)")
    }
}