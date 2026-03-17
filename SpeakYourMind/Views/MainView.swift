import SwiftUI
import AppKit
import Combine

/// Main view shown inside the OverlayPanel.
/// Provides live transcription display, record/stop/reset controls, text editor toggle, and AI processing.
struct MainView: View {
    @StateObject var speechManager = SpeechManager()
    @State private var showEditor = false
    @State private var showPermissionAlert = false
    @State private var permissionAlertMessage = ""

    // MARK: - Ollama / AI

    /// Shared OllamaManager passed in from AppDelegate.
    var ollamaManager: OllamaManager?

    /// SettingsViewModel used to check whether Ollama is enabled.
    var settingsViewModel: SettingsViewModel?

    @State private var isProcessingAI = false
    @State private var aiErrorMessage: String? = nil
    @State private var showAIError = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            // ── Status bar ──────────────────────────────────────
            HStack {
                Circle()
                    .fill(speechManager.isListening ? Color.red : Color.gray.opacity(0.4))
                    .frame(width: 10, height: 10)
                    .scaleEffect(speechManager.isListening ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                               value: speechManager.isListening)

                Text(speechManager.isListening ? "Listening…" : "Ready")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()

                // Close overlay
                Button { NSApp.keyWindow?.orderOut(nil) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            Divider()

            // ── Live transcription ──────────────────────────────
            ZStack {
                if showEditor {
                    TextEditor(text: $speechManager.transcribedText)
                        .font(.system(size: 14))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            Text(speechManager.transcribedText.isEmpty
                                 ? "Press record or use your hotkey to start…"
                                 : speechManager.transcribedText)
                                .font(.system(size: 14))
                                .foregroundColor(
                                    speechManager.transcribedText.isEmpty
                                    ? .secondary : .primary
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .id("bottom")
                        }
                        .onChange(of: speechManager.transcribedText) { _ in
                            withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                        }
                    }
                }

                // Loading overlay during AI processing
                if isProcessingAI {
                    ZStack {
                        Color.black.opacity(0.35)
                            .cornerRadius(8)
                        VStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.9)
                            Text("Processing…")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                        }
                    }
                }
            }

            Divider()

            // ── Controls ────────────────────────────────────────
            HStack(spacing: 20) {

                // Record / Stop
                Button {
                    if speechManager.isListening {
                        speechManager.stopListening()
                    } else {
                        do {
                            try speechManager.startListening()
                        } catch {
                            // Error is handled via onError callback
                        }
                    }
                } label: {
                    Image(systemName: speechManager.isListening
                          ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(speechManager.isListening ? .red : .accentColor)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("r", modifiers: .command)
                .help("Record / Stop  ⌘R\nOpen Overlay: ⌃⌥⌘ Space\nInstant Dictation: ⌃⌥⌘ (hold and release)")

                // Reset (clear text, keep recording)
                Button {
                    speechManager.clearAndContinue()
                } label: {
                    Image(systemName: "arrow.counterclockwise.circle")
                        .font(.system(size: 22))
                }
                .buttonStyle(.plain)
                .help("Reset text, keep recording")

                // Delete all
                Button {
                    speechManager.resetTranscription()
                } label: {
                    Image(systemName: "trash.circle")
                        .font(.system(size: 22))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.delete, modifiers: .command)
                .help("Delete all  ⌘⌫")

                Spacer()

                // AI menu (shown when Ollama is enabled and we have text)
                if settingsViewModel?.ollamaEnabled == true {
                    Menu {
                        Button("Correct Spelling") {
                            triggerOllamaProcessing(instruction: "Correct the spelling and grammar of the following text")
                        }
                        Button("Summarize") {
                            triggerOllamaProcessing(instruction: "Summarize the following text concisely")
                        }
                        Button("Generate Prompt") {
                            triggerOllamaProcessing(instruction: "Rewrite the following as a clear, detailed AI prompt")
                        }
                    } label: {
                        ZStack {
                            Image(systemName: "sparkles")
                                .font(.system(size: 20))
                                .foregroundColor(isProcessingAI ? .secondary : .accentColor)
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 28, height: 28)
                    .disabled(speechManager.transcribedText.isEmpty || isProcessingAI)
                    .help("AI Processing")
                }

                // Text editor toggle
                Button {
                    showEditor.toggle()
                } label: {
                    Image(systemName: showEditor
                          ? "doc.plaintext.fill" : "doc.plaintext")
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
                .keyboardShortcut("e", modifiers: .command)
                .help("Toggle editor  ⌘E")

                // Copy to clipboard
                Button {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(speechManager.transcribedText, forType: .string)
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
                .disabled(speechManager.transcribedText.isEmpty)
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .help("Copy to clipboard  ⇧⌘C")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 400, height: 300)
        .onReceive(
            NotificationCenter.default.publisher(for: .instantDictationDidActivateOverlay)
        ) { _ in
            // When instant dictation (overlay mode) activates, auto-start recording
            // in the overlay's own speech manager if not already listening.
            print("[MainView] Received instantDictationDidActivateOverlay notification, speechManager.isListening=\(speechManager.isListening)")
            guard !speechManager.isListening else {
                print("[MainView] Already listening — skipping startListening()")
                return
            }
            print("[MainView] Calling speechManager.startListening()")
            do {
                try speechManager.startListening()
                print("[MainView] speechManager.startListening() succeeded")
            } catch {
                print("[MainView] speechManager.startListening() threw error: \(error)")
                // Error surfaces via speechManager.lastError → handleSpeechError
            }
        }
        .onChange(of: speechManager.lastError) { newError in
            guard let error = newError else { return }
            handleSpeechError(error)
            speechManager.lastError = nil
        }
        .alert("Permission Required", isPresented: $showPermissionAlert) {
            Button("Open System Settings") {
                openSystemSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(permissionAlertMessage)
        }
        .alert("AI Error", isPresented: $showAIError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(aiErrorMessage ?? "An unknown error occurred.")
        }
    }

    // MARK: - AI Processing

    private func triggerOllamaProcessing(instruction: String) {
        guard let manager = ollamaManager else {
            aiErrorMessage = "Ollama is not configured. Please check Settings."
            showAIError = true
            return
        }

        let text = speechManager.transcribedText
        guard !text.isEmpty else { return }

        isProcessingAI = true

        manager.selectedModel = settingsViewModel?.ollamaSelectedModel ?? manager.selectedModel
        manager.baseURL = settingsViewModel?.ollamaBaseURL ?? manager.baseURL

        manager.processText(text, instruction: instruction) { result in
            // Completion already dispatched to main thread by OllamaManager
            isProcessingAI = false
            switch result {
            case .success(let processedText):
                speechManager.transcribedText = processedText
            case .failure(let error):
                aiErrorMessage = error.localizedDescription
                showAIError = true
            }
        }
    }

    // MARK: - Speech Error Handling

    private func handleSpeechError(_ error: SpeechError) {
        switch error {
        case .microphoneUnavailable, .microphoneDenied, .microphoneRestricted:
            permissionAlertMessage = error.errorDescription ?? "Microphone access is required. Please enable it in System Settings."
            showPermissionAlert = true
            UserFeedbackManager.shared.showError(permissionAlertMessage)
        case .speechRecognitionDenied, .speechRecognitionRestricted:
            permissionAlertMessage = error.errorDescription ?? "Speech recognition permission is required. Please enable it in System Settings."
            showPermissionAlert = true
            UserFeedbackManager.shared.showError(permissionAlertMessage)
        case .notAvailable(let reason):
            permissionAlertMessage = error.errorDescription ?? "Speech recognition is not available: \(reason)"
            showPermissionAlert = true
            UserFeedbackManager.shared.showError(permissionAlertMessage)
        case .recognitionFailed, .audioEngineFailed:
            let message = error.errorDescription ?? "An error occurred during speech recognition."
            UserFeedbackManager.shared.showError(message)
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}
