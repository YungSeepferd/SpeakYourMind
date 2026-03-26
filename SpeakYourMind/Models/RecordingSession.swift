import Foundation

/// Represents a single recording session with its transcribed text.
struct RecordingSession: Identifiable, Codable, Equatable {
    let id: UUID
    let createdAt: Date
    var text: String
    var duration: TimeInterval
    var isCompleted: Bool
    var isPinned: Bool = false
    var customTitle: String?
    
    init(id: UUID = UUID(), createdAt: Date = Date(), text: String = "", duration: TimeInterval = 0, isCompleted: Bool = false, isPinned: Bool = false, customTitle: String? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.text = text
        self.duration = duration
        self.isCompleted = isCompleted
        self.isPinned = isPinned
        self.customTitle = customTitle
    }
    
    var pinIcon: String? {
        isPinned ? "📌" : nil
    }
    
    var displayTitle: String {
        if let title = customTitle, !title.isEmpty {
            return title
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let time = formatter.string(from: createdAt)
        let preview = text.prefix(30).trimmingCharacters(in: .whitespacesAndNewlines)
        return preview.isEmpty ? "Session \(time)" : "\(preview)..."
    }
    
    var wordCount: Int {
        text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
}
