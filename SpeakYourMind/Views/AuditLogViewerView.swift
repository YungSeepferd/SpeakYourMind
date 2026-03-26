import SwiftUI

struct AuditLogViewerView: View {
    @StateObject private var viewModel = AuditLogViewerViewModel()
    @State private var selectedLevel: AuditLogLevel? = nil
    @State private var selectedCategory: AuditLogCategory? = nil
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbarView
            
            Divider()
            
            // Log entries
            if viewModel.entries.isEmpty {
                emptyStateView
            } else {
                logListView
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear {
            viewModel.loadLogs()
        }
    }
    
    // MARK: - Toolbar
    
    private var toolbarView: some View {
        HStack(spacing: DS.Spacing.md) {
            // Level filter
            Menu {
                Button("All Levels") { selectedLevel = nil }
                Divider()
                Button("🔍 Debug") { selectedLevel = .debug }
                Button("ℹ️ Info") { selectedLevel = .info }
                Button("⚠️ Warning") { selectedLevel = .warning }
                Button("❌ Error") { selectedLevel = .error }
                Button("💥 Fault") { selectedLevel = .fault }
            } label: {
                Label(selectedLevel?.rawValue.capitalized ?? "All Levels", systemImage: "line.3.horizontal.decrease.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            
            // Category filter
            Menu {
                Button("All Categories") { selectedCategory = nil }
                Divider()
                ForEach(AuditLogCategory.allCases, id: \.self) { category in
                    Button(categoryIcon(category) + " " + category.rawValue.capitalized) {
                        selectedCategory = category
                    }
                }
            } label: {
                Label(selectedCategory?.rawValue.capitalized ?? "All Categories", systemImage: "folder")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            
            Spacer()
            
            // Search
            TextField("Search logs...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
            
            // Actions
            Button(action: viewModel.loadLogs) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .help("Refresh logs")
            
            Button(action: viewModel.exportLogs) {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .help("Export logs")
            
            Button(action: viewModel.clearLogs) {
                Label("Clear", systemImage: "trash")
            }
            .help("Clear all logs")
            .foregroundColor(.red)
        }
        .padding(DS.Spacing.md)
    }
    
    // MARK: - Log List
    
    private var logListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(filteredLogs, id: \.timestamp) { entry in
                    LogEntryRow(entry: entry)
                }
            }
            .padding(.horizontal)
        }
        .background(Color(NSColor.textBackgroundColor))
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No audit logs found")
                .font(.headline)
            Text("Logs will appear here as you use the app")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Filtered Logs
    
    private var filteredLogs: [AuditLogEntry] {
        var logs = viewModel.entries
        
        if let level = selectedLevel {
            logs = logs.filter { $0.level == level }
        }
        
        if let category = selectedCategory {
            logs = logs.filter { $0.category == category }
        }
        
        if !searchText.isEmpty {
            logs = logs.filter {
                $0.message.localizedCaseInsensitiveContains(searchText) ||
                $0.eventType.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return logs
    }
    
    // MARK: - Helpers
    
    private func categoryIcon(_ category: AuditLogCategory) -> String {
        switch category {
        case .lifecycle: return "🔄"
        case .speech: return "🎤"
        case .ai: return "🤖"
        case .ui: return "🖼️"
        case .settings: return "⚙️"
        case .permissions: return "🔐"
        case .general: return "📋"
        }
    }
}

// MARK: - Log Entry Row

struct LogEntryRow: View {
    let entry: AuditLogEntry
    
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Timestamp
            Text(entry.timestamp, style: .time)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            // Level badge
            levelBadge
            
            // Category
            Text(entry.category.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80)
            
            // Event type
            Text(entry.eventType.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 120)
            
            // Message
            Text(entry.message)
                .font(.system(.caption, design: .default))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Metadata indicator
            if entry.metadata != nil {
                Image(systemName: "info.circle")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .help("Has metadata")
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(backgroundForLevel(entry.level).opacity(0.05))
        .cornerRadius(4)
    }
    
    private var levelBadge: some View {
        let (symbol, color) = levelSymbolAndColor(entry.level)
        return Image(systemName: symbol)
            .font(.system(size: 10))
            .foregroundColor(color)
            .frame(width: 16)
    }
    
    private func levelSymbolAndColor(_ level: AuditLogLevel) -> (String, Color) {
        switch level {
        case .debug: return ("magnifyingglass", .gray)
        case .info: return ("info.circle", .blue)
        case .warning: return ("exclamationmark.triangle", .orange)
        case .error: return ("xmark.circle", .red)
        case .fault: return ("exclamationmark.circle", .purple)
        }
    }
    
    private func backgroundForLevel(_ level: AuditLogLevel) -> Color {
        switch level {
        case .debug: return Color.gray
        case .info: return Color.blue
        case .warning: return Color.orange
        case .error: return Color.red
        case .fault: return Color.purple
        }
    }
}

// MARK: - View Model

@MainActor
class AuditLogViewerViewModel: ObservableObject {
    @Published var entries: [AuditLogEntry] = []
    
    func loadLogs() {
        Task {
            let logs = await AuditLogger.shared.getRecentLogs(limit: 500)
            self.entries = logs.reversed() // Show newest first
        }
    }
    
    func exportLogs() {
        Task {
            if let url = await AuditLogger.shared.exportLogs() {
                NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
            }
        }
    }
    
    func clearLogs() {
        Task {
            // Clear by writing empty file
            let logDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
                .appendingPathComponent("Logs")
                .appendingPathComponent("SpeakYourMind")
            let logFileURL = logDirectory.appendingPathComponent("audit.log")
            
            try? "".write(to: logFileURL, atomically: true, encoding: .utf8)
            loadLogs()
        }
    }
}

#Preview {
    AuditLogViewerView()
}
