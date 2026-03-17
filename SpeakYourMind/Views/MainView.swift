import SwiftUI
import AppKit

/// Main view shown inside the OverlayPanel.
/// Provides live transcription display, record/stop/reset controls, and text editor toggle.
struct MainView: View {
    @StateObject var speechManager = SpeechManager()
    @State private var showEditor = false
    @State private var showPermissionAlert = false
    @State private var permissionAlertMessage = ""

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
    }
    
    // MARK: - Error Handling
    
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