import Foundation
import Combine
import SwiftUI

extension Notification.Name {
    static let symOverlaySizeDidChange = Notification.Name("symOverlaySizeDidChange")
}

/// Overlay display mode - tells user what interaction pattern is active.
enum OverlayMode: String {
    case idle = "Ready"
    case overlayDictation = "Overlay Dictation"
    case instantDictation = "Instant Dictation"
    case edgeCapture = "Edge Capture"
    case processingAI = "Processing…"
    case error = "Error"
}

/// Output action - tells user what will happen when recording stops.
enum OutputAction {
    case saveSessionOnly      // Save to session, no injection
    case injectOnStop         // Inject text into focused app when stop
    case copyToClipboard      // Copy to clipboard when stop

    var description: String {
        switch self {
        case .saveSessionOnly: return "Save to Session"
        case .injectOnStop: return "Inject on Stop"
        case .copyToClipboard: return "Copy to Clipboard"
        }
    }
}

/// Size of the overlay window — single source of truth for dimensions.
enum OverlaySize: String, CaseIterable, Codable {
    case compact = "Compact"
    case standard = "Standard"
    case expanded = "Expanded"

    /// Content size for the SwiftUI view (NSPanel uses frameRect(forContentRect:) to add chrome).
    var contentSize: CGSize {
        switch self {
        case .compact:  return CGSize(width: 360, height: 200)
        case .standard: return CGSize(width: 460, height: 380)
        case .expanded: return CGSize(width: 580, height: 560)
        }
    }
}

/// Which tab is active in the transcript area.
enum TranscriptTab: String, CaseIterable {
    case original = "Original"
    case aiResult = "AI Result"
}

/// What the user wants to do after declining an AI result.
enum DeclineAction {
    case reprompt           // New instruction, same source text
    case refinePrompt       // Edit original instruction, resend
    case editPayload        // Edit source text, resend with same instruction
    case revert             // Discard AI result entirely
}

/// Centralized state management for overlay UI.
/// Encapsulates all UI state transitions and mode logic.
final class OverlayViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current overlay mode (which entry point triggered this)
    @Published var currentMode: OverlayMode = .idle
    
    /// What will happen when user stops recording
    @Published var outputAction: OutputAction = .saveSessionOnly
    
    /// Whether currently recording
    @Published var isRecording: Bool = false
    
    /// Whether recording is paused
    @Published var isPaused: Bool = false
    
    /// Whether has transcribed text
    @Published var hasText: Bool = false
    
    /// Whether Ollama is available
    @Published var ollamaAvailable: Bool = false
    
    /// Status message for header display
    @Published var statusMessage: String = "Ready"
    
    /// Whether processing AI request
    @Published var isProcessingAI: Bool = false
    
    /// AI error message
    @Published var aiErrorMessage: String? = nil

    // MARK: - AI Result Tab State

    /// Active transcript tab
    @Published var activeTab: TranscriptTab = .original

    /// The original text before AI processing (preserved for revert)
    @Published var aiOriginalText: String? = nil

    /// The AI-processed result text
    @Published var aiResultText: String? = nil

    /// The instruction/prompt used for the last AI request
    @Published var lastAIInstruction: String? = nil

    /// The system prompt used for the last AI request (for reprompt)
    @Published var lastAISystemPrompt: String? = nil

    /// Whether an AI result is available for review
    var hasAIResult: Bool { aiResultText != nil }

    /// Whether the user is editing the reprompt instruction
    @Published var isReprompting: Bool = false

    /// Editable reprompt instruction text
    @Published var repromptInstruction: String = ""

    /// Whether the user is editing the source payload for resend
    @Published var isEditingPayload: Bool = false

    /// Editable copy of the source text for payload editing
    @Published var editablePayload: String = ""

    /// Selected model for overlay-level model picker
    @Published var selectedModel: String = ""

    /// Current overlay size
    @Published var overlaySize: OverlaySize = .standard {
        didSet {
            UserDefaults.standard.set(overlaySize.rawValue, forKey: "overlaySize")
            NotificationCenter.default.post(name: .symOverlaySizeDidChange, object: overlaySize)
        }
    }
    
    // MARK: - Dependencies
    
    private let speechManager: SpeechManager
    private let sessionStore: RecordingSessionStore
    private let feedbackManager: UserFeedbackManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        speechManager: SpeechManager,
        sessionStore: RecordingSessionStore,
        feedbackManager: UserFeedbackManager = .shared
    ) {
        self.speechManager = speechManager
        self.sessionStore = sessionStore
        self.feedbackManager = feedbackManager
        
        if let savedSizeStr = UserDefaults.standard.string(forKey: "overlaySize"),
           let savedSize = OverlaySize(rawValue: savedSizeStr) {
            self.overlaySize = savedSize
        }
        
        setupBindings()
        
        self.speechManager.onError = { [weak self] error in
            self?.handleSpeechError(error)
        }
    }
    
    // MARK: - Private Methods
    
    private func handleSpeechError(_ error: SpeechError) {
        currentMode = .error
        aiErrorMessage = error.localizedDescription
        feedbackManager.handleError(AppError.speech(error))
        
        // Return to idle after a few seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            if self?.currentMode == .error {
                self?.currentMode = .idle
                self?.updateStatusMessage()
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Set overlay mode based on entry point
    func setMode(_ mode: OverlayMode) {
        currentMode = mode
        updateStatusMessage()
    }
    
    /// Set output action based on user preference
    func setOutputAction(_ action: OutputAction) {
        outputAction = action
    }
    
    /// Start recording with current configuration
    func startRecording() {
        if sessionStore.currentSession == nil {
            _ = sessionStore.createNewSession()
            feedbackManager.showNewSession()
        }
        
        speechManager.transcribedText = sessionStore.currentSession?.text ?? ""
        
        do {
            try speechManager.startListening()
            feedbackManager.showRecordingStarted()
            isRecording = true
            isPaused = false
            updateStatusMessage()
        } catch let error as SpeechError {
            handleSpeechError(error)
        } catch {
            handleSpeechError(.recognitionFailed(underlying: error))
        }
    }
    
    /// Stop recording
    func stopRecording() {
        speechManager.stopListening()
        sessionStore.markCurrentCompleted()
        sessionStore.saveSessions()
        feedbackManager.showRecordingStopped()
        isRecording = false
        isPaused = false
        updateStatusMessage()
    }
    
    /// Pause recording
    func pauseRecording() {
        speechManager.pauseListening()
        feedbackManager.showRecordingPaused()
        isPaused = true
        isRecording = false
        updateStatusMessage()
    }
    
    /// Resume recording
    func resumeRecording() {
        do {
            try speechManager.resumeListening()
            feedbackManager.showRecordingResumed()
            isPaused = false
            isRecording = true
            updateStatusMessage()
        } catch {
            // Error handled via callback
        }
    }
    
    /// Clear text but keep recording
    func clearText() {
        speechManager.clearAndContinue()
        feedbackManager.showInfo("Text cleared")
    }
    
    /// Delete all text
    func deleteAll() {
        speechManager.resetTranscription()
        feedbackManager.showWarning("All text deleted")
    }
    
    /// Process text with AI — stores result in AI tab instead of overwriting
    func processTextWithAI(
        instruction: String,
        systemPrompt: String? = nil,
        ollamaManager: OllamaManager?,
        settingsViewModel: SettingsViewModel?,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let manager = ollamaManager else {
            let error = AppError.ai(OllamaError.notRunning)
            aiErrorMessage = error.localizedDescription
            feedbackManager.handleError(error)
            completion(.failure(error))
            return
        }

        let sourceText = isEditingPayload ? editablePayload : speechManager.transcribedText
        guard !sourceText.isEmpty else {
            let error = AppError.validation("No text to process.")
            feedbackManager.handleError(error)
            completion(.failure(error))
            return
        }

        isProcessingAI = true
        currentMode = .processingAI

        // Preserve original text before AI processing
        if aiOriginalText == nil {
            aiOriginalText = speechManager.transcribedText
        }
        lastAIInstruction = instruction
        lastAISystemPrompt = systemPrompt
        isReprompting = false
        isEditingPayload = false

        // Use overlay-selected model if set, otherwise fall back to settings
        let modelToUse = selectedModel.isEmpty
            ? (settingsViewModel?.ollamaSelectedModel ?? manager.selectedModel)
            : selectedModel
        manager.selectedModel = modelToUse
        manager.baseURL = settingsViewModel?.ollamaBaseURL ?? manager.baseURL

        manager.processText(sourceText, instruction: instruction, systemPrompt: systemPrompt) { result in
            self.isProcessingAI = false

            switch result {
            case .success(let processedText):
                self.aiResultText = processedText
                self.activeTab = .aiResult
                self.feedbackManager.showAIComplete(
                    action: instruction.components(separatedBy: " ").first?.capitalized ?? "Processing"
                )
                self.currentMode = .idle
                completion(.success(processedText))

            case .failure(let error):
                self.aiErrorMessage = error.localizedDescription
                self.feedbackManager.handleError(error)
                self.currentMode = .error
                completion(.failure(error))
            }
        }
    }

    /// Accept AI result — replaces original text with AI output
    func acceptAIResult() {
        guard let result = aiResultText else { return }
        speechManager.transcribedText = result
        clearAIState()
        feedbackManager.showSuccess("AI result accepted")
    }

    /// Decline AI result with a specific follow-up action
    func declineAIResult(action: DeclineAction, ollamaManager: OllamaManager?, settingsViewModel: SettingsViewModel?) {
        switch action {
        case .revert:
            // Restore original text and discard AI state
            if let original = aiOriginalText {
                speechManager.transcribedText = original
            }
            clearAIState()
            feedbackManager.showInfo("Reverted to original")

        case .reprompt:
            repromptInstruction = ""
            isReprompting = true
            isEditingPayload = false
            activeTab = .original

        case .refinePrompt:
            repromptInstruction = lastAIInstruction ?? ""
            isReprompting = true
            isEditingPayload = false
            activeTab = .original

        case .editPayload:
            editablePayload = aiOriginalText ?? speechManager.transcribedText
            isEditingPayload = true
            isReprompting = false
            activeTab = .original
        }
    }

    /// Process text using a built-in AI prompt style (with system prompt)
    func processWithStyle(
        _ style: AIPromptStyle,
        ollamaManager: OllamaManager?,
        settingsViewModel: SettingsViewModel?,
        completion: @escaping (Result<String, Error>) -> Void = { _ in }
    ) {
        // Use user-customized system prompt if available, otherwise use built-in default
        let effectiveSystemPrompt = settingsViewModel?.effectiveSystemPrompt(for: style) ?? style.systemPrompt
        processTextWithAI(
            instruction: style.instruction,
            systemPrompt: effectiveSystemPrompt,
            ollamaManager: ollamaManager,
            settingsViewModel: settingsViewModel,
            completion: completion
        )
    }

    /// Send the reprompt (new or refined instruction)
    func sendReprompt(ollamaManager: OllamaManager?, settingsViewModel: SettingsViewModel?) {
        let instruction = repromptInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instruction.isEmpty else { return }
        processTextWithAI(
            instruction: instruction,
            systemPrompt: lastAISystemPrompt,
            ollamaManager: ollamaManager,
            settingsViewModel: settingsViewModel
        ) { _ in }
    }

    /// Resend with edited payload
    func resendWithEditedPayload(ollamaManager: OllamaManager?, settingsViewModel: SettingsViewModel?) {
        guard let instruction = lastAIInstruction, !editablePayload.isEmpty else { return }
        processTextWithAI(
            instruction: instruction,
            systemPrompt: lastAISystemPrompt,
            ollamaManager: ollamaManager,
            settingsViewModel: settingsViewModel
        ) { _ in }
    }

    /// Clear all AI review state
    func clearAIState() {
        aiOriginalText = nil
        aiResultText = nil
        lastAIInstruction = nil
        lastAISystemPrompt = nil
        activeTab = .original
        isReprompting = false
        isEditingPayload = false
        repromptInstruction = ""
        editablePayload = ""
    }
    
    /// Copy text to clipboard
    func copyToClipboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(speechManager.transcribedText, forType: .string)
        feedbackManager.showCopied()
    }
    
    /// Create new session
    func newSession() {
        _ = sessionStore.createNewSession()
        speechManager.transcribedText = ""
        feedbackManager.showNewSession()
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Sync recording state
        speechManager.$isListening
            .sink { [weak self] isListening in
                self?.isRecording = isListening
                self?.updateStatusMessage()
            }
            .store(in: &cancellables)
        
        // Sync paused state
        speechManager.$isPaused
            .sink { [weak self] isPaused in
                self?.isPaused = isPaused
                self?.updateStatusMessage()
            }
            .store(in: &cancellables)
        
        // Sync text presence
        speechManager.$transcribedText
            .sink { [weak self] text in
                self?.hasText = !text.isEmpty
            }
            .store(in: &cancellables)
        
        // Update status message on state changes
        updateStatusMessage()
    }
    
    private func updateStatusMessage() {
        switch currentMode {
        case .idle:
            statusMessage = isRecording ? "Recording…" : "Ready"
        case .overlayDictation:
            statusMessage = isRecording ? "Recording to overlay…" : "Overlay ready"
        case .instantDictation:
            statusMessage = isRecording ? "Instant recording…" : "Instant ready"
        case .edgeCapture:
            statusMessage = isRecording ? "Edge recording…" : "Edge ready"
        case .processingAI:
            statusMessage = "Processing AI…"
        case .error:
            statusMessage = aiErrorMessage ?? "Error"
        }
    }
}
