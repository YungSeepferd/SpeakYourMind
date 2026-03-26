import SwiftUI

/// AI processing controls — status dot, sparkles menu, model picker.
struct AIControlsView: View {
    @ObservedObject var speechManager: SpeechManager
    var ollamaManager: OllamaManager?
    var settingsViewModel: SettingsViewModel?
    @ObservedObject var viewModel: OverlayViewModel
    @Binding var isProcessingAI: Bool
    @Binding var aiErrorMessage: String?
    @Binding var showAIError: Bool
    @ObservedObject var feedbackManager: UserFeedbackManager

    let onProcessText: (String) -> Void

    var ollamaEnabled: Bool {
        settingsViewModel?.ollamaEnabled == true
    }

    var ollamaAvailable: Bool {
        ollamaEnabled && (ollamaManager?.isServerReachable ?? false)
    }

    var body: some View {
        Group {
            if ollamaEnabled {
                HStack(spacing: DS.Spacing.sm) {
                    // Ollama status dot
                    Circle()
                        .fill(ollamaAvailable ? DS.Colors.success : DS.Colors.warning)
                        .frame(width: 6, height: 6)
                        .help(settingsViewModel?.ollamaStatus ?? "Ollama status unknown")

                    // Model picker (compact in standard, full in expanded)
                    if let manager = ollamaManager {
                        ModelPickerView(
                            ollamaManager: manager,
                            viewModel: viewModel,
                            compact: viewModel.overlaySize == .standard
                        )
                    }

                    // AI menu
                    Menu {
                        // Built-in styles with sophisticated system prompts
                        ForEach(AIPromptStyle.allCases) { style in
                            Button {
                                viewModel.processWithStyle(
                                    style,
                                    ollamaManager: ollamaManager,
                                    settingsViewModel: settingsViewModel
                                )
                            } label: {
                                Label(style.rawValue, systemImage: style.icon)
                            }
                            .help(style.tooltip)
                        }

                        Divider()

                        // Generic transforms (no system prompt)
                        Button("Expand") {
                            onProcessText("Expand and elaborate on the following text")
                        }
                        Button("Simplify") {
                            onProcessText("Simplify the following text")
                        }
                        Button("Correct Spelling") {
                            onProcessText("Correct the spelling and grammar of the following text")
                        }

                        if let prompts = settingsViewModel?.customPrompts, !prompts.isEmpty {
                            Divider()
                            ForEach(prompts) { prompt in
                                Button(prompt.name) {
                                    if prompt.hasSystemPrompt {
                                        viewModel.processTextWithAI(
                                            instruction: prompt.instruction,
                                            systemPrompt: prompt.systemPrompt,
                                            ollamaManager: ollamaManager,
                                            settingsViewModel: settingsViewModel
                                        ) { _ in }
                                    } else {
                                        onProcessText(prompt.instruction)
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: DS.IconSize.md))
                            .foregroundColor(
                                isProcessingAI
                                    ? DS.Colors.textTertiary
                                    : DS.Colors.aiAccent
                            )
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .disabled(
                        speechManager.transcribedText.isEmpty
                        || isProcessingAI
                        || !ollamaAvailable
                    )
                    .help("AI Processing")
                }
            }
        }
    }
}
