import Foundation
import os

/// The severity level of the audit log entry
public enum AuditLogLevel: String, Codable {
    case debug
    case info
    case warning
    case error
    case fault
}

/// The system category the log entry relates to
public enum AuditLogCategory: String, Codable, CaseIterable {
    case lifecycle
    case speech
    case ai
    case ui
    case settings
    case permissions
    case general
}

/// Specific event types for easier filtering
public enum AuditEventType: String, Codable {
    case appLaunch
    case appQuit
    case appBackground
    case appForeground
    case startRecording
    case stopRecording
    case pauseRecording
    case resumeRecording
    case modeSwitch
    case modelSelection
    case promptProcessing
    case settingsChanged
    case permissionRequested
    case permissionResult
    case error
    case warning
    case unspecified
}

/// A single audit log entry
public struct AuditLogEntry: Codable {
    public let timestamp: Date
    public let level: AuditLogLevel
    public let category: AuditLogCategory
    public let eventType: AuditEventType
    public let message: String
    public let metadata: [String: String]?
    
    public init(timestamp: Date = Date(), level: AuditLogLevel, category: AuditLogCategory, eventType: AuditEventType, message: String, metadata: [String: String]? = nil) {
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.eventType = eventType
        self.message = message
        self.metadata = metadata
    }
}

/// The AuditLogger service responsible for writing structured logs to disk asynchronously
public actor AuditLogger {
    
    /// Shared singleton instance
    public static let shared = AuditLogger()
    
    private let logDirectory: URL
    private let currentLogFileURL: URL
    private let maxFileSize: UInt64 = 10 * 1024 * 1024 // 10 MB
    private let maxRotatedFiles = 5
    
    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    private let fileManager = FileManager.default
    
    // File handle for async writing
    private var fileHandle: FileHandle?
    
    private init() {
        // Setup log directory: ~/Library/Logs/SpeakYourMind
        let libraryDir = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let logsDir = libraryDir.appendingPathComponent("Logs").appendingPathComponent("SpeakYourMind")
        
        self.logDirectory = logsDir
        self.currentLogFileURL = logsDir.appendingPathComponent("audit.log")
        
        Task {
            await setupLogDirectory()
            await openFileHandle()
        }
    }
    
    deinit {
        try? fileHandle?.close()
    }
    
    private func setupLogDirectory() {
        if !fileManager.fileExists(atPath: logDirectory.path) {
            do {
                try fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                os_log("Failed to create audit log directory: %{public}@", type: .error, error.localizedDescription)
            }
        }
    }
    
    private func openFileHandle() {
        if !fileManager.fileExists(atPath: currentLogFileURL.path) {
            fileManager.createFile(atPath: currentLogFileURL.path, contents: nil, attributes: nil)
        }
        
        do {
            fileHandle = try FileHandle(forWritingTo: currentLogFileURL)
            try fileHandle?.seekToEnd()
        } catch {
            os_log("Failed to open audit log file handle: %{public}@", type: .error, error.localizedDescription)
        }
    }
    
    /// Check and perform log rotation if the current file exceeds the size limit
    private func checkRotation() {
        guard let attributes = try? fileManager.attributesOfItem(atPath: currentLogFileURL.path),
              let fileSize = attributes[.size] as? UInt64,
              fileSize >= maxFileSize else {
            return
        }
        
        // Close current file handle
        try? fileHandle?.close()
        fileHandle = nil
        
        // Rotate files
        for i in (1..<maxRotatedFiles).reversed() {
            let oldFileURL = logDirectory.appendingPathComponent("audit-\(i).log")
            let newFileURL = logDirectory.appendingPathComponent("audit-\(i + 1).log")
            
            if fileManager.fileExists(atPath: oldFileURL.path) {
                try? fileManager.moveItem(at: oldFileURL, to: newFileURL)
            }
        }
        
        // Move current to audit-1.log
        let firstRotatedFileURL = logDirectory.appendingPathComponent("audit-1.log")
        if fileManager.fileExists(atPath: currentLogFileURL.path) {
            if fileManager.fileExists(atPath: firstRotatedFileURL.path) {
                try? fileManager.removeItem(at: firstRotatedFileURL)
            }
            try? fileManager.moveItem(at: currentLogFileURL, to: firstRotatedFileURL)
        }
        
        // Reopen file handle
        openFileHandle()
    }
    
    /// Core logging method
    private func log(level: AuditLogLevel, category: AuditLogCategory, eventType: AuditEventType, message: String, metadata: [String: String]? = nil) {
        let entry = AuditLogEntry(level: level, category: category, eventType: eventType, message: message, metadata: metadata)
        
        do {
            var data = try jsonEncoder.encode(entry)
            data.append(contentsOf: "\n".data(using: .utf8)!)
            
            checkRotation()
            
            try fileHandle?.seekToEnd()
            try fileHandle?.write(contentsOf: data)
            
            // Also log to console for debugging
            os_log("[%{public}@] %{public}@: %{public}@", type: osLogType(for: level), category.rawValue, eventType.rawValue, message)
        } catch {
            os_log("Failed to write audit log entry: %{public}@", type: .error, error.localizedDescription)
        }
    }
    
    private func osLogType(for level: AuditLogLevel) -> OSLogType {
        switch level {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .fault: return .fault
        }
    }
    
    // MARK: - Public API
    
    public func info(category: AuditLogCategory, eventType: AuditEventType, message: String, metadata: [String: String]? = nil) {
        log(level: .info, category: category, eventType: eventType, message: message, metadata: metadata)
    }
    
    public func warning(category: AuditLogCategory, eventType: AuditEventType, message: String, metadata: [String: String]? = nil) {
        log(level: .warning, category: category, eventType: eventType, message: message, metadata: metadata)
    }
    
    public func error(category: AuditLogCategory, eventType: AuditEventType, message: String, metadata: [String: String]? = nil) {
        log(level: .error, category: category, eventType: eventType, message: message, metadata: metadata)
    }
    
    public func fault(category: AuditLogCategory, eventType: AuditEventType, message: String, metadata: [String: String]? = nil) {
        log(level: .fault, category: category, eventType: eventType, message: message, metadata: metadata)
    }
    
    public func debug(category: AuditLogCategory, eventType: AuditEventType, message: String, metadata: [String: String]? = nil) {
        log(level: .debug, category: category, eventType: eventType, message: message, metadata: metadata)
    }
    
    /// Retrieve recent logs
    public func getRecentLogs(limit: Int = 100) -> [AuditLogEntry] {
        guard let data = try? Data(contentsOf: currentLogFileURL),
              let content = String(data: data, encoding: .utf8) else {
            return []
        }
        
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        let recentLines = Array(lines.suffix(limit))
        
        var entries: [AuditLogEntry] = []
        for line in recentLines {
            if let lineData = line.data(using: .utf8),
               let entry = try? jsonDecoder.decode(AuditLogEntry.self, from: lineData) {
                entries.append(entry)
            }
        }
        
        return entries
    }
    
    /// Exports all log files (current and rotated) to a temporary directory for sharing
    public func exportLogs() -> URL? {
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("SpeakYourMind_Logs_\(UUID().uuidString)")
        
        do {
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
            
            // Copy current log
            if fileManager.fileExists(atPath: currentLogFileURL.path) {
                try fileManager.copyItem(at: currentLogFileURL, to: tempDir.appendingPathComponent("audit.log"))
            }
            
            // Copy rotated logs
            for i in 1...maxRotatedFiles {
                let oldFileURL = logDirectory.appendingPathComponent("audit-\(i).log")
                if fileManager.fileExists(atPath: oldFileURL.path) {
                    try fileManager.copyItem(at: oldFileURL, to: tempDir.appendingPathComponent("audit-\(i).log"))
                }
            }
            
            return tempDir
        } catch {
            os_log("Failed to export audit logs: %{public}@", type: .error, error.localizedDescription)
            return nil
        }
    }
}
