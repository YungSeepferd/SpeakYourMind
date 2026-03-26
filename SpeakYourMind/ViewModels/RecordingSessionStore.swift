import Foundation
import Combine

/// Manages multiple recording sessions with tab-like navigation.
final class RecordingSessionStore: ObservableObject {
    @Published var sessions: [RecordingSession] = []
    @Published var selectedSessionId: UUID?
    @Published var searchQuery: String = ""

    var filteredSessions: [RecordingSession] {
        guard !searchQuery.isEmpty else { return sessions }
        let query = searchQuery.lowercased()
        return sessions.filter {
            $0.text.lowercased().contains(query) ||
            ($0.customTitle?.lowercased().contains(query) ?? false)
        }
    }
    
    private var saveTimer: Timer?
    private var pendingChanges = false
    private var saveQueued = false
    
    var currentSession: RecordingSession? {
        get {
            sessions.first { $0.id == selectedSessionId }
        }
        set {
            if let newSession = newValue {
                if let index = sessions.firstIndex(where: { $0.id == newSession.id }) {
                    sessions[index] = newSession
                } else {
                    sessions.append(newSession)
                }
            }
        }
    }
    
    var selectedSessionIndex: Int {
        sessions.firstIndex { $0.id == selectedSessionId } ?? -1
    }
    
    init() {
        loadSessions()
    }
    
    func createNewSession() -> RecordingSession {
        let newSession = RecordingSession()
        sessions.append(newSession)
        selectedSessionId = newSession.id
        return newSession
    }
    
    func selectSession(_ id: UUID) {
        saveTimer?.invalidate()
        saveTimer = nil
        if pendingChanges {
            saveSessions()
            pendingChanges = false
        }
        selectedSessionId = id
        saveSessions()
    }
    
    func updateCurrentText(_ text: String) {
        if let index = sessions.firstIndex(where: { $0.id == selectedSessionId }) {
            sessions[index].text = text
        }
        pendingChanges = true
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.pendingChanges {
                self.saveSessions()
                self.pendingChanges = false
            }
            self.saveQueued = false
        }
    }
    
    func updateCurrentDuration(_ duration: TimeInterval) {
        if let index = sessions.firstIndex(where: { $0.id == selectedSessionId }) {
            sessions[index].duration = duration
        }
    }
    
    func markCurrentCompleted() {
        saveTimer?.invalidate()
        saveTimer = nil
        if pendingChanges {
            saveSessions()
            pendingChanges = false
        }
        if let index = sessions.firstIndex(where: { $0.id == selectedSessionId }) {
            sessions[index].isCompleted = true
        }
        saveSessions()
    }
    
    func deleteSession(_ id: UUID) {
        sessions.removeAll { $0.id == id }
        if selectedSessionId == id {
            selectedSessionId = sessions.first?.id
        }
    }
    
    func renameSession(_ id: UUID, newName: String) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index].customTitle = newName.isEmpty ? nil : newName
        saveSessions()
    }
    
    func deleteAllSessions() {
        sessions.removeAll { !$0.isPinned }
        if !sessions.contains(where: { $0.id == selectedSessionId }) {
            selectedSessionId = sessions.first?.id
        }
    }
    
    func pinSession(_ id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index].isPinned = true
        sortSessions()
        saveSessions()
    }
    
    func unpinSession(_ id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index].isPinned = false
        sortSessions()
        saveSessions()
    }
    
    func togglePin(_ id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index].isPinned.toggle()
        sortSessions()
        saveSessions()
    }
    
    private func sortSessions() {
        sessions.sort { $0.isPinned && !$1.isPinned }
    }
    
    deinit {
        saveTimer?.invalidate()
        if pendingChanges {
            saveSessions()
        }
    }
    
    // MARK: - Persistence
    
    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: "recordingSessions"),
              let decoded = try? JSONDecoder().decode([RecordingSession].self, from: data) else {
            return
        }
        sessions = decoded
        sortSessions()
        if !sessions.isEmpty {
            selectedSessionId = sessions[0].id
        }
    }
    
    func saveSessions() {
        guard !saveQueued else { return }
        saveQueued = true
        guard let encoded = try? JSONEncoder().encode(sessions) else {
            saveQueued = false
            return
        }
        UserDefaults.standard.set(encoded, forKey: "recordingSessions")
    }
}
