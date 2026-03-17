import AppKit
import Speech

// MARK: - Coordinator State

/// Represents the current state of the instant record coordinator.
enum CoordinatorState: Equatable {
    case idle
    case recording
    case injecting
    case error(String)
    
    static func == (lhs: CoordinatorState, rhs: CoordinatorState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.recording, .recording), (.injecting, .injecting):
            return true
        case (.error(let lhsMsg), .error(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

// MARK: - Instant Record Coordinator

/// Coordinates the instant-record hotkey mode:
/// press hotkey → start recording → press again → inject text at cursor.
/// 
/// This coordinator orchestrates the complete instant-record workflow by managing
/// the speech manager, text injector, permissions, and recording indicator panel.
final class InstantRecordCoordinator: ObservableObject {

    /// Manages speech recognition and audio capture.
    let speechManager: SpeechManager
    
    /// Handles text injection into the focused application (batch mode).
    let textInjector: TextInjector
    
    /// Handles streaming/incremental text injection during recording.
    private var streamingTextInjector = StreamingTextInjector()
    
    /// Current injection mode (batch or streaming).
    private var injectionMode: InjectionMode = .streaming
    
    /// Manages accessibility permissions for text injection.
    let permissionsManager: PermissionsManager
    
    /// Visual indicator panel shown during recording.
    let indicatorPanel: RecordingIndicatorPanel

    /// Current state of the coordinator.
    @Published var state: CoordinatorState = .idle
    
    /// Callback for showing error toasts.
    var onError: ((String) -> Void)?
    
    /// Callback for showing success messages.
    var onSuccess: ((String) -> Void)?
    
    private var isRecording = false
    
    /// Tracks whether we've fallen back to batch mode due to cursor drift.
    private var hasFallenBackToBatch = false
    
    init() {
        self.speechManager = SpeechManager()
        self.textInjector = TextInjector()
        self.permissionsManager = PermissionsManager()
        self.indicatorPanel = RecordingIndicatorPanel()
        setupErrorHandling()
        setupInjectionModeObserver()
    }
    
    private func setupInjectionModeObserver() {
        // Listen for injection mode changes from SettingsViewModel
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInjectionModeChange(_:)),
            name: .injectionModeDidChange,
            object: nil
        )
        
        // Load initial mode from UserDefaults
        let useStreaming = UserDefaults.standard.bool(forKey: "useStreamingMode")
        injectionMode = useStreaming ? .streaming : .batch
    }
    
    @objc private func handleInjectionModeChange(_ notification: Notification) {
        if let mode = notification.userInfo?["mode"] as? InjectionMode {
            injectionMode = mode
            print("[InstantRecordCoordinator] Injection mode changed to: \(mode)")
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupErrorHandling() {
        speechManager.onError = { [weak self] error in
            self?.handleSpeechError(error)
        }
    }
    
    private func handleSpeechError(_ error: SpeechError) {
        print("[InstantRecordCoordinator] Speech error: \(error.localizedDescription)")
        state = .error(error.localizedDescription)
        onError?(error.localizedDescription)
        
        // Reset to idle after showing error
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            if case .error = self?.state {
                self?.state = .idle
            }
        }
    }
    
    private func handleInjectionError(_ error: InjectionError) {
        print("[InstantRecordCoordinator] Injection error: \(error.localizedDescription)")
        
        // Fallback to clipboard copy
        let text = speechManager.transcribedText
        if !text.isEmpty {
            let result = textInjector.copyToClipboard(text)
            switch result {
            case .success:
                onSuccess?("Copied to clipboard (injection failed)")
            case .failure(let copyError):
                state = .error(copyError.localizedDescription)
                onError?(copyError.localizedDescription)
            }
        } else {
            state = .error(error.localizedDescription)
            onError?(error.localizedDescription)
        }
    }

    /// Toggles between recording and stopped states.
    /// 
    /// If not recording, starts speech recognition and shows the indicator panel.
    /// If currently recording, stops recognition and injects the transcribed text
    /// at the current cursor position.
    func toggle() {
        if isRecording {
            stopAndInject()
        } else {
            // Reset streaming injector when starting
            streamingTextInjector.clearBuffer()
            hasFallenBackToBatch = false
            
            Task {
                await startRecordingAsync()
            }
        }
    }
    
    /// Sets the injection mode for text injection.
    /// - Parameter mode: The injection mode to use (.batch or .streaming)
    func setInjectionMode(_ mode: InjectionMode) {
        injectionMode = mode
        print("[InstantRecordCoordinator] Injection mode set to: \(mode)")
    }
    
    /// Updates the clipboard with the full accumulated text.
    /// Called on each partial result with the complete text.
    /// - Parameter text: The full accumulated text to copy to clipboard
    private func updateClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        _ = pasteboard.setString(text, forType: .string)
        print("[InstantRecordCoordinator] Clipboard updated with \(text.count) chars")
    }
    
    /// Handles cursor drift detection and falls back to batch mode if needed.
    private func handleCursorDrift() {
        guard !hasFallenBackToBatch else { return }
        
        // Show warning via UserFeedbackManager
        UserFeedbackManager.shared.showWarning("Cursor drift detected. Falling back to batch mode for remainder of session.")
        
        // Fall back to batch mode
        injectionMode = .batch
        hasFallenBackToBatch = true
        
        print("[InstantRecordCoordinator] Fell back to batch mode due to cursor drift")
    }

    /// Starts recording after checking permissions asynchronously.
    private func startRecordingAsync() async {
        // Check accessibility permission first
        let accessibilityGranted = await permissionsManager.checkAndRequestAccessibility()
        
        guard accessibilityGranted else {
            handlePermissionDenied()
            return
        }
        
        // Also check speech permissions
        let permissionsGranted = await speechManager.checkAndRequestPermissions()
        
        guard permissionsGranted else {
            handleSpeechPermissionDenied()
            return
        }
        
        // Permissions granted, start recording on main actor
        await MainActor.run {
            startRecording()
        }
    }
    
    private func handlePermissionDenied() {
        let status = permissionsManager.accessibilityStatus
        switch status {
        case .denied:
            onError?("Accessibility permission denied. Please enable it in System Settings > Privacy & Security > Accessibility.")
        case .restricted:
            onError?("Accessibility permission is restricted. Please contact your administrator.")
        case .notDetermined:
            onError?("Accessibility permission not determined. Please try again.")
        case .authorized:
            break
        }
        state = .idle
    }
    
    private func handleSpeechPermissionDenied() {
        let micStatus = speechManager.microphoneStatus
        let speechStatus = speechManager.speechRecognitionStatus
        
        if micStatus == .denied || micStatus == .restricted {
            onError?("Microphone permission denied. Please enable it in System Settings > Privacy & Security > Microphone.")
        } else if speechStatus == .denied || speechStatus == .restricted {
            onError?("Speech recognition permission denied. Please enable it in System Settings > Privacy & Security > Speech Recognition.")
        } else {
            onError?("Permission check failed. Please try again.")
        }
        
        state = .idle
    }

    /// Starts recording (must be called from main thread).
    private func startRecording() {
        guard permissionsManager.isAccessibilityGranted else {
            permissionsManager.requestAccessibilityIfNeeded()
            onError?("Accessibility permission required. Please grant access in System Settings.")
            return
        }

        isRecording = true
        state = .recording
        speechManager.resetTranscription()
        
        // Wire up partial result callback for streaming mode
        speechManager.onPartialResult = { [weak self] partialText in
            guard let self else { return }
            
            if self.injectionMode == .streaming && !self.hasFallenBackToBatch {
                // Update the streaming injector's buffer
                self.streamingTextInjector.updateBuffer(partialText)
                
                // Update clipboard with full accumulated text
                let fullText = self.streamingTextInjector.getAccumulatedText()
                self.updateClipboard(fullText)
                
                // Try incremental injection
                Task {
                    do {
                        _ = try await self.streamingTextInjector.injectIncremental()
                    } catch {
                        // If injection fails due to cursor drift, fall back to batch
                        self.handleCursorDrift()
                    }
                }
            }
        }
        
        do {
            try speechManager.startListening()
        } catch let error as SpeechError {
            handleSpeechError(error)
            isRecording = false
            state = .idle
            return
        } catch {
            handleSpeechError(.recognitionFailed(underlying: error))
            isRecording = false
            state = .idle
            return
        }

        if UserDefaults.standard.bool(forKey: "showIndicator") != false {
            indicatorPanel.show()
        }
    }

    private func stopAndInject() {
        isRecording = false
        state = .injecting
        speechManager.stopListening()
        indicatorPanel.hide()

        // Brief delay for final recognition result
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            guard !self.speechManager.transcribedText.isEmpty else {
                self.state = .idle
                return
            }
            
            let text = self.speechManager.transcribedText
            let result = self.textInjector.inject(text)
            
            switch result {
            case .success:
                self.state = .idle
                self.onSuccess?("Text injected successfully")
            case .failure(let error):
                self.handleInjectionError(error)
            }
            
            self.speechManager.resetTranscription()
        }
    }
}