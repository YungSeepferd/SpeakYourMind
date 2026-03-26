import SwiftUI

/// Inline model selector for the overlay — picks from available Ollama models.
struct ModelPickerView: View {
    @ObservedObject var ollamaManager: OllamaManager
    @ObservedObject var viewModel: OverlayViewModel
    var compact: Bool = false

    var body: some View {
        Menu {
            if ollamaManager.availableModels.isEmpty {
                Text("No models available")
                Button("Refresh models") {
                    ollamaManager.fetchAvailableModels(forceRefresh: true) { _ in }
                }
            } else {
                ForEach(ollamaManager.availableModels, id: \.self) { model in
                    Button {
                        viewModel.selectedModel = model
                        ollamaManager.selectedModel = model
                    } label: {
                        HStack {
                            Text(model)
                            if model == currentModel {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                Divider()

                Button("Refresh models") {
                    ollamaManager.fetchAvailableModels(forceRefresh: true) { _ in }
                }
            }
        } label: {
            HStack(spacing: DS.Spacing.xxs) {
                Image(systemName: "cpu")
                    .font(.system(size: compact ? DS.IconSize.inline : DS.IconSize.sm))
                Text(displayName)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8))
            }
            .font(compact ? DS.Typography.caption : DS.Typography.footnote)
            .foregroundColor(DS.Colors.textSecondary)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xxs)
            .background(DS.Colors.surfaceSecondary)
            .cornerRadius(DS.Radius.sm)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var currentModel: String {
        viewModel.selectedModel.isEmpty ? ollamaManager.selectedModel : viewModel.selectedModel
    }

    private var displayName: String {
        let model = currentModel
        if model.isEmpty { return "Select model" }
        // Truncate long model names like "llama3.1:70b-instruct-q4_0"
        let maxLen = compact ? 12 : 18
        if model.count > maxLen {
            return String(model.prefix(maxLen)) + "…"
        }
        return model
    }
}
