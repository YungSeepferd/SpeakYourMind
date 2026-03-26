import Foundation
import AppKit

enum ExportFormat: String, CaseIterable {
    case txt = "txt"
    case markdown = "md"

    var fileExtension: String { rawValue }

    var displayName: String {
        switch self {
        case .txt: return "Text Document"
        case .markdown: return "Markdown"
        }
    }
}

final class SessionExporter {

    static let shared = SessionExporter()

    private init() {}

    func exportSession(_ session: RecordingSession, format: ExportFormat) -> String {
        switch format {
        case .txt:
            return exportAsTxt(session)
        case .markdown:
            return exportAsMarkdown(session)
        }
    }

    func exportAndSave(session: RecordingSession, format: ExportFormat) -> URL? {
        let content = exportSession(session, format: format)

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = defaultFileName(for: session, format: format)
        savePanel.canCreateDirectories = true

        guard savePanel.runModal() == .OK, let url = savePanel.url else {
            return nil
        }

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            Logger.shared.error("Failed to save export: \(error)")
            return nil
        }
    }

    private func defaultFileName(for session: RecordingSession, format: ExportFormat) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let dateString = formatter.string(from: session.createdAt)
        return "Session_\(dateString).\(format.fileExtension)"
    }

    private func exportAsTxt(_ session: RecordingSession) -> String {
        var output = ""

        output += "=" .repeated(50) + "\n"
        output += "SESSION EXPORT\n"
        output += "=" .repeated(50) + "\n\n"

        output += formatMetadata(session)
        output += "\n"

        output += "-" .repeated(50) + "\n"
        output += "TRANSCRIPT\n"
        output += "-" .repeated(50) + "\n\n"
        output += session.text.isEmpty ? "[No transcript]" : session.text
        output += "\n"

        return output
    }

    private func exportAsMarkdown(_ session: RecordingSession) -> String {
        var output = ""

        output += "# Session Export\n\n"

        output += "## Metadata\n\n"
        output += "| Property | Value |\n"
        output += "|----------|-------|\n"
        output += "| Date | \(formatDate(session.createdAt)) |\n"
        output += "| Duration | \(formatDuration(session.duration)) |\n"
        output += "| Word Count | \(session.wordCount) |\n"
        output += "\n"

        output += "## Transcript\n\n"
        output += session.text.isEmpty ? "*No transcript*" : session.text
        output += "\n"

        return output
    }

    private func formatMetadata(_ session: RecordingSession) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        var metadata = ""
        metadata += "Date:    \(dateFormatter.string(from: session.createdAt))\n"
        metadata += "Duration: \(formatDuration(session.duration))\n"
        metadata += "Words:   \(session.wordCount)\n"
        return metadata
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        guard duration > 0 else { return "0:00" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private extension String {
    func repeated(_ count: Int) -> String {
        String(repeating: self, count: count)
    }
}