import Foundation
import AVFoundation
import Speech
import AppKit

/// Represents the authorization status for a permission.
enum PermissionStatus: Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
    
    var isGranted: Bool {
        self == .authorized
    }
    
    var isAuthorized: Bool {
        self == .authorized
    }
}

// MARK: - AVAuthorizationStatus Extension

extension AVAuthorizationStatus {
    /// Maps AVAuthorizationStatus to PermissionStatus.
    var permissionStatus: PermissionStatus {
        switch self {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }
}

// MARK: - SFSpeechRecognizerAuthorizationStatus Extension

extension SFSpeechRecognizerAuthorizationStatus {
    /// Maps SFSpeechRecognizerAuthorizationStatus to PermissionStatus.
    var permissionStatus: PermissionStatus {
        switch self {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }
}