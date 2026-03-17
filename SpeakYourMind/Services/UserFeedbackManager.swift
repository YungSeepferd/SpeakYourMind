import Foundation
import AppKit

/// Types of user feedback messages following macOS patterns.
enum FeedbackType {
    /// Critical errors requiring immediate attention (uses NSAlert).
    case error
    /// Warnings about potential issues (uses status bar).
    case warning
    /// Success confirmations (uses status bar).
    case success
    /// Informational messages (uses status bar).
    case info
    
    var title: String {
        switch self {
        case .error: return "Error"
        case .warning: return "Warning"
        case .success: return "Success"
        case .info: return "Info"
        }
    }
    
    var symbolName: String {
        switch self {
        case .error: return "exclamationmark.triangle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    var tintColor: NSColor {
        switch self {
        case .error: return .systemRed
        case .warning: return .systemOrange
        case .success: return .systemGreen
        case .info: return .systemBlue
        }
    }
}

/// Centralized manager for user feedback following macOS app patterns.
/// Uses NSAlert for critical errors and status bar for non-critical messages.
final class UserFeedbackManager {
    
    /// Shared singleton instance.
    static let shared = UserFeedbackManager()
    
    private var statusItem: NSStatusItem?
    private var statusBarTimer: Timer?
    
    private init() {
        setupStatusItem()
    }
    
    // MARK: - Public API
    
    /// Shows feedback to the user based on the feedback type.
    /// - Parameters:
    ///   - feedback: The type of feedback to display.
    ///   - message: The message to display.
    func show(_ feedback: FeedbackType, message: String) {
        switch feedback {
        case .error:
            showAlert(title: feedback.title, message: message)
        case .warning, .success, .info:
            showStatusBarMessage(message, isError: feedback == .warning)
        }
    }
    
    /// Convenience method for showing error feedback.
    func showError(_ message: String) {
        show(.error, message: message)
    }
    
    /// Convenience method for showing warning feedback.
    func showWarning(_ message: String) {
        show(.warning, message: message)
    }
    
    /// Convenience method for showing success feedback.
    func showSuccess(_ message: String) {
        show(.success, message: message)
    }
    
    /// Convenience method for showing info feedback.
    func showInfo(_ message: String) {
        show(.info, message: message)
    }
    
    // MARK: - Private Helpers
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.isVisible = false
    }
    
    /// Shows an NSAlert for critical errors.
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        
        // Make alert modal to the app
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
    
    /// Shows a temporary status bar message for non-critical feedback.
    private func showStatusBarMessage(_ message: String, isError: Bool) {
        guard let button = statusItem?.button else { return }
        
        // Cancel any existing timer
        statusBarTimer?.invalidate()
        
        // Configure the status item
        button.image = NSImage(systemSymbolName: isError ? "exclamationmark.triangle.fill" : "info.circle.fill",
                               accessibilityDescription: "Status")
        button.image?.isTemplate = false
        button.contentTintColor = isError ? .systemOrange : .secondaryLabelColor
        button.title = " \(message)"
        statusItem?.isVisible = true
        
        // Auto-hide after 4 seconds
        statusBarTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            self?.hideStatusBarMessage()
        }
    }
    
    /// Hides the status bar message.
    private func hideStatusBarMessage() {
        statusItem?.isVisible = false
        statusItem?.button?.title = ""
    }
}