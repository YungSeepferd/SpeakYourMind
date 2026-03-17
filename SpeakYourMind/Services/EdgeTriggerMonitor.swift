import AppKit
import SwiftUI
import Combine

/// Monitors mouse position to detect when cursor hits the screen edge.
/// Shows a minimal overlay panel when edge is triggered.
final class EdgeTriggerMonitor: ObservableObject {
    
    // MARK: - Constants
    
    /// Default edge trigger sensitivity (pixels from edge)
    static let defaultEdgeSensitivity: CGFloat = 20
    
    /// Minimum edge sensitivity
    static let minEdgeSensitivity: CGFloat = 10
    
    /// Maximum edge sensitivity
    static let maxEdgeSensitivity: CGFloat = 30
    
    /// Delay before hiding overlay after mouse leaves edge area
    static let hideDelay: TimeInterval = 2.0
    
    // MARK: - Published Properties
    
    /// Whether edge trigger monitoring is enabled
    @Published var isEnabled: Bool = false {
        didSet {
            if isEnabled != oldValue {
                if isEnabled {
                    startMonitoring()
                } else {
                    stopMonitoring()
                }
                UserDefaults.standard.set(isEnabled, forKey: "edgeTriggerEnabled")
            }
        }
    }
    
    /// Edge sensitivity in pixels (how close to edge to trigger)
    @Published var edgeSensitivity: CGFloat = defaultEdgeSensitivity {
        didSet {
            UserDefaults.standard.set(edgeSensitivity, forKey: "edgeSensitivity")
            updateTrackingArea()
        }
    }
    
    // MARK: - Private Properties
    
    /// The overlay panel shown when edge is triggered
    private var overlayWindow: NSWindow?
    
    /// Tracking area for mouse movement
    private var trackingArea: NSTrackingArea?
    
    /// Screen to monitor (defaults to main screen)
    private var targetScreen: NSScreen? {
        NSScreen.main
    }
    
    /// Timer for delayed hide
    private var hideTimer: Timer?
    
    /// Whether the mouse is currently in the trigger area
    private var isMouseInTriggerArea = false
    
    /// Whether the overlay is currently visible
    private var isOverlayVisible = false
    
    /// Global event monitor for detecting clicks outside overlay
    private var globalEventMonitor: Any?
    
    /// Local event monitor for Escape key
    private var localEventMonitor: Any?
    
    // MARK: - Initialization
    
    init() {
        // Load saved settings
        isEnabled = UserDefaults.standard.bool(forKey: "edgeTriggerEnabled")
        edgeSensitivity = UserDefaults.standard.object(forKey: "edgeSensitivity") as? CGFloat ?? Self.defaultEdgeSensitivity
        
        // Clamp sensitivity to valid range
        edgeSensitivity = max(Self.minEdgeSensitivity, min(Self.maxEdgeSensitivity, edgeSensitivity))
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Starts monitoring for edge trigger events
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        updateTrackingArea()
        setupEventMonitors()
        
        print("[EdgeTriggerMonitor] Started monitoring for edge trigger")
    }
    
    /// Stops monitoring for edge trigger events
    func stopMonitoring() {
        removeTrackingArea()
        removeEventMonitors()
        hideOverlay()
        
        print("[EdgeTriggerMonitor] Stopped monitoring for edge trigger")
    }
    
    /// Whether the monitor is currently active
    var isMonitoring: Bool {
        trackingArea != nil
    }
    
    // MARK: - Private Methods - Tracking Area
    
    private func updateTrackingArea() {
        removeTrackingArea()
        
        guard let screen = targetScreen else { return }
        
        // Create a tracking area at the top edge of the screen
        let screenFrame = screen.frame
        let triggerRect = NSRect(
            x: screenFrame.origin.x,
            y: screenFrame.origin.y + screenFrame.height - edgeSensitivity,
            width: screenFrame.width,
            height: edgeSensitivity
        )
        
        trackingArea = NSTrackingArea(
            rect: triggerRect,
            options: [
                .mouseEnteredAndExited,
                .mouseMoved,
                .activeAlways,
                .inVisibleRect
            ],
            owner: self,
            userInfo: nil
        )
        
        // Add tracking area to the first window's content view
        if let area = trackingArea,
           let window = NSApplication.shared.windows.first {
            window.contentView?.addTrackingArea(area)
            print("[EdgeTriggerMonitor] Tracking area updated: \(triggerRect)")
        }
    }
    
    private func removeTrackingArea() {
        if let area = trackingArea,
           let window = NSApplication.shared.windows.first {
            window.contentView?.removeTrackingArea(area)
        }
        trackingArea = nil
    }
    
    // MARK: - Private Methods - Event Monitors
    
    private func setupEventMonitors() {
        // Monitor for global mouse moved events to track cursor position
        NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            self?.handleMouseMoved(event)
        }
        
        // Monitor for Escape key to hide overlay
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.hideOverlay()
                return nil
            }
            return event
        }
        
        // Monitor for clicks outside overlay to hide it
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleGlobalClick(event)
        }
    }
    
    private func removeEventMonitors() {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
    }
    
    // MARK: - Private Methods - Event Handlers
    
    private func handleMouseMoved(_ event: NSEvent) {
        guard let screen = targetScreen else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        let screenFrame = screen.frame
        let topEdge = screenFrame.origin.y + screenFrame.height
        
        // Check if mouse is within the trigger area (top edge)
        let isInEdgeArea = mouseLocation.y >= (topEdge - edgeSensitivity)
        
        if isInEdgeArea && !isMouseInTriggerArea {
            // Mouse entered the edge area
            isMouseInTriggerArea = true
            cancelHideTimer()
            
            if !isOverlayVisible {
                showOverlay(at: mouseLocation)
            }
        } else if !isInEdgeArea && isMouseInTriggerArea {
            // Mouse left the edge area
            isMouseInTriggerArea = false
            
            // Start hide timer
            startHideTimer()
        }
        
        // If overlay is visible and mouse is in trigger area, keep it visible
        if isOverlayVisible && isInEdgeArea {
            cancelHideTimer()
        }
    }
    
    private func handleGlobalClick(_ event: NSEvent) {
        guard isOverlayVisible else { return }
        
        // Check if click is outside the overlay window
        if let window = overlayWindow {
            let windowFrame = window.frame
            
            // Convert to screen coordinates
            let screenLocation = NSEvent.mouseLocation
            
            if !windowFrame.contains(screenLocation) {
                hideOverlay()
            }
        }
    }
    
    // MARK: - Private Methods - Overlay
    
    private func showOverlay(at mouseLocation: NSPoint) {
        guard !isOverlayVisible else { return }
        
        // Create minimal overlay content
        let overlayView = EdgeOverlayView()
        let hostingController = NSHostingController(rootView: overlayView)
        
        // Create borderless window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 120),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        window.level = .floating
        window.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95)
        window.isOpaque = false
        window.hasShadow = true
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        
        // Position near cursor but ensure it stays on screen
        positionOverlayWindow(window, near: mouseLocation)
        
        // Show the window
        window.orderFront(nil)
        overlayWindow = window
        isOverlayVisible = true
        
        // Make window key to receive keyboard events
        window.makeKey()
        
        print("[EdgeTriggerMonitor] Overlay shown at \(mouseLocation)")
    }
    
    private func positionOverlayWindow(_ window: NSWindow, near mouseLocation: NSPoint) {
        guard let screen = targetScreen else { return }
        
        let windowSize = window.frame.size
        let screenFrame = screen.frame
        
        // Position below the cursor (so it doesn't cover the trigger area)
        var originX = mouseLocation.x - (windowSize.width / 2)
        var originY = mouseLocation.y - windowSize.height - 10
        
        // Ensure window stays within screen bounds
        originX = max(screenFrame.minX + 10, min(originX, screenFrame.maxX - windowSize.width - 10))
        originY = max(screenFrame.minY + 10, min(originY, screenFrame.maxY - windowSize.height - 10))
        
        window.setFrameOrigin(NSPoint(x: originX, y: originY))
    }
    
    private func hideOverlay() {
        guard isOverlayVisible else { return }
        
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        isOverlayVisible = false
        cancelHideTimer()
        
        print("[EdgeTriggerMonitor] Overlay hidden")
    }
    
    // MARK: - Private Methods - Timers
    
    private func startHideTimer() {
        cancelHideTimer()
        
        hideTimer = Timer.scheduledTimer(withTimeInterval: Self.hideDelay, repeats: false) { [weak self] _ in
            // Only hide if mouse hasn't returned to trigger area
            if !(self?.isMouseInTriggerArea ?? false) {
                self?.hideOverlay()
            }
        }
    }
    
    private func cancelHideTimer() {
        hideTimer?.invalidate()
        hideTimer = nil
    }
}

// MARK: - Edge Overlay View

/// Minimal overlay view shown when edge is triggered.
/// Contains a record button and live transcription display.
struct EdgeOverlayView: View {
    @StateObject private var speechManager = SpeechManager()
    @State private var showPermissionAlert = false
    @State private var permissionAlertMessage = ""
    
    var body: some View {
        VStack(spacing: 8) {
            // Header with status
            HStack {
                Circle()
                    .fill(speechManager.isListening ? Color.red : Color.gray.opacity(0.4))
                    .frame(width: 8, height: 8)
                
                Text(speechManager.isListening ? "Recording…" : "Tap to speak")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            // Live transcription
            ScrollView {
                Text(speechManager.transcribedText.isEmpty 
                     ? "Your speech will appear here…" 
                     : speechManager.transcribedText)
                    .font(.system(size: 12))
                    .foregroundColor(speechManager.transcribedText.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(3)
            }
            .frame(height: 40)
            
            // Record button
            Button {
                toggleRecording()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: speechManager.isListening ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 16))
                    Text(speechManager.isListening ? "Stop" : "Record")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(speechManager.isListening ? .red : .accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(speechManager.isListening ? Color.red.opacity(0.1) : Color.accentColor.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 280, height: 120)
        .onChange(of: speechManager.lastError) { newError in
            guard let error = newError else { return }
            handleSpeechError(error: error)
            speechManager.lastError = nil
        }
        .alert("Permission Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                openSystemSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(permissionAlertMessage)
        }
    }
    
    private func toggleRecording() {
        if speechManager.isListening {
            speechManager.stopListening()
        } else {
            do {
                try speechManager.startListening()
            } catch {
                // Error handled via onChange
            }
        }
    }
    
    private func handleSpeechError(error: SpeechError) {
        switch error {
        case .microphoneUnavailable, .microphoneDenied, .microphoneRestricted:
            permissionAlertMessage = "Microphone access is required. Please enable it in System Settings."
            showPermissionAlert = true
        case .speechRecognitionDenied, .speechRecognitionRestricted:
            permissionAlertMessage = "Speech recognition permission is required. Please enable it in System Settings."
            showPermissionAlert = true
        default:
            permissionAlertMessage = error.errorDescription ?? "An error occurred."
            showPermissionAlert = true
        }
    }
    
    private func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}