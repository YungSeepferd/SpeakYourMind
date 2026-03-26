import os
import Foundation

/// Centralized logging utility for SpeakYourMind
/// Usage: Logger.shared.log(.info, "Message") or Logger.shared.error("Error message")
class Logger {
    static let shared = Logger()
    
    private let log: OSLog
    
    init() {
        self.log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.speakyourmind", category: "app")
    }
    
    enum Level {
        case debug
        case info
        case warning
        case error
        case fault
    }
    
    func log(_ level: Level, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let prefix = "[\(fileName):\(line)] \(function) - "
        let logMessage = "{\(level.rawValue.uppercased())} \(prefix)\(message)"
        
        switch level {
        case .debug:
            os_log("{DEBUG} %{public}@", log: log, type: .debug, logMessage)
        case .info:
            os_log("{INFO} %{public}@", log: log, type: .info, logMessage)
        case .warning:
            os_log("{WARN} %{public}@", log: log, type: .error, logMessage)
        case .error:
            os_log("{ERROR} %{public}@", log: log, type: .error, logMessage)
        case .fault:
            os_log("{FAULT} %{public}@", log: log, type: .fault, logMessage)
        }
    }
    
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message, file: file, function: function, line: line)
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message, file: file, function: function, line: line)
    }
    
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message, file: file, function: function, line: line)
    }
    
    func fault(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.fault, message, file: file, function: function, line: line)
    }
}

// MARK: - Level Raw Value Extension
extension Logger.Level {
    var rawValue: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARN"
        case .error: return "ERROR"
        case .fault: return "FAULT"
        }
    }
}
