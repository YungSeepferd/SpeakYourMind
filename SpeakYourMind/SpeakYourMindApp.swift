import SwiftUI
import KeyboardShortcuts
import Combine

/// Full AppDelegate wiring: menu bar icon, overlay panel, instant-record coordinator, hotkeys.
class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem!
    var overlayPanel: OverlayPanel!
    var instantCoordinator: InstantRecordCoordinator!
    var edgeTriggerMonitor: EdgeTriggerMonitor!
    var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    
    /// Shared settings view model for the app.
    static var sharedSettingsViewModel: SettingsViewModel!

    /// Shared OllamaManager instance, initialized alongside the SettingsViewModel.
    static var sharedOllamaManager: OllamaManager!

    /// Shared SpeechManager instance used by both MainView and EdgeTriggerMonitor.
    /// Design decision: We use a single shared instance because the overlay and edge
    /// trigger overlay represent the same recording session - they must share state
    /// (isListening, transcribedText, etc.) to provide a consistent UX. Creating separate
    /// instances would cause the two UIs to show divergent state, confusing the user.
    static var sharedSpeechManager: SpeechManager!

    /// Shared RecordingSessionStore instance used by both MainView and EdgeTriggerMonitor.
    /// Same rationale as sharedSpeechManager: sessions are global to the app, not per-view.
    static var sharedSessionStore: RecordingSessionStore!

    // MARK: - Lifecycle

    func applicationWillTerminate(_ notification: Notification) {
        Task {
            await AuditLogger.shared.info(
                category: .lifecycle,
                eventType: .appQuit,
                message: "SpeakYourMind terminating"
            )
        }
        edgeTriggerMonitor?.stopMonitoring()
    }

    /// Dock icon click — open the overlay panel.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        toggleOverlay()
        return true
    }
    
    /// App unhidden from dock — open the overlay panel.
    func applicationDidUnhide(_ notification: Notification) {
        toggleOverlay()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            await AuditLogger.shared.info(
                category: .lifecycle,
                eventType: .appLaunch,
                message: "SpeakYourMind launched"
            )
        }
        
        // Initialize shared settings view model
        AppDelegate.sharedSettingsViewModel = SettingsViewModel()
        
        // Share the OllamaManager created by SettingsViewModel
        AppDelegate.sharedOllamaManager = AppDelegate.sharedSettingsViewModel.ollamaManager
        
        // Initialize shared SpeechManager and RecordingSessionStore
        // These are shared between MainView and EdgeTriggerMonitor for consistent state
        AppDelegate.sharedSpeechManager = SpeechManager()
        AppDelegate.sharedSessionStore = RecordingSessionStore()
        
        setupMenuBarItem()
        setupOverlayPanel()
        setupInstantRecord()
        setupEdgeTriggerMonitor()
        registerHotkeys()
        
        // Open overlay on app launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.overlayPanel.center()
            self?.overlayPanel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private var statusMenu: NSMenu!
    private var auditLogWindow: NSWindow?

    // MARK: - Menu Bar

    private func setupMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        updateStatusItemIcon(isListening: false, hasError: false)

        // Left-click toggles overlay, right-click shows context menu.
        // Do NOT assign statusItem.menu — that overrides the button action entirely.
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        statusMenu = NSMenu()
        statusMenu.addItem(NSMenuItem(title: "Open Overlay",
                                action: #selector(toggleOverlay),
                                keyEquivalent: ""))
        statusMenu.addItem(.separator())
        statusMenu.addItem(NSMenuItem(title: "Settings…",
                                action: #selector(openSettings),
                                keyEquivalent: ","))
        statusMenu.addItem(NSMenuItem(title: "View Audit Logs",
                                action: #selector(openAuditLogViewer),
                                keyEquivalent: "l"))
        statusMenu.addItem(.separator())
        statusMenu.addItem(NSMenuItem(title: "Quit SpeakYourMind",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            // Show context menu on right-click
            statusItem.menu = statusMenu
            statusItem.button?.performClick(nil)
            // Reset to nil so the next left-click fires our action again
            statusItem.menu = nil
        } else {
            toggleOverlay()
        }
    }

    /// Updates the menu bar icon based on recording state.
    /// - Parameters:
    ///   - isListening: Whether speech recognition is currently active.
    ///   - hasError: Whether there is an error condition to display.
    func updateStatusItemIcon(isListening: Bool, hasError: Bool) {
        guard let button = statusItem.button else { return }

        if hasError {
            // Error state: orange triangle
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill",
                                   accessibilityDescription: "SpeakYourMind - Error")
            button.contentTintColor = .systemOrange
        } else if isListening {
            // Recording state: red mic
            button.image = NSImage(systemSymbolName: "mic.fill",
                                   accessibilityDescription: "SpeakYourMind - Recording")
            button.contentTintColor = .systemRed
        } else {
            // Idle state: standard mic
            button.image = NSImage(systemSymbolName: "mic.badge.plus",
                                   accessibilityDescription: "SpeakYourMind")
            button.contentTintColor = nil
        }
    }

    // MARK: - Overlay Panel

    private func setupOverlayPanel() {
        overlayPanel = OverlayPanel()
        let viewModel = OverlayViewModel(
            speechManager: AppDelegate.sharedSpeechManager,
            sessionStore: AppDelegate.sharedSessionStore
        )
        let mainView = MainView(
            speechManager: AppDelegate.sharedSpeechManager,
            sessionStore: AppDelegate.sharedSessionStore,
            viewModel: viewModel,
            ollamaManager: AppDelegate.sharedOllamaManager,
            settingsViewModel: AppDelegate.sharedSettingsViewModel
        )
        let hostingView = NSHostingController(rootView: mainView)
        overlayPanel.contentViewController = hostingView
        
        // Set initial window size to match view model's loaded size
        let initialSize = viewModel.overlaySize.contentSize
        var initialFrame = overlayPanel.frame
        let newInitialRect = overlayPanel.frameRect(forContentRect: NSRect(origin: .zero, size: initialSize))
        initialFrame.size = newInitialRect.size
        overlayPanel.setFrame(initialFrame, display: true)
        
        // Observe window size changes
        NotificationCenter.default.publisher(for: .symOverlaySizeDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let newSize = notification.object as? OverlaySize else { return }
                
                let targetSize = newSize.contentSize
                
                var frame = self.overlayPanel.frame
                let newFrameRect = self.overlayPanel.frameRect(forContentRect: NSRect(origin: .zero, size: targetSize))
                
                // Adjust origin to keep panel centered horizontally and anchored at the top
                frame.origin.y += frame.height - newFrameRect.height
                frame.origin.x += (frame.width - newFrameRect.width) / 2
                frame.size = newFrameRect.size
                
                self.overlayPanel.setFrame(frame, display: true, animate: true)
            }
            .store(in: &cancellables)
        
        // Observe recording state changes to update menu bar icon
        AppDelegate.sharedSpeechManager.$isListening
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isListening in
                self?.updateStatusItemIcon(isListening: isListening, hasError: false)
            }
            .store(in: &cancellables)
    }

    @objc func toggleOverlay() {
        if overlayPanel.isVisible {
            overlayPanel.orderOut(nil)
        } else {
            overlayPanel.center()
            overlayPanel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Instant Record

    private func setupInstantRecord() {
        instantCoordinator = InstantRecordCoordinator()
        instantCoordinator.statusItemButton = statusItem.button
    }

    /// Handles a finalized speech result from instant dictation.
    ///
    /// Injects the transcribed text into the focused field only when:
    /// - The instant record coordinator is actively recording (`isRecording == true`)
    /// - Direct injection mode is selected (`instantDictationUsesOverlay == false`)
    /// - The overlay panel is **not** currently visible (`overlayPanel.isVisible == false`)
    ///
    /// The final guard (`!overlayPanel.isVisible`) is a defensive check: even if
    /// `isRecording` is erroneously `true` during overlay-mode instant dictation,
    /// injection will still be blocked while the overlay is on screen.
    func handleSpeechResult(_ text: String) {
        Logger.shared.debug("handleSpeechResult: isRecording=\(instantCoordinator.isRecording), usesOverlay=\(instantCoordinator.instantDictationUsesOverlay), overlayVisible=\(overlayPanel.isVisible)")
        // Defensive check: never inject when overlay is visible
        if overlayPanel.isVisible {
            Logger.shared.debug("Suppressing direct injection - overlay is visible")
            return
        }
        if instantCoordinator.isRecording && !instantCoordinator.instantDictationUsesOverlay && !overlayPanel.isVisible {
            _ = instantCoordinator.textInjector.inject(text)
        }
    }

    // MARK: - Edge Trigger Monitor

    private func setupEdgeTriggerMonitor() {
        edgeTriggerMonitor = EdgeTriggerMonitor()
        edgeTriggerMonitor.speechManager = AppDelegate.sharedSpeechManager
        edgeTriggerMonitor.sessionStore = AppDelegate.sharedSessionStore
        // Start monitoring if enabled (loads from UserDefaults)
        if edgeTriggerMonitor.isEnabled {
            edgeTriggerMonitor.startMonitoring()
        }
    }

    // MARK: - Hotkeys

    private func registerHotkeys() {
        KeyboardShortcuts.onKeyUp(for: .openOverlay) { [weak self] in
            self?.toggleOverlay()
        }

        // Regular hotkey (if user sets a non-modifier shortcut)
        KeyboardShortcuts.onKeyDown(for: .instantRecord) { [weak self] in
            self?.instantCoordinator.toggle()
        }
        
        // Modifier-only hotkey (⌃⌥⌘) - start recording immediately on trigger
        ModifierOnlyHotkeyMonitor.shared.onTrigger = { [weak self] in
            self?.instantCoordinator.toggle()
        }
        ModifierOnlyHotkeyMonitor.shared.start()
    }

    // MARK: - Settings

    @objc func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView(viewModel: AppDelegate.sharedSettingsViewModel)
            let hostingController = NSHostingController(rootView: settingsView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "SpeakYourMind Settings"
            window.styleMask = [.titled, .closable]
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func openAuditLogViewer() {
        if auditLogWindow == nil {
            let viewerView = AuditLogViewerView()
            let hostingController = NSHostingController(rootView: viewerView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Audit Logs"
            window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
            window.center()
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 700, height: 500)
            auditLogWindow = window
        }
        auditLogWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - App Entry Point

@main
struct SpeakYourMindApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}