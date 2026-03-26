import Foundation
import AppKit
import SwiftUI
import Combine

/// Toast notification for user feedback, displayed near the overlay panel.
final class ToastNotification: ObservableObject, Identifiable {
    let id = UUID()
    let message: String
    let type: ToastType
    let createdAt = Date()
    
    @Published var opacity: Double = 0
    @Published var scale: CGFloat = 0.8
    
    init(message: String, type: ToastType) {
        self.message = message
        self.type = type
    }
    
    func animateIn() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            opacity = 1
            scale = 1.0
        }
    }
    
    func animateOut(completion: @escaping () -> Void) {
        withAnimation(.easeOut(duration: 0.2)) {
            opacity = 0
            scale = 0.9
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            completion()
        }
    }
}

/// Types of toast notifications.
enum ToastType {
    case success
    case info
    case warning
    
    var symbolName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .success: return .green
        case .info: return .blue
        case .warning: return .orange
        }
    }
    
    var displayDuration: TimeInterval {
        switch self {
        case .success: return 2.0
        case .info: return 2.5
        case .warning: return 3.0
        }
    }
}

/// Centralized manager for user feedback with toast notifications.
/// Provides immediate, contextual feedback for all user actions.
final class UserFeedbackManager: ObservableObject {
    
    /// Shared singleton instance.
    static let shared = UserFeedbackManager()
    
    @Published var toasts: [ToastNotification] = []
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: - Public API
    
    /// Shows a toast notification for user feedback.
    /// - Parameters:
    ///   - message: The message to display.
    ///   - type: The type of feedback (success, info, warning).
    func showToast(_ message: String, type: ToastType = .info) {
        let toast = ToastNotification(message: message, type: type)
        
        DispatchQueue.main.async {
            self.toasts.append(toast)
            toast.animateIn()
            
            // Auto-remove after duration
            DispatchQueue.main.asyncAfter(deadline: .now() + toast.type.displayDuration) {
                toast.animateOut {
                    DispatchQueue.main.async {
                        self.toasts.removeAll { $0.id == toast.id }
                    }
                }
            }
        }
    }
    
    /// Shows success feedback.
    func showSuccess(_ message: String) {
        showToast(message, type: .success)
    }
    
    /// Shows info feedback.
    func showInfo(_ message: String) {
        showToast(message, type: .info)
    }
    
    /// Shows warning feedback.
    func showWarning(_ message: String) {
        showToast(message, type: .warning)
    }
    
    /// Shows critical error using NSAlert.
    func showError(_ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Error"
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }
    
    // MARK: - Centralized Error Handling
    
    /// Handles an AppError, logging it and displaying appropriate UI feedback
    func handleAppError(_ error: AppError) {
        let code = error.errorCode
        let message = error.errorDescription ?? "An unknown error occurred."
        let suggestion = error.recoverySuggestion
        
        Logger.shared.error("[\(code)] \(message) - \(error.failureReason ?? "")")
        
        if error.isCritical {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.alertStyle = .critical
                alert.messageText = "Error (\(code))"
                if let suggestion = suggestion {
                    alert.informativeText = "\(message)\n\n\(suggestion)"
                } else {
                    alert.informativeText = message
                }
                alert.addButton(withTitle: "OK")
                NSApp.activate(ignoringOtherApps: true)
                alert.runModal()
            }
        } else {
            showWarning(message)
        }
    }
    
    /// Overload to handle generic errors by wrapping them in AppError
    func handleError(_ error: Error) {
        if let appError = error as? AppError {
            handleAppError(appError)
        } else if let speechError = error as? SpeechError {
            handleAppError(.speech(speechError))
        } else if let aiError = error as? OllamaError {
            handleAppError(.ai(aiError))
        } else if let injectionError = error as? InjectionError {
            handleAppError(.injection(injectionError))
        } else {
            handleAppError(.system(error))
        }
    }
    
    // MARK: - Action Feedback Helpers
    
    /// Feedback for copy action.
    func showCopied() {
        showSuccess("Copied to clipboard")
    }
    
    /// Feedback for text injection.
    func showInjected() {
        showSuccess("Text injected")
    }
    
    /// Feedback for recording started.
    func showRecordingStarted() {
        showInfo("Recording started")
    }
    
    /// Feedback for recording stopped.
    func showRecordingStopped() {
        showSuccess("Recording saved")
    }
    
    /// Feedback for recording paused.
    func showRecordingPaused() {
        showInfo("Paused")
    }
    
    /// Feedback for recording resumed.
    func showRecordingResumed() {
        showInfo("Resumed")
    }
    
    /// Feedback for new session created.
    func showNewSession() {
        showInfo("New session")
    }
    
    /// Feedback for session deleted.
    func showSessionDeleted() {
        showWarning("Session deleted")
    }
    
    /// Feedback for AI processing complete.
    func showAIComplete(action: String) {
        showSuccess("\(action) complete")
    }
    
    /// Feedback for AI processing failed.
    func showAIFailed(error: String) {
        showWarning("AI failed: \(error)")
    }
}