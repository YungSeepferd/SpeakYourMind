import AppKit
import SwiftUI
import Combine
import Foundation

/// Monitors mouse position to detect when cursor hits the screen edge.
/// Shows a minimal overlay panel when edge is triggered.
final class EdgeTriggerMonitor: ObservableObject {
    
    // MARK: - Constants
    
    static let defaultEdgeSensitivity: CGFloat = 20
    static let minEdgeSensitivity: CGFloat = 10
    static let maxEdgeSensitivity: CGFloat = 30
    static let hideDelay: TimeInterval = 2.0
    
    // MARK: - Published Properties
    
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
    
    @Published var edgeSensitivity: CGFloat = defaultEdgeSensitivity {
        didSet {
            UserDefaults.standard.set(edgeSensitivity, forKey: "edgeSensitivity")
            updateTrackingArea()
        }
    }
    
    // MARK: - Private Properties
    
    private var overlayWindow: NSWindow?
    private var trackingAreas: [NSTrackingArea] = []
    private var hideTimer: Timer?
    private var isMouseInTriggerArea = false
    private var isOverlayVisible = false
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var screenChangeObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var lastMouseLocation: NSPoint?
    
    // MARK: - Initialization
    
    init() {
        isEnabled = UserDefaults.standard.bool(forKey: "edgeTriggerEnabled")
        edgeSensitivity = UserDefaults.standard.object(forKey: "edgeSensitivity") as? CGFloat ?? Self.defaultEdgeSensitivity
        edgeSensitivity = max(Self.minEdgeSensitivity, min(Self.maxEdgeSensitivity, edgeSensitivity))
        
        setupScreenChangeObserver()
        setupWakeObserver()
    }
    
    deinit {
        stopMonitoring()
        removeScreenChangeObserver()
        removeWakeObserver()
    }
    
    // MARK: - Public Methods
    
    var isMonitoring: Bool {
        !trackingAreas.isEmpty
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        updateTrackingArea()
        setupEventMonitors()
        
        Logger.shared.info("Started monitoring for edge trigger")
    }
    
    func stopMonitoring() {
        removeTrackingAreas()
        removeEventMonitors()
        hideOverlay()
        
        Logger.shared.info("Stopped monitoring for edge trigger")
    }
    
    func resetStuckState() {
        Logger.shared.warning("Resetting stuck overlay state")
        hideOverlay()
        isMouseInTriggerArea = false
        cancelHideTimer()
    }
    
    // MARK: - Private Methods - Screen Configuration
    
    private func setupScreenChangeObserver() {
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenConfigurationChange()
        }
    }
    
    private func removeScreenChangeObserver() {
        if let observer = screenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            screenChangeObserver = nil
        }
    }
    
    private func handleScreenConfigurationChange() {
        Logger.shared.info("Screen configuration changed, rebuilding tracking areas")
        updateTrackingArea()
    }
    
    private func setupWakeObserver() {
        wakeObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resetStuckState()
        }
        
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resetStuckState()
        }
    }
    
    private func removeWakeObserver() {
        if let observer = wakeObserver {
            NotificationCenter.default.removeObserver(observer)
            wakeObserver = nil
        }
    }
    
    // MARK: - Private Methods - Tracking Area
    
    private func updateTrackingArea() {
        removeTrackingAreas()
        
        for screen in NSScreen.screens {
            addTrackingArea(for: screen)
        }
    }
    
    private func addTrackingArea(for screen: NSScreen) {
        let screenFrame = screen.frame
        let triggerRect: NSRect
        
        let primaryScreen = NSScreen.screens.max(by: { $0.frame.maxY < $1.frame.maxY })
        let isPrimaryScreen = screen == primaryScreen
        
        if isPrimaryScreen {
            triggerRect = NSRect(
                x: screenFrame.origin.x,
                y: screenFrame.origin.y + screenFrame.height - edgeSensitivity,
                width: screenFrame.width,
                height: edgeSensitivity
            )
        } else {
            triggerRect = NSRect(
                x: screenFrame.origin.x,
                y: screenFrame.origin.y,
                width: screenFrame.width,
                height: edgeSensitivity
            )
        }
        
        let trackingArea = NSTrackingArea(
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
        
        if let window = NSApplication.shared.windows.first(where: { $0.screen == screen }) {
            window.contentView?.addTrackingArea(trackingArea)
            trackingAreas.append(trackingArea)
            Logger.shared.debug("Tracking area added for screen: \(screen.localizedName)")
        } else if let mainWindow = NSApplication.shared.windows.first {
            mainWindow.contentView?.addTrackingArea(trackingArea)
            trackingAreas.append(trackingArea)
        }
    }
    
    private func removeTrackingAreas() {
        for area in trackingAreas {
            for window in NSApplication.shared.windows {
                window.contentView?.removeTrackingArea(area)
            }
        }
        trackingAreas.removeAll()
    }
    
    private func screenContainingMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
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
        guard let screen = screenContainingMouse() else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        let screenFrame = screen.frame
        
        let primaryScreen = NSScreen.screens.max(by: { $0.frame.maxY < $1.frame.maxY })
        let isPrimaryScreen = screen == primaryScreen
        
        let isInEdgeArea: Bool
        if isPrimaryScreen {
            isInEdgeArea = mouseLocation.y >= (screenFrame.maxY - edgeSensitivity)
        } else {
            isInEdgeArea = mouseLocation.y <= edgeSensitivity
        }
        
        lastMouseLocation = mouseLocation
        
        if isInEdgeArea && !isMouseInTriggerArea {
            isMouseInTriggerArea = true
            cancelHideTimer()
            
            if !isOverlayVisible {
                showOverlay(at: mouseLocation, on: screen)
            }
        } else if !isInEdgeArea && isMouseInTriggerArea {
            isMouseInTriggerArea = false
            startHideTimer()
        }
        
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
    
    var speechManager: SpeechManager?
    var sessionStore: RecordingSessionStore?

    private func showOverlay(at mouseLocation: NSPoint, on screen: NSScreen) {
        guard !isOverlayVisible else { return }
        guard let sm = speechManager, let ss = sessionStore else {
            Logger.shared.error("EdgeTriggerMonitor missing SpeechManager or RecordingSessionStore")
            return
        }
        
        let overlayView = EdgeOverlayView(speechManager: sm, sessionStore: ss)
        let hostingController = NSHostingController(rootView: overlayView)
        
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
        
        positionOverlayWindow(window, near: mouseLocation, on: screen)
        
        window.orderFront(nil)
        overlayWindow = window
        isOverlayVisible = true
        
        window.makeKey()
        
        Logger.shared.debug("Overlay shown at \(mouseLocation)")
    }
    
    private func positionOverlayWindow(_ window: NSWindow, near mouseLocation: NSPoint, on screen: NSScreen) {
        let windowSize = window.frame.size
        let screenFrame = screen.frame
        
        var originX = mouseLocation.x - (windowSize.width / 2)
        var originY = mouseLocation.y - windowSize.height - 10
        
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
        
        Logger.shared.debug("Overlay hidden")
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

/// Minimal overlay view shown when edge is triggered.
/// Contains a record button and live transcription display.
struct EdgeOverlayView: View {
    @ObservedObject var speechManager: SpeechManager
    @ObservedObject var sessionStore: RecordingSessionStore
    @ObservedObject private var feedbackManager = UserFeedbackManager.shared
    @State private var showPermissionAlert = false
    @State private var permissionAlertMessage = ""
    @FocusState private var focusedField: FocusField?
    
    enum FocusField: Hashable {
        case recordButton
        case pauseButton
        case clearButton
        case closeButton
    }
    
    var body: some View {
        ZStack {
            overlayContent
            ToastContainerView(content: EmptyView(), feedbackManager: feedbackManager)
        }
        .frame(width: 280, height: 120)
        .onAppear { focusedField = .recordButton }
        .onChange(of: speechManager.transcribedText) { newText in
            sessionStore.updateCurrentText(newText)
            sessionStore.saveSessions()
        }
        .onChange(of: speechManager.lastError) { newError in
            guard let error = newError else { return }
            handleSpeechError(error: error)
            speechManager.lastError = nil
        }
        .alert("Permission Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") { openSystemSettings() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(permissionAlertMessage)
        }
    }
    
    @ViewBuilder
    private var overlayContent: some View {
        VStack(spacing: 8) {
            headerView
            transcriptionView
            buttonRow
        }
        .padding(12)
    }
    
    private var headerView: some View {
        HStack {
            // Mode badge
            Text("Edge Capture")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
            
            Circle()
                .fill(speechManager.isListening ? Color.red : Color.gray.opacity(0.4))
                .frame(width: 8, height: 8)
            
            Text(speechManager.isListening ? "Recording…" : "Tap to speak")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            
            // Session count badge
            if !sessionStore.sessions.isEmpty {
                Text("\(sessionStore.sessions.count)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(3)
            }
            
            Spacer()
            
            Button {
                speechManager.stopListening()
                sessionStore.markCurrentCompleted()
                sessionStore.saveSessions()
                feedbackManager.showRecordingStopped()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.bordered)
            .focusable()
            .focused($focusedField, equals: .closeButton)
            .help("Close")
            .keyboardShortcut(.cancelAction)
            .opacity(speechManager.isListening ? 1 : 0)
            .disabled(!speechManager.isListening)
        }
    }
    
    private var transcriptionView: some View {
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
    }
    
    private var buttonRow: some View {
        HStack(spacing: 12) {
            recordButton
            pauseButton
            clearButton
            expandButton
            Spacer()
        }
    }
    
    private var recordButton: some View {
        Button { toggleRecording() } label: {
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
        .buttonStyle(.bordered)
        .focusable()
        .focused($focusedField, equals: .recordButton)
        .help("Record/Stop (⌘R or Space)")
        .keyboardShortcut(.return, modifiers: [])
    }
    
    private var pauseButton: some View {
        Button {
            if speechManager.isListening {
                speechManager.pauseListening()
                feedbackManager.showRecordingPaused()
            } else if speechManager.isPaused {
                do {
                    try speechManager.resumeListening()
                    feedbackManager.showRecordingResumed()
                } catch { }
            }
        } label: {
            Image(systemName: speechManager.isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: 14))
                .foregroundColor(.orange)
        }
        .buttonStyle(.bordered)
        .focusable()
        .focused($focusedField, equals: .pauseButton)
        .help("Pause/Resume (⌘P)")
        .keyboardShortcut("p", modifiers: [.command])
        .disabled(!speechManager.isListening && !speechManager.isPaused)
        .opacity(speechManager.isListening || speechManager.isPaused ? 1 : 0.5)
    }
    
    private var clearButton: some View {
        Button {
            speechManager.clearAndContinue()
            feedbackManager.showInfo("Text cleared")
        } label: {
            Image(systemName: "arrow.counterclockwise.circle")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .buttonStyle(.bordered)
        .focusable()
        .focused($focusedField, equals: .clearButton)
        .help("Clear text (⌘⌫)")
        .keyboardShortcut(.delete, modifiers: [.command])
    }
    
    private var expandButton: some View {
        Button {
            expandToMainOverlay()
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .buttonStyle(.bordered)
        .focusable()
        .help("Expand to main overlay")
    }
    
    private func expandToMainOverlay() {
        NotificationCenter.default.post(
            name: .instantDictationDidActivateOverlay,
            object: nil,
            userInfo: nil
        )
    }
    
    private func toggleRecording() {
        if speechManager.isListening {
            speechManager.stopListening()
            sessionStore.markCurrentCompleted()
            sessionStore.saveSessions()
            feedbackManager.showRecordingStopped()
        } else {
            if sessionStore.currentSession == nil {
                _ = sessionStore.createNewSession()
                feedbackManager.showNewSession()
            }
            speechManager.transcribedText = sessionStore.currentSession?.text ?? ""
            do {
                try speechManager.startListening()
                feedbackManager.showRecordingStarted()
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