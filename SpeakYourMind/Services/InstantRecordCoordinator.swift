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
///
/// Behavior is controlled by two settings:
/// - `instantDictationUsesOverlay`: routes speech to the overlay panel instead of injecting directly
/// - `autoUpdateClipboard`: only updates the clipboard during streaming when explicitly enabled
final class InstantRecordCoordinator: ObservableObject {

    /// Manages speech recognition and audio capture.
    let speechManager: SpeechManager
    
    /// Handles text injection into the focused application (batch mode).
    let textInjector: TextInjector
    
    /// Handles streaming/incremental text injection during recording.
    private var streamingTextInjector = StreamingTextInjector()
    
    /// Current injection mode (batch or streaming).
    private var injectionMode: InjectionMode = .streaming

    /// Whether instant dictation routes to the overlay panel (true) or injects directly (false).
    var instantDictationUsesOverlay: Bool = true

    /// Whether to automatically update the clipboard with transcribed text during streaming.
    private var autoUpdateClipboard: Bool = false
    
    /// Manages accessibility permissions for text injection.
    let permissionsManager: PermissionsManager
    
    /// Visual indicator panel shown during recording.
    let indicatorPanel: RecordingIndicatorPanel
    
    /// Reference to the status item button for positioning the indicator
    weak var statusItemButton: NSStatusBarButton? {
        didSet {
            indicatorPanel.statusItemButton = statusItemButton
        }
    }

    /// Current state of the coordinator.
    @Published var state: CoordinatorState = .idle
    
    /// Callback for showing error toasts.
    var onError: ((String) -> Void)?
    
    /// Callback for showing success messages.
    var onSuccess: ((String) -> Void)?
    
    var isRecording = false
    
    /// Tracks whether we've fallen back to batch mode due to cursor drift.
    private var hasFallenBackToBatch = false
    
    init() {
        self.speechManager = SpeechManager()
        self.textInjector = TextInjector()
        self.permissionsManager = PermissionsManager()
        self.indicatorPanel = RecordingIndicatorPanel()
        setupErrorHandling()
        speechManager.onFinalResult = { [weak self] text in
            print("[InstantRecordCoordinator] Final speech result: \(text.prefix(50))...")
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.handleSpeechResult(text)
            }
        }
        setupObservers()
    }
    
    private func setupObservers() {
        // Listen for injection mode changes from SettingsViewModel
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInjectionModeChange(_:)),
            name: .injectionModeDidChange,
            object: nil
        )

        // Listen for instant dictation behavior changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInstantDictationBehaviorChange(_:)),
            name: .instantDictationBehaviorDidChange,
            object: nil
        )
        
        // Load initial values from UserDefaults
        if let modeString = UserDefaults.standard.string(forKey: "useStreamingMode"),
           let mode = InjectionMode(rawValue: modeString) {
            injectionMode = mode
        } else {
            injectionMode = .streaming
        }

        instantDictationUsesOverlay = UserDefaults.standard.object(forKey: "instantDictationUsesOverlay") as? Bool ?? true
        autoUpdateClipboard = UserDefaults.standard.object(forKey: "autoUpdateClipboard") as? Bool ?? false
    }
    
    @objc private func handleInjectionModeChange(_ notification: Notification) {
        if let mode = notification.userInfo?["mode"] as? InjectionMode {
            injectionMode = mode
            print("[InstantRecordCoordinator] Injection mode changed to: \(mode)")
        }
    }

    @objc private func handleInstantDictationBehaviorChange(_ notification: Notification) {
        if let usesOverlay = notification.userInfo?["usesOverlay"] as? Bool {
            instantDictationUsesOverlay = usesOverlay
            print("[InstantRecordCoordinator] Instant dictation uses overlay: \(usesOverlay)")
        }
        // Also refresh autoUpdateClipboard from UserDefaults (no separate notification needed)
        autoUpdateClipboard = UserDefaults.standard.object(forKey: "autoUpdateClipboard") as? Bool ?? false
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
    /// Behavior depends on the `instantDictationUsesOverlay` setting:
    /// - **Overlay mode** (default): Shows the overlay panel and routes speech to its text field.
    ///   Text is not injected directly; the user interacts with it from within the overlay.
    /// - **Direct injection mode**: Speech is injected directly into the focused field using
    ///   `StreamingTextInjector` (streaming) or `TextInjector` (batch).
    func toggle() {
        print("[InstantRecordCoordinator] toggle() called, instantDictationUsesOverlay=\(instantDictationUsesOverlay)")
        if isRecording {
            print("[InstantRecordCoordinator] toggle() → branch: isRecording=true, calling stopAndFinish()")
            stopAndFinish()
        } else {
            // Refresh autoUpdateClipboard in case it changed without a notification
            autoUpdateClipboard = UserDefaults.standard.object(forKey: "autoUpdateClipboard") as? Bool ?? false

            if instantDictationUsesOverlay {
                print("[InstantRecordCoordinator] toggle() → branch: overlay mode, calling showOverlayAndRecord()")
                showOverlayAndRecord()
            } else {
                print("[InstantRecordCoordinator] toggle() → branch: direct injection mode, calling startRecordingAsync()")
                // Reset streaming injector when starting direct injection
                streamingTextInjector.clearBuffer()
                hasFallenBackToBatch = false

                Task {
                    await startRecordingAsync()
                }
            }
        }
    }

    // MARK: - Overlay Mode

    /// Shows the overlay panel and begins recording into it.
    ///
    /// The overlay's own SpeechManager receives all speech output.
    /// No `StreamingTextInjector` is used, and the clipboard is not touched.
    private func showOverlayAndRecord() {
        guard let appDelegate = NSApp.delegate as? AppDelegate else {
            print("[InstantRecordCoordinator] AppDelegate unavailable — cannot show overlay")
            return
        }

        print("[InstantRecordCoordinator] showOverlayAndRecord() called, overlayPanel.isVisible=\(appDelegate.overlayPanel.isVisible)")

        // Show and focus the overlay panel
        DispatchQueue.main.async {
            appDelegate.overlayPanel.center()
            appDelegate.overlayPanel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            print("[InstantRecordCoordinator] showOverlayAndRecord() overlay shown, isVisible=\(appDelegate.overlayPanel.isVisible)")
        }

        // Post a notification so MainView can start listening automatically
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("[InstantRecordCoordinator] showOverlayAndRecord() posting instantDictationDidActivateOverlay notification")
            NotificationCenter.default.post(
                name: .instantDictationDidActivateOverlay,
                object: nil
            )
        }

        print("[InstantRecordCoordinator] Overlay mode: opened overlay panel for instant dictation")
        // Recording lifecycle is owned by MainView's speechManager in overlay mode;
        // we do not set isRecording here so subsequent toggles re-show the overlay.
    }

    // MARK: - Direct Injection Mode
    
    /// Sets the injection mode for text injection.
    /// - Parameter mode: The injection mode to use (.batch or .streaming)
    func setInjectionMode(_ mode: InjectionMode) {
        injectionMode = mode
        print("[InstantRecordCoordinator] Injection mode set to: \(mode)")
    }
    
    /// Updates the clipboard with the full accumulated text.
    /// Only called when `autoUpdateClipboard` is enabled.
    /// - Parameter text: The full accumulated text to copy to clipboard
    private func updateClipboardIfEnabled(_ text: String) {
        guard autoUpdateClipboard else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        _ = pasteboard.setString(text, forType: .string)
        print("[InstantRecordCoordinator] Clipboard updated with \(text.count) chars (autoUpdateClipboard=true)")
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
            startDirectRecording()
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

    /// Starts direct-injection recording (must be called from main thread).
    private func startDirectRecording() {
        print("[InstantRecordCoordinator] startDirectRecording() called — injectionMode=\(injectionMode), autoUpdateClipboard=\(autoUpdateClipboard), instantDictationUsesOverlay=\(instantDictationUsesOverlay)")
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
                
                // Only update clipboard when the setting is enabled
                let fullText = self.streamingTextInjector.getAccumulatedText()
                self.updateClipboardIfEnabled(fullText)
                
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

    /// Stops recording and, in direct injection mode, injects the accumulated text.
    private func stopAndFinish() {
        print("[InstantRecordCoordinator] stopAndFinish() called — isRecording=\(isRecording), instantDictationUsesOverlay=\(instantDictationUsesOverlay)")
        if let appDelegate = NSApp.delegate as? AppDelegate {
            print("[InstantRecordCoordinator] stopAndFinish() overlayPanel.isVisible=\(appDelegate.overlayPanel.isVisible)")
        }
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

            if !self.instantDictationUsesOverlay {
                // Direct injection mode: inject text into the focused application
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
            } else {
                // Overlay mode: skip direct injection — text remains in the overlay panel
                print("[InstantRecordCoordinator] Overlay mode: skipping direct injection, text stays in overlay")
                self.state = .idle
            }
        }
    }
}
