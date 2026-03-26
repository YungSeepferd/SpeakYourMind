import SwiftUI

/// Expanded AI panel — model picker, instruction field, send button.
/// Only visible in `.expanded` overlay size.
struct ExpandedAIView: View {
    @ObservedObject var viewModel: OverlayViewModel
    var ollamaManager: OllamaManager?
    var settingsViewModel: SettingsViewModel?
    @Binding var transcribedText: String
    @Binding var isProcessing: Bool
    let onSend: (String) -> Void

    @State private var userPrompt: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Header row — label + model picker
            HStack {
                Label("AI Instruction", systemImage: "sparkles")
                    .font(DS.Typography.footnote.weight(.semibold))
                    .foregroundColor(DS.Colors.aiAccent)

                Spacer()

                if let manager = ollamaManager {
                    ModelPickerView(
                        ollamaManager: manager,
                        viewModel: viewModel,
                        compact: false
                    )
                }
            }

            // Instruction row
            HStack(spacing: DS.Spacing.sm) {
                TextField("What should the AI do with this text?", text: $userPrompt)
                    .textFieldStyle(.roundedBorder)
                    .font(DS.Typography.body)
                    .disabled(isProcessing || transcribedText.isEmpty)

                Button {
                    onSend(userPrompt)
                } label: {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.Colors.aiAccent)
                .disabled(isProcessing || transcribedText.isEmpty || userPrompt.isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
                .help("Send to AI  ⌘↵")
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.md)
        .background(DS.Colors.surfaceGrouped)
    }
}
