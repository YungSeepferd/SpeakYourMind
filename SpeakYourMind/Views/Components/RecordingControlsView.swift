import SwiftUI

/// Recording control buttons: record, pause, reset, delete.
/// Uses design system icon sizes and spacing.
struct RecordingControlsView: View {
    @ObservedObject var speechManager: SpeechManager
    @ObservedObject var sessionStore: RecordingSessionStore
    @ObservedObject var feedbackManager: UserFeedbackManager

    let onRecord: () -> Void
    let onPause: () -> Void
    let onClear: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Record / Stop — primary action
            Button { onRecord() } label: {
                Image(systemName: speechManager.isListening
                      ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: DS.IconSize.primary))
                    .foregroundColor(speechManager.isListening ? .red : .accentColor)
            }
            .buttonStyle(.plain)
            .dsHoverEffect()
            .keyboardShortcut("r", modifiers: .command)
            .help(speechManager.isListening ? "Stop (⌘R)" : "Record (⌘R)")

            // Pause / Resume
            Button { onPause() } label: {
                Image(systemName: speechManager.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: DS.IconSize.md))
                    .foregroundColor(.orange)
            }
            .buttonStyle(.plain)
            .dsHoverEffect()
            .keyboardShortcut("p", modifiers: .command)
            .disabled(!speechManager.isListening && !speechManager.isPaused)
            .help(speechManager.isPaused ? "Resume (⌘P)" : "Pause (⌘P)")

            // Clear
            Button { onClear() } label: {
                Image(systemName: "arrow.counterclockwise.circle")
                    .font(.system(size: DS.IconSize.md))
                    .foregroundColor(DS.Colors.textSecondary)
            }
            .buttonStyle(.plain)
            .dsHoverEffect()
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .help("Clear (⇧⌘R)")

            // Delete
            Button { onDelete() } label: {
                Image(systemName: "trash.circle")
                    .font(.system(size: DS.IconSize.md))
                    .foregroundColor(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
            .dsHoverEffect()
            .keyboardShortcut(.delete, modifiers: .command)
            .help("Delete (⌘⌫)")
        }
    }
}
