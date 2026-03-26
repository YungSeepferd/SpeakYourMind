import Foundation

struct CustomPrompt: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var instruction: String
    var systemPrompt: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        instruction: String,
        systemPrompt: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.instruction = instruction
        self.systemPrompt = systemPrompt
        self.createdAt = createdAt
    }

    /// Whether this prompt has a custom system prompt defined.
    var hasSystemPrompt: Bool {
        !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
