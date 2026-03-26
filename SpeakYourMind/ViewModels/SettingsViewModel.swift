import Foundation
import AVFoundation
import Speech
import Combine
import AppKit

/// ViewModel for managing application settings.
/// Coordinates between SettingsView, SpeechManager, and other services.
final class SettingsViewModel: ObservableObject {
    
    // MARK: - Constants
    
    private static let selectedLocaleKey = "selectedLocale"
    private static let useOnDeviceRecognitionKey = "useOnDeviceRecognition"
    private static let useStreamingModeKey = "useStreamingMode"
    private static let autoCapitalizeKey = "autoCapitalize"
    private static let playSoundsKey = "playSounds"
    private static let showIndicatorKey = "showIndicator"
    private static let selectedAudioDeviceIdKey = "selectedAudioDeviceId"
    private static let edgeTriggerEnabledKey = "edgeTriggerEnabled"
    private static let edgeTriggerSensitivityKey = "edgeTriggerSensitivity"
    // Instant dictation behavior
    private static let instantDictationUsesOverlayKey = "instantDictationUsesOverlay"
    private static let autoUpdateClipboardKey = "autoUpdateClipboard"
    private static let autoCopyOnStopKey = "autoCopyOnStop"
    // Ollama
    private static let ollamaEnabledKey = "ollamaEnabled"
    private static let ollamaBaseURLKey = "ollamaBaseURL"
    private static let ollamaSelectedModelKey = "ollamaSelectedModel"
    // Custom Prompts
    private static let customPromptsKey = "customPrompts"
    // Built-in AI style overrides
    private static let builtinStyleOverridesKey = "builtinStyleOverrides"
    
    // MARK: - Published Properties
    
    /// Currently selected speech recognition locale.
    @Published var selectedLocale: Locale {
        didSet {
            UserDefaults.standard.set(selectedLocale.identifier, forKey: Self.selectedLocaleKey)
            // Notify SpeechManager of locale change
            NotificationCenter.default.post(
                name: .speechLocaleDidChange,
                object: nil,
                userInfo: ["locale": selectedLocale]
            )
        }
    }
    
    /// Whether to use on-device speech recognition (faster, more private).
    @Published var useOnDeviceRecognition: Bool {
        didSet {
            UserDefaults.standard.set(useOnDeviceRecognition, forKey: Self.useOnDeviceRecognitionKey)
        }
    }
    
    /// Current injection mode for text injection.
    @Published var injectionMode: InjectionMode {
        didSet {
            UserDefaults.standard.set(injectionMode.rawValue, forKey: Self.useStreamingModeKey)
            // Notify InstantRecordCoordinator
            NotificationCenter.default.post(
                name: .injectionModeDidChange,
                object: nil,
                userInfo: ["mode": injectionMode]
            )
        }
    }
    
    /// Whether to auto-capitalize sentences.
    @Published var autoCapitalize: Bool {
        didSet {
            UserDefaults.standard.set(autoCapitalize, forKey: Self.autoCapitalizeKey)
        }
    }
    
    /// Whether to play sounds on start/stop.
    @Published var playSounds: Bool {
        didSet {
            UserDefaults.standard.set(playSounds, forKey: Self.playSoundsKey)
        }
    }
    
    /// Whether to show recording indicator.
    @Published var showIndicator: Bool {
        didSet {
            UserDefaults.standard.set(showIndicator, forKey: Self.showIndicatorKey)
        }
    }
    
    /// Available locales for speech recognition.
    @Published var availableLocales: [Locale] = []
    
    /// Available audio input devices.
    @Published var availableAudioDevices: [AudioDevice] = []
    
    /// Currently selected audio device.
    @Published var selectedAudioDevice: AudioDevice? {
        didSet {
            if let device = selectedAudioDevice {
                UserDefaults.standard.set(device.id, forKey: Self.selectedAudioDeviceIdKey)
            }
        }
    }
    
    /// Whether on-device recognition is supported for the current locale.
    @Published var supportsOnDeviceRecognition: Bool = false
    
    /// Whether edge trigger overlay is enabled.
    @Published var edgeTriggerEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(edgeTriggerEnabled, forKey: Self.edgeTriggerEnabledKey)
            // Update EdgeTriggerMonitor directly if available
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.edgeTriggerMonitor?.isEnabled = edgeTriggerEnabled
            }
        }
    }
    
    /// Edge sensitivity in pixels for edge trigger.
    @Published var edgeTriggerSensitivity: CGFloat = EdgeTriggerMonitor.defaultEdgeSensitivity {
        didSet {
            UserDefaults.standard.set(edgeTriggerSensitivity, forKey: Self.edgeTriggerSensitivityKey)
            // Update EdgeTriggerMonitor directly if available
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.edgeTriggerMonitor?.edgeSensitivity = edgeTriggerSensitivity
            }
        }
    }
    
    // MARK: - Instant Dictation Behavior Properties

    /// Whether instant dictation routes speech to the overlay panel (true) or injects directly (false).
    @Published var instantDictationUsesOverlay: Bool = true {
        didSet {
            UserDefaults.standard.set(instantDictationUsesOverlay, forKey: Self.instantDictationUsesOverlayKey)
            NotificationCenter.default.post(
                name: .instantDictationBehaviorDidChange,
                object: nil,
                userInfo: ["usesOverlay": instantDictationUsesOverlay]
            )
        }
    }

    /// Whether to automatically update the clipboard with transcribed text during streaming.
    @Published var autoUpdateClipboard: Bool = false {
        didSet {
            UserDefaults.standard.set(autoUpdateClipboard, forKey: Self.autoUpdateClipboardKey)
        }
    }

    /// Whether to automatically copy transcription to clipboard when recording stops.
    @Published var autoCopyOnStop: Bool = false {
        didSet {
            UserDefaults.standard.set(autoCopyOnStop, forKey: Self.autoCopyOnStopKey)
        }
    }

    /// Toggles the instant dictation overlay routing preference.
    func toggleInstantDictationUsesOverlay() {
        instantDictationUsesOverlay.toggle()
    }

    // MARK: - Ollama Properties

    /// Whether Ollama AI features are enabled.
    @Published var ollamaEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(ollamaEnabled, forKey: Self.ollamaEnabledKey)
            if ollamaEnabled {
                Task { await checkConnection() }
            } else {
                ollamaStatus = "Not checked"
            }
        }
    }

    /// Base URL for the Ollama server.
    @Published var ollamaBaseURL: String = "http://localhost:11434" {
        didSet {
            UserDefaults.standard.set(ollamaBaseURL, forKey: Self.ollamaBaseURLKey)
            if let manager = ollamaManager {
                manager.baseURL = ollamaBaseURL
            }
        }
    }

    /// Currently selected Ollama model.
    @Published var ollamaSelectedModel: String = "" {
        didSet {
            UserDefaults.standard.set(ollamaSelectedModel, forKey: Self.ollamaSelectedModelKey)
            if let manager = ollamaManager {
                manager.selectedModel = ollamaSelectedModel
            }
        }
    }

    /// Available Ollama model names.
    @Published var ollamaAvailableModels: [String] = []

    /// Status message for the Ollama connection ("Connected", "Checking…", or an error).
    @Published var ollamaStatus: String = "Not checked"
    
    /// User-friendly status message based on connection status.
    var connectionStatusMessage: String {
        let status = ollamaManager?.connectionStatus ?? .notRunning
        switch status {
        case .notInstalled:
            return "Ollama is not installed. Install from ollama.ai"
        case .notRunning:
            return "Ollama server is not running. Open Ollama app or run 'ollama serve'"
        case .running:
            return "Connected to Ollama server"
        case .error(let message):
            return "Connection error: \(message)"
        }
    }

    /// The shared OllamaManager instance (nil until Ollama features are first used).
    var ollamaManager: OllamaManager?

    // MARK: - Custom Prompts

    /// Custom AI prompts created by the user.
    @Published var customPrompts: [CustomPrompt] = []

    // MARK: - Built-in AI Style Overrides

    /// Per-style system prompt overrides. Key = AIPromptStyle.rawValue, Value = custom system prompt.
    /// Empty string means "use default".
    @Published var builtinStyleOverrides: [String: String] = [:]

    // MARK: - Initialization
    
    init() {
        // Load saved settings
        let savedLocaleIdentifier = UserDefaults.standard.string(forKey: Self.selectedLocaleKey) ?? "en-US"
        self.selectedLocale = Locale(identifier: savedLocaleIdentifier)
        
        self.useOnDeviceRecognition = UserDefaults.standard.bool(forKey: Self.useOnDeviceRecognitionKey)
        
        // Load injection mode from UserDefaults or use default
        if let modeString = UserDefaults.standard.string(forKey: Self.useStreamingModeKey),
           let mode = InjectionMode(rawValue: modeString) {
            self.injectionMode = mode
        } else {
            self.injectionMode = .streaming
        }
        
        self.autoCapitalize = UserDefaults.standard.object(forKey: Self.autoCapitalizeKey) as? Bool ?? true
        self.playSounds = UserDefaults.standard.object(forKey: Self.playSoundsKey) as? Bool ?? true
        self.showIndicator = UserDefaults.standard.object(forKey: Self.showIndicatorKey) as? Bool ?? true
        
        // Load edge trigger settings
        self.edgeTriggerEnabled = UserDefaults.standard.object(forKey: Self.edgeTriggerEnabledKey) as? Bool ?? false
        self.edgeTriggerSensitivity = UserDefaults.standard.object(forKey: Self.edgeTriggerSensitivityKey) as? CGFloat ?? EdgeTriggerMonitor.defaultEdgeSensitivity
        
        // Load instant dictation behavior settings
        self.instantDictationUsesOverlay = UserDefaults.standard.object(forKey: Self.instantDictationUsesOverlayKey) as? Bool ?? true
        self.autoUpdateClipboard = UserDefaults.standard.object(forKey: Self.autoUpdateClipboardKey) as? Bool ?? false
        self.autoCopyOnStop = UserDefaults.standard.object(forKey: Self.autoCopyOnStopKey) as? Bool ?? false
        
        // Load Ollama settings
        self.ollamaEnabled = UserDefaults.standard.object(forKey: Self.ollamaEnabledKey) as? Bool ?? false
        self.ollamaBaseURL = UserDefaults.standard.string(forKey: Self.ollamaBaseURLKey) ?? "http://localhost:11434"
        self.ollamaSelectedModel = UserDefaults.standard.string(forKey: Self.ollamaSelectedModelKey) ?? ""
        
        // Load custom prompts
        loadCustomPrompts()
        loadBuiltinStyleOverrides()
        
        // Load available locales and devices
        loadAvailableLocales()
        loadAvailableAudioDevices()
        
        // Initialize OllamaManager
        let manager = OllamaManager(baseURL: self.ollamaBaseURL, selectedModel: self.ollamaSelectedModel)
        self.ollamaManager = manager
        
        // Auto-check connection if enabled
        if ollamaEnabled {
            Task {
                await checkConnection()
                if case .running = ollamaManager?.connectionStatus {
                    refreshOllamaModels()
                }
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Refreshes the list of available audio devices.
    func refreshAudioDevices() {
        loadAvailableAudioDevices()
    }
    
    /// Refreshes on-device recognition support for current locale.
    func refreshOnDeviceSupport() {
        supportsOnDeviceRecognition = SpeechManager.supportsOnDeviceRecognition(for: selectedLocale)
    }

    /// Checks Ollama connection status and updates published properties.
    @MainActor
    func checkConnection() async {
        guard let manager = ollamaManager else { return }
        ollamaStatus = "Checking…"
        let status = await manager.checkConnection()
        manager.connectionStatus = status
        ollamaStatus = connectionStatusMessage
    }
    
    /// Manually refreshes connection status.
    @MainActor
    func refreshConnectionStatus() async {
        guard let manager = ollamaManager else { return }
        ollamaStatus = "Checking…"
        let status = await manager.checkConnection()
        manager.connectionStatus = status
        ollamaStatus = connectionStatusMessage
    }
    
    /// Fetches available models from the Ollama server and updates status.
    /// Checks connection status before fetching.
    func refreshOllamaModels() {
        guard let manager = ollamaManager else { return }
        manager.baseURL = ollamaBaseURL
        
        Task {
            await refreshConnectionStatus()
            
            guard case .running = manager.connectionStatus else {
                ollamaStatus = connectionStatusMessage
                return
            }
            
            ollamaStatus = "Fetching models…"
            manager.fetchAvailableModels { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let models):
                    self.ollamaAvailableModels = models
                    self.ollamaStatus = models.isEmpty ? "Connected (no models)" : "Connected"
                    // Auto-select first model if none selected
                    if self.ollamaSelectedModel.isEmpty, let first = models.first {
                        self.ollamaSelectedModel = first
                    }
                case .failure(let error):
                    self.ollamaAvailableModels = []
                    self.ollamaStatus = "Error: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Custom Prompts Methods

    /// Adds a new custom prompt.
    func addCustomPrompt(_ prompt: CustomPrompt) {
        customPrompts.append(prompt)
        saveCustomPrompts()
    }

    /// Deletes a custom prompt by ID.
    func deleteCustomPrompt(_ id: UUID) {
        customPrompts.removeAll { $0.id == id }
        saveCustomPrompts()
    }

    /// Edits an existing custom prompt.
    func editCustomPrompt(_ id: UUID, newName: String, newInstruction: String, newSystemPrompt: String = "") {
        if let index = customPrompts.firstIndex(where: { $0.id == id }) {
            customPrompts[index].name = newName
            customPrompts[index].instruction = newInstruction
            customPrompts[index].systemPrompt = newSystemPrompt
            saveCustomPrompts()
        }
    }

    private func loadCustomPrompts() {
        guard let data = UserDefaults.standard.data(forKey: Self.customPromptsKey),
              let prompts = try? JSONDecoder().decode([CustomPrompt].self, from: data) else {
            customPrompts = []
            return
        }
        customPrompts = prompts
    }

    private func saveCustomPrompts() {
        guard let data = try? JSONEncoder().encode(customPrompts) else { return }
        UserDefaults.standard.set(data, forKey: Self.customPromptsKey)
    }

    // MARK: - Built-in AI Style Override Methods

    /// Returns the effective system prompt for a built-in style (user override or default).
    func effectiveSystemPrompt(for style: AIPromptStyle) -> String {
        if let override = builtinStyleOverrides[style.rawValue],
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return override
        }
        return style.systemPrompt
    }

    /// Sets a user override for a built-in style's system prompt.
    /// Pass empty string to revert to the default.
    func setBuiltinStyleOverride(_ style: AIPromptStyle, systemPrompt: String) {
        builtinStyleOverrides[style.rawValue] = systemPrompt
        saveBuiltinStyleOverrides()
    }

    /// Resets a built-in style's system prompt to its default.
    func resetBuiltinStyleToDefault(_ style: AIPromptStyle) {
        builtinStyleOverrides.removeValue(forKey: style.rawValue)
        saveBuiltinStyleOverrides()
    }

    /// Whether a built-in style has a user override.
    func hasOverride(for style: AIPromptStyle) -> Bool {
        guard let override = builtinStyleOverrides[style.rawValue] else { return false }
        return !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func loadBuiltinStyleOverrides() {
        guard let data = UserDefaults.standard.data(forKey: Self.builtinStyleOverridesKey),
              let overrides = try? JSONDecoder().decode([String: String].self, from: data) else {
            builtinStyleOverrides = [:]
            return
        }
        builtinStyleOverrides = overrides
    }

    private func saveBuiltinStyleOverrides() {
        guard let data = try? JSONEncoder().encode(builtinStyleOverrides) else { return }
        UserDefaults.standard.set(data, forKey: Self.builtinStyleOverridesKey)
    }

    // MARK: - Private Methods
    
    private func loadAvailableLocales() {
        availableLocales = SpeechManager.availableLocales
    }
    
    private func loadAvailableAudioDevices() {
        var devices: [AudioDevice] = []
        
        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        _ = inputNode.audioUnit
        
        // Get device IDs using AudioObjectGetPropertyData
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        
        guard status == noErr else {
            Logger.shared.error("Failed to get audio devices size: \(status)")
            // Fallback: add default device
            devices.append(AudioDevice(id: "default", name: "Default Microphone"))
            availableAudioDevices = devices
            return
        }
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )
        
        guard status == noErr else {
            Logger.shared.error("Failed to get audio devices: \(status)")
            devices.append(AudioDevice(id: "default", name: "Default Microphone"))
            availableAudioDevices = devices
            return
        }
        
        // Filter for input devices and get their names
        for deviceID in deviceIDs {
            // Check if device has input channels
            var inputPropertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            
            var inputDataSize: UInt32 = 0
            status = AudioObjectGetPropertyDataSize(deviceID, &inputPropertyAddress, 0, nil, &inputDataSize)
            
            guard status == noErr, inputDataSize > 0 else { continue }
            
            let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
            defer { bufferListPointer.deallocate() }
            
            status = AudioObjectGetPropertyData(deviceID, &inputPropertyAddress, 0, nil, &inputDataSize, bufferListPointer)
            
            guard status == noErr else { continue }
            
            let bufferList = bufferListPointer.pointee
            let inputChannels = bufferList.mNumberBuffers > 0 ? bufferList.mBuffers.mNumberChannels : 0
            
            guard inputChannels > 0 else { continue }
            
            // Get device name
            var namePropertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            var name: CFString = "" as CFString
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            
            status = AudioObjectGetPropertyData(deviceID, &namePropertyAddress, 0, nil, &nameSize, &name)
            
            let deviceName = status == noErr ? name as String : "Unknown Device"
            let deviceIDString = String(deviceID)
            
            devices.append(AudioDevice(id: deviceIDString, name: deviceName))
        }
        
        if devices.isEmpty {
            devices.append(AudioDevice(id: "default", name: "Default Microphone"))
        }
        
        availableAudioDevices = devices
        
        // Restore saved selection or default to first
        let savedDeviceId = UserDefaults.standard.string(forKey: Self.selectedAudioDeviceIdKey)
        if let savedId = savedDeviceId, let device = devices.first(where: { $0.id == savedId }) {
            selectedAudioDevice = device
        } else {
            selectedAudioDevice = devices.first
        }
    }
}

// MARK: - Audio Device Model

/// Represents an audio input device.
struct AudioDevice: Identifiable, Hashable {
    let id: String
    let name: String
}