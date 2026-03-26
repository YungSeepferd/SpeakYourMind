import AppKit

/// Errors that can occur during permission requests.
enum PermissionError: LocalizedError {
    case accessibilityDenied
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .accessibilityDenied:
            return "Accessibility permission was denied. Please enable it in System Settings > Privacy & Security > Accessibility."
        case .timeout:
            return "Permission request timed out. Please try again."
        }
    }
    
    var failureReason: String? {
        switch self {
        case .accessibilityDenied:
            return "Accessibility permission has been denied. This permission is required for text injection."
        case .timeout:
            return "The permission request did not complete within the expected time."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .accessibilityDenied:
            return "Open System Settings > Privacy & Security > Accessibility and enable access for this app."
        case .timeout:
            return "Try again by clicking the permission button, or manually grant permission in System Settings."
        }
    }
}

/// Manages Accessibility permission required for text injection via CGEvent.
/// 
/// This class provides methods to check and request Accessibility permissions,
/// which are required for injecting text via simulated keyboard events (CGEvent).
final class PermissionsManager: ObservableObject {

    /// Whether the process is already trusted for accessibility.
    /// 
    /// Returns `true` if the app has been granted Accessibility permissions in
    /// System Settings, allowing CGEvent-based text injection.
    var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }
    
    /// Current accessibility permission status.
    @Published var accessibilityStatus: PermissionStatus = .notDetermined
    
    /// Callback invoked when accessibility permission state changes.
    var onPermissionChange: ((Bool) -> Void)?
    
    /// Timer for polling permission changes.
    private var permissionCheckTimer: Timer?
    
    /// Task for polling accessibility permission.
    private var pollingTask: Task<Void, Never>?

    /// Prompts the user for accessibility access (shows system dialog).
    /// 
    /// Displays the system accessibility permission dialog if not already granted.
    /// This method returns immediately without waiting for user response.
    /// 
    /// - Returns: `true` if accessibility is already granted, `false` if the prompt was shown.
    @discardableResult
    func requestAccessibilityIfNeeded() -> Bool {
        if AXIsProcessTrusted() { return true }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    /// Checks and updates the current accessibility permission status.
    /// 
    /// - Returns: The current PermissionStatus.
    @discardableResult
    func checkAccessibilityStatus() -> PermissionStatus {
        let isTrusted = AXIsProcessTrusted()
        accessibilityStatus = isTrusted ? .authorized : .denied
        return accessibilityStatus
    }
    
    /// Checks and requests accessibility permission using async/await.
    /// Uses withCheckedContinuation for AXIsProcessTrustedWithOptions.
    /// 
    /// - Returns: True if permission was granted, false otherwise.
    func checkAndRequestAccessibility() async -> Bool {
        // First check current status
        checkAccessibilityStatus()
        
        if accessibilityStatus == .authorized {
            return true
        }
        
        // Request permission (shows system dialog)
        return await withCheckedContinuation { continuation in
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            let result = AXIsProcessTrustedWithOptions(options)
            
            // Check result immediately
            if result {
                DispatchQueue.main.async {
                    self.accessibilityStatus = .authorized
                }
                continuation.resume(returning: true)
            } else {
                // Start polling for permission grant
                Task {
                    let granted = await self.startPollingForPermission()
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    /// Starts polling for accessibility permission every 2 seconds until granted.
    /// 
    /// - Parameter timeout: Maximum time to wait in seconds (default 30).
    /// - Returns: True if permission was granted, false if timeout.
    func startPollingForPermission(timeout: TimeInterval = 30.0) async -> Bool {
        return await withCheckedContinuation { continuation in
            let startTime = Date()
            
            func checkPermission() {
                if AXIsProcessTrusted() {
                    DispatchQueue.main.async {
                        self.accessibilityStatus = .authorized
                    }
                    continuation.resume(returning: true)
                    return
                }
                
                if Date().timeIntervalSince(startTime) >= timeout {
                    DispatchQueue.main.async {
                        self.accessibilityStatus = .denied
                    }
                    continuation.resume(returning: false)
                    return
                }
                
                // Poll every 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    checkPermission()
                }
            }
            
            checkPermission()
        }
    }
    
    /// Requests accessibility permission using async/await.
    /// 
    /// - Parameter timeout: Maximum time to wait for permission (default 30 seconds).
    /// - Returns: True if permission was granted, false otherwise.
    func requestAccessibilityAsync(timeout: TimeInterval = 30.0) async -> Bool {
        if AXIsProcessTrusted() {
            accessibilityStatus = .authorized
            return true
        }
        
        _ = requestAccessibilityIfNeeded()
        
        return await withCheckedContinuation { continuation in
            let startTime = Date()
            
            func checkPermission() {
                if AXIsProcessTrusted() {
                    DispatchQueue.main.async {
                        self.accessibilityStatus = .authorized
                    }
                    continuation.resume(returning: true)
                    return
                }
                
                if Date().timeIntervalSince(startTime) >= timeout {
                    DispatchQueue.main.async {
                        self.accessibilityStatus = .denied
                    }
                    continuation.resume(returning: false)
                    return
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    checkPermission()
                }
            }
            
            checkPermission()
        }
    }

    /// Prompts for accessibility, then polls until granted or timeout.
    /// 
    /// Requests accessibility permission if not already granted, then polls
    /// the system every second for up to the specified timeout to detect when the user
    /// grants permission in System Settings.
    /// 
    /// - Parameters:
    ///   - timeout: Maximum time to wait in seconds (default 30).
    ///   - completion: Callback with Result indicating success or failure.
    func ensureAccessibility(timeout: TimeInterval = 30.0, completion: @escaping (Result<Bool, PermissionError>) -> Void) {
        checkAccessibilityStatus()
        
        if accessibilityStatus == .authorized {
            completion(.success(true))
            return
        }
        
        _ = requestAccessibilityIfNeeded()
        poll(timeout: timeout, completion: completion)
    }
    
    /// Starts monitoring for permission changes with a callback.
    /// 
    /// - Parameter interval: How often to check for permission changes (default 1 second).
    func startMonitoring(interval: TimeInterval = 1.0) {
        stopMonitoring()
        
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            let wasGranted = self.isAccessibilityGranted
            self.onPermissionChange?(wasGranted)
        }
    }
    
    /// Stops monitoring for permission changes.
    func stopMonitoring() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }
    
    /// Cancels any ongoing polling task.
    func cancelPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func poll(timeout: TimeInterval, completion: @escaping (Result<Bool, PermissionError>) -> Void) {
        let startTime = Date()
        
        func check() {
            if AXIsProcessTrusted() {
                accessibilityStatus = .authorized
                completion(.success(true))
                return
            }
            
            if Date().timeIntervalSince(startTime) >= timeout {
                Logger.shared.error("Permission check timed out after \(timeout) seconds")
                accessibilityStatus = .denied
                completion(.failure(.timeout))
                return
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                check()
            }
        }
        
        check()
    }
}