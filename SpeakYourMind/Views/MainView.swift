import SwiftUI
import AppKit
import Combine

struct MainView: View {
    @ObservedObject var speechManager: SpeechManager
    @ObservedObject var sessionStore: RecordingSessionStore
    @ObservedObject var viewModel: OverlayViewModel
    @StateObject var feedbackManager = UserFeedbackManager.shared
    @State private var showEditor = false
    @State private var showPermissionAlert = false
    @State private var permissionAlertMessage = ""

    var ollamaManager: OllamaManager?
    var settingsViewModel: SettingsViewModel?

    @State private var showAIError = false

    var body: some View {
        VStack(spacing: 0) {
            OverlayHeaderView(
                speechManager: speechManager,
                sessionStore: sessionStore,
                feedbackManager: feedbackManager,
                overlaySize: $viewModel.overlaySize,
                currentMode: viewModel.currentMode,
                onClose: { NSApp.keyWindow?.orderOut(nil) },
                onNewSession: newSession
            )

            if viewModel.overlaySize != .compact {
                Divider()
                SessionRailView(
                    sessionStore: sessionStore,
                    speechManager: speechManager,
                    feedbackManager: feedbackManager
                )
            }

            Divider()

            // Transcript area
            ZStack {
                TranscriptSurfaceView(
                    text: $speechManager.transcribedText,
                    isEditorMode: $showEditor,
                    viewModel: viewModel,
                    ollamaManager: ollamaManager,
                    settingsViewModel: settingsViewModel,
                    placeholder: viewModel.overlaySize == .compact
                        ? "Ready…"
                        : "Press record or use your hotkey to start…",
                    isEmpty: speechManager.transcribedText.isEmpty
                )

                if viewModel.isProcessingAI {
                    processingOverlay
                }
            }

            Divider()

            // Bottom toolbar
            bottomToolbar

            // Expanded AI panel
            if viewModel.overlaySize == .expanded {
                Divider()
                ExpandedAIView(
                    viewModel: viewModel,
                    ollamaManager: ollamaManager,
                    settingsViewModel: settingsViewModel,
                    transcribedText: $speechManager.transcribedText,
                    isProcessing: $viewModel.isProcessingAI,
                    onSend: triggerExplicitOllamaProcessing
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(ToastContainerView(content: EmptyView(), feedbackManager: feedbackManager))
        .onReceive(NotificationCenter.default.publisher(for: .instantDictationDidActivateOverlay)) { _ in
            guard !speechManager.isListening else { return }
            if sessionStore.currentSession == nil {
                _ = sessionStore.createNewSession()
            }
            speechManager.transcribedText = sessionStore.currentSession?.text ?? ""
            try? speechManager.startListening()
        }
        .onChange(of: speechManager.transcribedText) { newText in
            sessionStore.updateCurrentText(newText)
            sessionStore.saveSessions()
        }
        .onChange(of: speechManager.lastError) { newError in
            guard let error = newError else { return }
            handleSpeechError(error)
            speechManager.lastError = nil
        }
        .alert("Permission Required", isPresented: $showPermissionAlert) {
            Button("Open System Settings") { openSystemSettings() }
            Button("Cancel", role: .cancel) { }
        } message: { Text(permissionAlertMessage) }
        .alert("AI Error", isPresented: $showAIError) {
            Button("OK", role: .cancel) { }
        } message: { Text(viewModel.aiErrorMessage ?? "An unknown error occurred.") }
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: DS.Spacing.lg) {
            RecordingControlsView(
                speechManager: speechManager,
                sessionStore: sessionStore,
                feedbackManager: feedbackManager,
                onRecord: handleRecord,
                onPause: handlePause,
                onClear: { speechManager.clearAndContinue() },
                onDelete: { speechManager.resetTranscription() }
            )

            if viewModel.overlaySize != .compact {
                Spacer()

                AIControlsView(
                    speechManager: speechManager,
                    ollamaManager: ollamaManager,
                    settingsViewModel: settingsViewModel,
                    viewModel: viewModel,
                    isProcessingAI: $viewModel.isProcessingAI,
                    aiErrorMessage: $viewModel.aiErrorMessage,
                    showAIError: $showAIError,
                    feedbackManager: feedbackManager,
                    onProcessText: triggerOllamaProcessing
                )

                // Editor toggle
                Button { showEditor.toggle() } label: {
                    Image(systemName: showEditor ? "doc.plaintext.fill" : "doc.plaintext")
                        .font(.system(size: DS.IconSize.action))
                        .foregroundColor(showEditor ? DS.Colors.accent : DS.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .dsHoverEffect()
                .keyboardShortcut("e", modifiers: .command)
                .help("Toggle editor  ⌘E")

                // Copy
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(speechManager.transcribedText, forType: .string)
                    feedbackManager.showCopied()
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: DS.IconSize.action))
                        .foregroundColor(DS.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .dsHoverEffect()
                .disabled(speechManager.transcribedText.isEmpty)
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .help("Copy  ⇧⌘C")

                // Export
                Button {
                    exportCurrentSession(format: .txt)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: DS.IconSize.action))
                        .foregroundColor(DS.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .dsHoverEffect()
                .disabled(sessionStore.currentSession == nil)
                .keyboardShortcut("s", modifiers: .command)
                .help("Export  ⌘S")
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
    }

    // MARK: - Actions

    private func handleRecord() {
        if speechManager.isListening {
            speechManager.stopListening()
            sessionStore.markCurrentCompleted()
            sessionStore.saveSessions()
            if settingsViewModel?.autoCopyOnStop == true {
                let text = speechManager.transcribedText
                if !text.isEmpty {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    feedbackManager.showCopied()
                } else {
                    feedbackManager.showRecordingStopped()
                }
            } else {
                feedbackManager.showRecordingStopped()
            }
        } else {
            if sessionStore.currentSession == nil {
                _ = sessionStore.createNewSession()
                feedbackManager.showNewSession()
            }
            speechManager.transcribedText = sessionStore.currentSession?.text ?? ""
            try? speechManager.startListening()
            feedbackManager.showRecordingStarted()
        }
    }

    private func handlePause() {
        if speechManager.isListening {
            speechManager.pauseListening()
            feedbackManager.showRecordingPaused()
        } else if speechManager.isPaused {
            try? speechManager.resumeListening()
            feedbackManager.showRecordingResumed()
        }
    }

    private func triggerOllamaProcessing(instruction: String) {
        viewModel.processTextWithAI(
            instruction: instruction,
            ollamaManager: ollamaManager,
            settingsViewModel: settingsViewModel
        ) { _ in }
    }

    private func triggerExplicitOllamaProcessing(_ prompt: String) {
        let instruction = "\(prompt):\n\n\"\(speechManager.transcribedText)\""
        viewModel.processTextWithAI(
            instruction: instruction,
            ollamaManager: ollamaManager,
            settingsViewModel: settingsViewModel
        ) { _ in }
    }

    private func handleSpeechError(_ error: SpeechError) {
        switch error {
        case .microphoneUnavailable, .microphoneDenied, .microphoneRestricted:
            permissionAlertMessage = error.errorDescription ?? "Microphone access required."
            showPermissionAlert = true
            UserFeedbackManager.shared.showError(permissionAlertMessage)
        case .speechRecognitionDenied, .speechRecognitionRestricted:
            permissionAlertMessage = error.errorDescription ?? "Speech recognition permission required."
            showPermissionAlert = true
            UserFeedbackManager.shared.showError(permissionAlertMessage)
        case .notAvailable(let reason):
            permissionAlertMessage = error.errorDescription ?? "Speech recognition not available: \(reason)"
            showPermissionAlert = true
            UserFeedbackManager.shared.showError(permissionAlertMessage)
        case .recognitionFailed, .audioEngineFailed:
            UserFeedbackManager.shared.showError(error.errorDescription ?? "Speech recognition error.")
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    private func newSession() {
        _ = sessionStore.createNewSession()
        speechManager.transcribedText = ""
        feedbackManager.showNewSession()
    }

    private func exportCurrentSession(format: ExportFormat) {
        guard let session = sessionStore.currentSession else {
            feedbackManager.showWarning("No session selected")
            return
        }
        if let url = SessionExporter.shared.exportAndSave(session: session, format: format) {
            feedbackManager.showSuccess("Exported to \(url.lastPathComponent)")
        }
    }

    // MARK: - Processing Overlay

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
            VStack(spacing: DS.Spacing.md) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.2)
                Text("Processing with AI…")
                    .font(DS.Typography.subheadline.weight(.medium))
                    .foregroundColor(.white)
            }
            .padding(DS.Spacing.xxl)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl)
                    .fill(Color.primary.opacity(0.2))
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
