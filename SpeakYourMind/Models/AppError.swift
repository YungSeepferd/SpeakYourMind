import Foundation
import AppKit

/// Centralized error type for the SpeakYourMind application.
/// Wraps domain-specific errors and provides unified handling.
enum AppError: LocalizedError, Identifiable {
    case speech(SpeechError)
    case ai(OllamaError)
    case injection(InjectionError)
    case permission(String)
    case system(Error)
    case validation(String)
    
    var id: String { UUID().uuidString }
    
    var errorDescription: String? {
        switch self {
        case .speech(let error): return error.errorDescription
        case .ai(let error): return error.errorDescription
        case .injection(let error): return error.errorDescription
        case .permission(let message): return message
        case .system(let error): return error.localizedDescription
        case .validation(let message): return message
        }
    }
    
    var failureReason: String? {
        switch self {
        case .speech(let error): return error.failureReason
        case .ai(let error): return error.failureReason
        case .injection(let error): return error.failureReason
        case .permission: return "Missing required permissions."
        case .system(let error): return (error as NSError).localizedFailureReason
        case .validation: return "Validation failed."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .speech(let error): return error.recoverySuggestion
        case .ai(let error): return error.recoverySuggestion
        case .injection(let error): return error.recoverySuggestion
        case .permission: return "Please update your permissions in System Settings."
        case .system(let error): return (error as NSError).localizedRecoverySuggestion
        case .validation: return "Please check your input and try again."
        }
    }
    
    var isCritical: Bool {
        switch self {
        case .speech(let error):
            switch error {
            case .microphoneDenied, .microphoneRestricted, .speechRecognitionDenied, .speechRecognitionRestricted:
                return true
            default:
                return false
            }
        case .ai(let error):
            switch error {
            case .connectionRefused, .notRunning:
                return true
            default:
                return false
            }
        case .injection(let error):
            switch error {
            case .eventPostFailed:
                return true
            default:
                return false
            }
        case .permission, .system:
            return true
        case .validation:
            return false
        }
    }
    
    var errorCode: String {
        switch self {
        case .speech(let error):
            let typeName = String(describing: error).split(separator: "(").first ?? ""
            return "ERR_SPEECH_\(String(typeName).prefix(15).uppercased())"
        case .ai(let error):
            let typeName = String(describing: error).split(separator: "(").first ?? ""
            return "ERR_AI_\(String(typeName).prefix(15).uppercased())"
        case .injection(let error):
            let typeName = String(describing: error).split(separator: "(").first ?? ""
            return "ERR_INJ_\(String(typeName).prefix(15).uppercased())"
        case .permission:
            return "ERR_PERM"
        case .system:
            return "ERR_SYS"
        case .validation:
            return "ERR_VAL"
        }
    }
}
