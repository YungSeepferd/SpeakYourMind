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

    // MARK: - Lifecycle

    func applicationWillTerminate(_ notification: Notification) {
        edgeTriggerMonitor?.stopMonitoring()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize shared settings view model
        AppDelegate.sharedSettingsViewModel = SettingsViewModel()
        
        // Share the OllamaManager created by SettingsViewModel
        AppDelegate.sharedOllamaManager = AppDelegate.sharedSettingsViewModel.ollamaManager
        
        setupMenuBarItem()
        setupOverlayPanel()
        setupInstantRecord()
        setupEdgeTriggerMonitor()
        registerHotkeys()
    }

    // MARK: - Menu Bar

    private func setupMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        updateStatusItemIcon(isListening: false, hasError: false)

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Overlay",
                                action: #selector(toggleOverlay),
                                keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings…",
                                action: #selector(openSettings),
                                keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit SpeakYourMind",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem.menu = menu
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
        let mainView = MainView(ollamaManager: AppDelegate.sharedOllamaManager,
                                settingsViewModel: AppDelegate.sharedSettingsViewModel)
        let hostingView = NSHostingController(rootView: mainView)
        overlayPanel.contentViewController = hostingView
        
        // Observe recording state changes to update menu bar icon
        mainView.speechManager.$isListening
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

    // MARK: - Edge Trigger Monitor

    private func setupEdgeTriggerMonitor() {
        edgeTriggerMonitor = EdgeTriggerMonitor()
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

        KeyboardShortcuts.onKeyDown(for: .instantRecord) { [weak self] in
            self?.instantCoordinator.toggle()
        }
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