import SwiftUI

/// Scrollable transcript display with AI result tabs, accept/decline bar,
/// and inline reprompt/payload editing.
struct TranscriptSurfaceView: View {
    @Binding var text: String
    @Binding var isEditorMode: Bool
    @ObservedObject var viewModel: OverlayViewModel
    var ollamaManager: OllamaManager?
    var settingsViewModel: SettingsViewModel?
    let placeholder: String
    let isEmpty: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar — only shown when AI result is available
            if viewModel.hasAIResult {
                tabBar
            }

            // Content area
            ZStack {
                if viewModel.isReprompting {
                    repromptEditor
                } else if viewModel.isEditingPayload {
                    payloadEditor
                } else if viewModel.activeTab == .aiResult, let aiText = viewModel.aiResultText {
                    aiResultContent(aiText)
                } else if isEditorMode {
                    originalEditor
                } else {
                    originalReadOnly
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Accept/Decline bar — shown when reviewing AI result
            if viewModel.hasAIResult && !viewModel.isReprompting && !viewModel.isEditingPayload {
                acceptDeclineBar
            }
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: DS.Spacing.xxs) {
            ForEach(TranscriptTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(DS.Animation.quick) {
                        viewModel.activeTab = tab
                    }
                } label: {
                    HStack(spacing: DS.Spacing.xxs) {
                        if tab == .aiResult {
                            Image(systemName: "sparkles")
                                .font(.system(size: DS.IconSize.inline))
                                .foregroundColor(DS.Colors.aiAccent)
                        }
                        Text(tab.rawValue)
                    }
                    .dsSegmentedTab(isSelected: viewModel.activeTab == tab)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs)
        .background(DS.Colors.surfaceGrouped)
    }

    // MARK: - Content Variants

    private var originalEditor: some View {
        TextEditor(text: $text)
            .font(DS.Typography.body)
            .scrollContentBackground(.hidden)
            .padding(DS.Spacing.sm)
    }

    private var originalReadOnly: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(isEmpty ? placeholder : text)
                    .font(DS.Typography.body)
                    .foregroundColor(isEmpty ? DS.Colors.textTertiary : DS.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DS.Spacing.md)
                    .id("bottom")
            }
            .onChange(of: text) { _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    private func aiResultContent(_ aiText: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                // Instruction label
                if let instruction = viewModel.lastAIInstruction {
                    HStack(spacing: DS.Spacing.xxs) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: DS.IconSize.inline))
                        Text(instruction)
                            .lineLimit(1)
                    }
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.aiAccent)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(DS.Colors.aiSurface)
                    .cornerRadius(DS.Radius.sm)
                }

                Text(aiText)
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding(DS.Spacing.md)
        }
    }

    // MARK: - Reprompt Editor

    private var repromptEditor: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Label("New instruction", systemImage: "arrow.triangle.2.circlepath")
                .font(DS.Typography.footnote)
                .foregroundColor(DS.Colors.textSecondary)

            TextEditor(text: $viewModel.repromptInstruction)
                .font(DS.Typography.body)
                .scrollContentBackground(.hidden)
                .padding(DS.Spacing.sm)
                .background(DS.Colors.surfaceSecondary)
                .cornerRadius(DS.Radius.md)
                .frame(maxHeight: .infinity)

            HStack {
                Button("Cancel") {
                    viewModel.isReprompting = false
                }
                .buttonStyle(.plain)
                .foregroundColor(DS.Colors.textSecondary)

                Spacer()

                Button {
                    viewModel.sendReprompt(
                        ollamaManager: ollamaManager, settingsViewModel: settingsViewModel
                    )
                } label: {
                    Label("Send", systemImage: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.Colors.aiAccent)
                .disabled(viewModel.repromptInstruction.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(DS.Spacing.md)
    }

    // MARK: - Payload Editor

    private var payloadEditor: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Label("Edit source text", systemImage: "pencil.line")
                .font(DS.Typography.footnote)
                .foregroundColor(DS.Colors.textSecondary)

            TextEditor(text: $viewModel.editablePayload)
                .font(DS.Typography.body)
                .scrollContentBackground(.hidden)
                .padding(DS.Spacing.sm)
                .background(DS.Colors.surfaceSecondary)
                .cornerRadius(DS.Radius.md)
                .frame(maxHeight: .infinity)

            HStack {
                Button("Cancel") {
                    viewModel.isEditingPayload = false
                }
                .buttonStyle(.plain)
                .foregroundColor(DS.Colors.textSecondary)

                Spacer()

                Button {
                    viewModel.resendWithEditedPayload(
                        ollamaManager: ollamaManager, settingsViewModel: settingsViewModel
                    )
                } label: {
                    Label("Resend", systemImage: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.Colors.aiAccent)
                .disabled(viewModel.editablePayload.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(DS.Spacing.md)
    }

    // MARK: - Accept / Decline Bar

    private var acceptDeclineBar: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Accept
            Button {
                viewModel.acceptAIResult()
            } label: {
                Label("Accept", systemImage: "checkmark")
                    .font(DS.Typography.subheadline.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.Colors.success)

            // Decline dropdown
            Menu {
                Button {
                    viewModel.declineAIResult(
                        action: .reprompt, ollamaManager: ollamaManager, settingsViewModel: settingsViewModel
                    )
                } label: {
                    Label("Reprompt with new instruction", systemImage: "arrow.triangle.2.circlepath")
                }

                Button {
                    viewModel.declineAIResult(
                        action: .refinePrompt, ollamaManager: ollamaManager, settingsViewModel: settingsViewModel
                    )
                } label: {
                    Label("Refine original prompt", systemImage: "pencil")
                }

                Button {
                    viewModel.declineAIResult(
                        action: .editPayload, ollamaManager: ollamaManager, settingsViewModel: settingsViewModel
                    )
                } label: {
                    Label("Edit source text & resend", systemImage: "doc.text")
                }

                Divider()

                Button(role: .destructive) {
                    viewModel.declineAIResult(
                        action: .revert, ollamaManager: ollamaManager, settingsViewModel: settingsViewModel
                    )
                } label: {
                    Label("Revert to original", systemImage: "arrow.uturn.backward")
                }
            } label: {
                Label("Decline", systemImage: "chevron.down")
                    .font(DS.Typography.subheadline.weight(.medium))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            // Word count for current tab
            Text(wordCountLabel)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textTertiary)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.surfaceGrouped)
    }

    private var wordCountLabel: String {
        let currentText = viewModel.activeTab == .aiResult
            ? (viewModel.aiResultText ?? "")
            : text
        let count = currentText.split(separator: " ").count
        return "\(count) word\(count == 1 ? "" : "s")"
    }
}
