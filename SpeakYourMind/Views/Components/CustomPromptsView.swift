import SwiftUI

struct CustomPromptsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    @State private var showingEditSheet = false
    @State private var showingAddSheet = false
    @State private var newPromptName = ""
    @State private var newPromptInstruction = ""
    @State private var newPromptSystemPrompt = ""

    // Built-in style editing
    @State private var showingStyleSheet = false
    @State private var editingStyle: AIPromptStyle = .fixTranscription
    @State private var editingStyleSystemPrompt = ""
    
    // Edit sheet state
    @State private var editingPromptId: String?
    @State private var editingPromptName = ""
    @State private var editingPromptInstruction = ""
    @State private var editingPromptSystemPrompt = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // MARK: - Built-in AI Styles
            builtinStylesSection

            Divider()

            // MARK: - Custom Prompts
            customPromptsSection
        }
        .sheet(isPresented: $showingAddSheet) {
            addPromptSheet
        }
        .sheet(isPresented: $showingEditSheet) {
            editPromptSheet
        }
        .sheet(isPresented: $showingStyleSheet) {
            editBuiltinStyleSheet(style: editingStyle)
        }
    }

    // MARK: - Built-in Styles Section

    private var builtinStylesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Built-in AI Styles")
                .font(.headline)

            Text("Each style has a pre-written system prompt that shapes the AI's behavior. You can customize them.")
                .font(.caption)
                .foregroundColor(.secondary)

            builtinStyleRow(.fixTranscription)
            builtinStyleRow(.summarizeIdea)
            builtinStyleRow(.codingPrompt)
        }
    }

    private func builtinStyleRow(_ style: AIPromptStyle) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: style.icon)
                .foregroundColor(DS.Colors.aiAccent)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(style.rawValue)
                        .font(.subheadline.weight(.medium))
                    if viewModel.hasOverride(for: style) {
                        Text("Customized")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(DS.Colors.aiAccent)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(DS.Colors.aiAccent.opacity(0.15))
                            .cornerRadius(DS.Radius.sm)
                    }
                }
                Text(style.instruction)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                editingStyleSystemPrompt = viewModel.effectiveSystemPrompt(for: style)
                editingStyle = style
                showingStyleSheet = true
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(.borderless)
            .help("Edit system prompt")
        }
        .padding(.vertical, 4)
    }

    // MARK: - Custom Prompts Section

    private var customPromptsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text("Custom Prompts")
                    .font(.headline)
                Spacer()
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Add custom prompt")
            }

            if viewModel.customPrompts.isEmpty {
                Text("No custom prompts yet. Add one to appear in the AI menu.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, DS.Spacing.sm)
            } else {
                ForEach(viewModel.customPrompts) { prompt in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(prompt.name)
                                    .font(.subheadline)
                                if prompt.hasSystemPrompt {
                                    Image(systemName: "brain")
                                        .font(.system(size: 9))
                                        .foregroundColor(DS.Colors.aiAccent)
                                        .help("Has system prompt")
                                }
                            }
                            Text(prompt.instruction)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button(action: { 
                            editingPromptId = prompt.id.uuidString
                            editingPromptName = prompt.name
                            editingPromptInstruction = prompt.instruction
                            editingPromptSystemPrompt = prompt.systemPrompt
                            showingEditSheet = true
                        }) {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                        .help("Edit prompt")
                        Button(action: { viewModel.deleteCustomPrompt(prompt.id) }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                        .help("Delete prompt")
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Add Prompt Sheet

    private var addPromptSheet: some View {
        VStack(spacing: DS.Spacing.md) {
            Text("Add Custom Prompt")
                .font(.headline)

            TextField("Name (e.g., Make Professional)", text: $newPromptName)
                .textFieldStyle(.roundedBorder)

            TextField("Instruction (e.g., Rewrite this text in a professional tone)", text: $newPromptInstruction)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("System Prompt")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                    Text("(optional)")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                Text("Sets the AI's role and behavior. Leave blank for a simple instruction-only prompt.")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
                TextEditor(text: $newPromptSystemPrompt)
                    .font(.system(.caption, design: .monospaced))
                    .frame(height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }

            HStack {
                Button("Cancel") {
                    showingAddSheet = false
                    clearNewPromptFields()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    saveNewPrompt()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newPromptName.isEmpty || newPromptInstruction.isEmpty)
            }
        }
        .padding()
        .frame(width: 420)
    }

    // MARK: - Edit Prompt Sheet

    private var editPromptSheet: some View {
        VStack(spacing: DS.Spacing.md) {
            Text("Edit Custom Prompt")
                .font(.headline)

            TextField("Name", text: $editingPromptName)
            .textFieldStyle(.roundedBorder)

            TextField("Instruction", text: $editingPromptInstruction)
            .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("System Prompt")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                    Text("(optional)")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                TextEditor(text: $editingPromptSystemPrompt)
                .font(.system(.caption, design: .monospaced))
                .frame(height: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            }

            HStack {
                Button("Cancel") {
                    showingEditSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    saveEditedPrompt()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(editingPromptName.isEmpty || editingPromptInstruction.isEmpty)
            }
        }
        .padding()
        .frame(width: 420)
    }

    // MARK: - Edit Built-in Style Sheet

    private func editBuiltinStyleSheet(style: AIPromptStyle) -> some View {
        VStack(spacing: DS.Spacing.md) {
            HStack {
                Image(systemName: style.icon)
                    .foregroundColor(DS.Colors.aiAccent)
                Text("Edit System Prompt — \(style.rawValue)")
                    .font(.headline)
            }

            Text("Instruction: \(style.instruction)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text("System Prompt")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                Text("Defines the AI's persona and rules. This is sent as the system message.")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
                TextEditor(text: $editingStyleSystemPrompt)
                    .font(.system(.caption, design: .monospaced))
                    .frame(height: 180)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }

            HStack {
                Button("Cancel") {
                    showingStyleSheet = false
                }
                .keyboardShortcut(.cancelAction)

                if viewModel.hasOverride(for: style) {
                    Button("Reset to Default") {
                        viewModel.resetBuiltinStyleToDefault(style)
                        editingStyleSystemPrompt = style.systemPrompt
                    }
                }

                Spacer()

                Button("Save") {
                    viewModel.setBuiltinStyleOverride(style, systemPrompt: editingStyleSystemPrompt)
                    showingStyleSheet = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 480, height: 380)
    }

    // MARK: - Actions

    private func saveNewPrompt() {
        guard !newPromptName.isEmpty, !newPromptInstruction.isEmpty else { return }
        let prompt = CustomPrompt(
            name: newPromptName,
            instruction: newPromptInstruction,
            systemPrompt: newPromptSystemPrompt
        )
        viewModel.addCustomPrompt(prompt)
        showingAddSheet = false
        clearNewPromptFields()
    }

    private func saveEditedPrompt() {
        guard let id = editingPromptId else { return }
        viewModel.editCustomPrompt(
            UUID(uuidString: id) ?? UUID(),
            newName: editingPromptName,
            newInstruction: editingPromptInstruction,
            newSystemPrompt: editingPromptSystemPrompt
        )
        showingEditSheet = false
        editingPromptId = nil
    }

    private func clearNewPromptFields() {
        newPromptName = ""
        newPromptInstruction = ""
        newPromptSystemPrompt = ""
    }
}
