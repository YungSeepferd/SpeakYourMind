import SwiftUI

/// Header bar — status, language, size picker, close.
struct OverlayHeaderView: View {
    @ObservedObject var speechManager: SpeechManager
    @ObservedObject var sessionStore: RecordingSessionStore
    @ObservedObject var feedbackManager: UserFeedbackManager
    @Binding var overlaySize: OverlaySize
    let currentMode: OverlayMode
    let onClose: () -> Void
    let onNewSession: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Status indicator + label
            statusIndicator

            Spacer()

            // Language picker (always visible)
            LanguagePicker(
                speechManager: speechManager,
                compact: overlaySize == .compact
            )

            // Size picker — segmented style
            sizePicker

            // Close
            Button { onClose() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: DS.IconSize.md))
                    .foregroundColor(DS.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .dsHoverEffect()
            .keyboardShortcut(.escape)
            .help("Close overlay (Esc)")
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.top, DS.Spacing.md)
        .padding(.bottom, DS.Spacing.xs)
    }

    // MARK: - Subviews

    private var statusIndicator: some View {
        HStack(spacing: DS.Spacing.xs) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .scaleEffect(speechManager.isListening ? 1.3 : 1.0)
                .animation(
                    speechManager.isListening
                        ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                        : .default,
                    value: speechManager.isListening
                )

            Text(statusLabel)
                .font(DS.Typography.footnote.weight(.medium))
                .foregroundColor(DS.Colors.textSecondary)

            if !sessionStore.sessions.isEmpty {
                Text("\(sessionStore.sessions.count)")
                    .font(DS.Typography.caption2.weight(.semibold))
                    .foregroundColor(DS.Colors.textTertiary)
                    .padding(.horizontal, DS.Spacing.xxs + 2)
                    .padding(.vertical, 1)
                    .background(DS.Colors.surfaceSecondary)
                    .cornerRadius(DS.Radius.pill)
            }
        }
    }

    private var sizePicker: some View {
        HStack(spacing: 2) {
            ForEach(OverlaySize.allCases, id: \.self) { size in
                Button {
                    withAnimation(DS.Animation.quick) {
                        overlaySize = size
                    }
                } label: {
                    Text(size.label)
                        .dsSegmentedTab(isSelected: overlaySize == size)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        if speechManager.isListening { return .red }
        if speechManager.isPaused { return .orange }
        return Color.gray.opacity(0.4)
    }

    private var statusLabel: String {
        if speechManager.isListening { return "Listening…" }
        if speechManager.isPaused { return "Paused" }
        return "Ready"
    }
}

// MARK: - OverlaySize helpers

extension OverlaySize {
    var label: String {
        switch self {
        case .compact: return "S"
        case .standard: return "M"
        case .expanded: return "L"
        }
    }
}
