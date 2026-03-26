import Foundation
import Speech
import AVFoundation
import AppKit

/// Errors that can occur during speech recognition.
enum SpeechError: LocalizedError, Equatable {
    case microphoneUnavailable
    case microphoneDenied
    case microphoneRestricted
    case speechRecognitionDenied
    case speechRecognitionRestricted
    case recognitionFailed(underlying: Error?)
    case audioEngineFailed(underlying: Error?)
    case notAvailable(reason: String)
    
    static func == (lhs: SpeechError, rhs: SpeechError) -> Bool {
        switch (lhs, rhs) {
        case (.microphoneUnavailable, .microphoneUnavailable),
             (.microphoneDenied, .microphoneDenied),
             (.microphoneRestricted, .microphoneRestricted),
             (.speechRecognitionDenied, .speechRecognitionDenied),
             (.speechRecognitionRestricted, .speechRecognitionRestricted):
            return true
        case (.recognitionFailed, .recognitionFailed),
             (.audioEngineFailed, .audioEngineFailed),
             (.notAvailable, .notAvailable):
            return true
        default:
            return false
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .microphoneUnavailable:
            return "Microphone access is not available. Please enable it in System Settings > Privacy & Security > Microphone."
        case .microphoneDenied:
            return "Microphone access was denied. Please enable it in System Settings > Privacy & Security > Microphone."
        case .microphoneRestricted:
            return "Microphone access is restricted by system policy. Contact your administrator for assistance."
        case .speechRecognitionDenied:
            return "Speech recognition permission was denied. Please enable it in System Settings > Privacy & Security > Speech Recognition."
        case .speechRecognitionRestricted:
            return "Speech recognition is restricted by system policy. Contact your administrator for assistance."
        case .recognitionFailed(let underlying):
            if let error = underlying {
                return "Speech recognition failed: \(error.localizedDescription)"
            }
            return "Speech recognition failed for an unknown reason."
        case .audioEngineFailed(let underlying):
            if let error = underlying {
                return "Audio engine failed to start: \(error.localizedDescription)"
            }
            return "Audio engine failed to start for an unknown reason."
        case .notAvailable(let reason):
            return "Speech recognition is not available: \(reason)"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .microphoneUnavailable:
            return "The microphone is not available on this device."
        case .microphoneDenied:
            return "Microphone access has been denied by the user."
        case .microphoneRestricted:
            return "Microphone access is restricted by a system profile or MDM policy."
        case .speechRecognitionDenied:
            return "Speech recognition permission has been denied by the user."
        case .speechRecognitionRestricted:
            return "Speech recognition is restricted by a system profile or MDM policy."
        case .recognitionFailed:
            return "The speech recognition task encountered an error."
        case .audioEngineFailed:
            return "The audio engine failed to start or was interrupted."
        case .notAvailable(let reason):
            return reason
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .microphoneUnavailable:
            return "Check that a microphone is connected and enabled in System Settings."
        case .microphoneDenied:
            return "Open System Settings > Privacy & Security > Microphone and enable access for this app."
        case .microphoneRestricted:
            return "Contact your system administrator to enable microphone access."
        case .speechRecognitionDenied:
            return "Open System Settings > Privacy & Security > Speech Recognition and enable access for this app."
        case .speechRecognitionRestricted:
            return "Contact your system administrator to enable speech recognition."
        case .recognitionFailed:
            return "Try speaking more clearly or check your microphone. If the problem persists, restart the app."
        case .audioEngineFailed:
            return "Try closing other audio apps and restart the app."
        case .notAvailable:
            return "Please ensure all required permissions are granted and try again."
        }
    }
    
    /// Maps AVCaptureDevice authorization status to appropriate SpeechError.
    static func fromMicrophoneStatus(_ status: AVAuthorizationStatus) -> SpeechError {
        switch status {
        case .denied:
            return .microphoneDenied
        case .restricted:
            return .microphoneRestricted
        case .notDetermined:
            return .microphoneUnavailable
        case .authorized:
            return .microphoneUnavailable
        @unknown default:
            return .microphoneUnavailable
        }
    }
    
    /// Maps SFSpeechRecognizer authorization status to appropriate SpeechError.
    static func fromSpeechRecognitionStatus(_ status: SFSpeechRecognizerAuthorizationStatus) -> SpeechError {
        switch status {
        case .denied:
            return .speechRecognitionDenied
        case .restricted:
            return .speechRecognitionRestricted
        case .notDetermined:
            return .notAvailable(reason: "Speech recognition not determined")
        case .authorized:
            return .notAvailable(reason: "Speech recognition authorized but other issue")
        @unknown default:
            return .notAvailable(reason: "Unknown speech recognition status")
        }
    }
}

/// Handles microphone capture and live speech-to-text via Apple's Speech framework.
/// 
/// This class manages the audio engine for capturing microphone input and uses Apple's
/// Speech framework to perform real-time speech recognition. It publishes transcription
/// results and manages the recognition lifecycle.
final class SpeechManager: NSObject, ObservableObject {

    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer!

    /// Whether speech recognition and microphone access have been authorized.
    @Published var isAvailable = false
    
    /// Current microphone permission status.
    @Published var microphoneStatus: PermissionStatus = .notDetermined
    
    /// Current speech recognition permission status.
    @Published var speechRecognitionStatus: PermissionStatus = .notDetermined
    
    /// Whether the audio engine is currently capturing and processing speech.
    @Published var isListening = false
    
    /// Whether recording is currently paused (paused mid-session).
    @Published var isPaused = false
    
    /// The current transcribed text from speech recognition.
    @Published var transcribedText = ""
    
    /// The current partial transcribed text from speech recognition (streaming mode).
    @Published var partialText = ""
    
    /// The current speech recognition locale.
    @Published var currentLanguage: Locale = Locale(identifier: "en-US")
    
    /// Available locales for speech recognition (from SFSpeechRecognizer.supportedLocales).
    var availableLanguages: [Locale] {
        Self.availableLocales
    }
    
    /// The last error that occurred during speech recognition.
    @Published var lastError: SpeechError?
    
    /// Recording start time for duration tracking.
    private var recordingStartTime: Date?
    
    /// Current recording duration in seconds.
    @Published var recordingDuration: TimeInterval = 0
    
    /// Timer for updating duration during recording.
    private var durationTimer: Timer?
    
    /// Paused time offset for duration tracking.
    private var pausedTimeOffset: TimeInterval = 0

    /// Callback invoked when speech recognition produces a final result.
    /// 
    /// - Parameter text: The final transcribed text string.
    var onFinalResult: ((String) -> Void)?
    
    /// Callback invoked when speech recognition produces partial results.
    /// 
    /// - Parameter text: The partial transcribed text string.
    var onPartialResult: ((String) -> Void)?
    
    /// Callback invoked when an error occurs during speech recognition.
    /// 
    /// - Parameter error: The SpeechError that occurred.
    var onError: ((SpeechError) -> Void)?

    override init() {
        super.init()
        speechRecognizer = SFSpeechRecognizer(locale: currentLanguage)!
        
        // Listen for locale changes from SettingsViewModel
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLocaleChange(_:)),
            name: .speechLocaleDidChange,
            object: nil
        )
        
        // Check permissions asynchronously on init
        Task {
            await checkAndRequestPermissions()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleLocaleChange(_ notification: Notification) {
        if let locale = notification.userInfo?["locale"] as? Locale {
            setLocale(locale)
        }
    }
    
    // MARK: - Language Management
    
    /// Sets the speech recognition locale and reinitializes the recognizer.
    /// Preserves transcribed text during language switch.
    /// - Parameter locale: The locale to use for speech recognition.
    func setLanguage(_ locale: Locale) {
        Logger.shared.info("Setting language to: \(locale.identifier)")
        
        // Preserve transcribed text
        let preservedText = transcribedText
        
        // Stop current recognition if active
        if isListening {
            stopListening()
        }
        
        // Create new recognizer with the specified locale
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        currentLanguage = locale
        
        // Update on-device support status
        supportsOnDeviceRecognition = Self.supportsOnDeviceRecognition(for: locale)
        
        // Restore transcribed text
        transcribedText = preservedText
    }
    
    /// Sets the speech recognition locale and recreates the recognizer.
    /// - Parameter locale: The locale to use for speech recognition.
    /// - Deprecated: Use setLanguage(_:) instead.
    func setLocale(_ locale: Locale) {
        setLanguage(locale)
    }
    
    /// Whether on-device speech recognition is supported for the current locale.
    /// On-device recognition is faster and more private, but may not be available for all locales.
    var supportsOnDeviceRecognition: Bool = false
    
    /// Returns whether on-device speech recognition is supported for the given locale.
    /// - Parameter locale: The locale to check.
    /// - Returns: True if on-device recognition is available.
    static func supportsOnDeviceRecognition(for locale: Locale) -> Bool {
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            return false
        }
        return recognizer.supportsOnDeviceRecognition
    }
    
    /// Returns all available locales for speech recognition.
    /// - Returns: Array of available Locale objects sorted by display name.
    static var availableLocales: [Locale] {
        guard let recognizers = SFSpeechRecognizer.supportedLocales() as? Set<Locale> else {
            return [Locale(identifier: "en-US")]
        }
        return recognizers.sorted { $0.localizedString(forIdentifier: $0.identifier) ?? $0.identifier < $1.localizedString(forIdentifier: $1.identifier) ?? $1.identifier }
    }

    // MARK: - Permissions

    /// Checks and requests all required permissions (microphone and speech recognition).
    /// Uses async/await with withCheckedContinuation for the callback-based APIs.
    /// 
    /// - Returns: True if both microphone and speech recognition permissions are granted.
    func checkAndRequestPermissions() async -> Bool {
        // Check speech recognition permission
        let speechStatus = await checkSpeechRecognitionPermission()
        speechRecognitionStatus = speechStatus
        
        // Request speech recognition if not determined
        if speechStatus == .notDetermined {
            let newStatus = await requestSpeechRecognitionPermission()
            speechRecognitionStatus = newStatus
        }
        
        // Check microphone permission
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio).permissionStatus
        microphoneStatus = micStatus
        
        // Request microphone permission if not determined
        if micStatus == .notDetermined {
            let granted = await requestMicrophonePermission()
            microphoneStatus = granted ? .authorized : .denied
        }
        
        // Update isAvailable based on final status
        isAvailable = microphoneStatus == .authorized && speechRecognitionStatus == .authorized
        
        return isAvailable
    }
    
    /// Checks current speech recognition permission status using async/await.
    private func checkSpeechRecognitionPermission() async -> PermissionStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status.permissionStatus)
            }
        }
    }
    
    /// Requests speech recognition permission using async/await.
    private func requestSpeechRecognitionPermission() async -> PermissionStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status.permissionStatus)
            }
        }
    }
    
    /// Requests microphone permission using async/await.
    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Legacy synchronous permission request (kept for backward compatibility).
    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.speechRecognitionStatus = status.permissionStatus
                self?.isAvailable = status == .authorized
            }
        }

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            microphoneStatus = .authorized
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.microphoneStatus = granted ? .authorized : .denied
                    if !granted {
                        self?.isAvailable = false
                    }
                }
            }
        case .denied:
            microphoneStatus = .denied
            DispatchQueue.main.async { self.isAvailable = false }
        case .restricted:
            microphoneStatus = .restricted
            DispatchQueue.main.async { self.isAvailable = false }
        @unknown default:
            microphoneStatus = .denied
            DispatchQueue.main.async { self.isAvailable = false }
        }
    }

    // MARK: - Recording

    /// Starts capturing audio and performing speech recognition.
    /// 
    /// Initializes the audio engine and begins the recognition task. If permissions
    /// are not granted, this method has no effect.
    /// 
    /// - Throws: SpeechError if microphone is unavailable or audio engine fails to start.
    func startListening() throws {
        guard isAvailable, !isListening else { return }
        
        // Check microphone authorization
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        guard micStatus == .authorized else {
            let error = SpeechError.microphoneUnavailable
            Task {
                await AuditLogger.shared.error(
                    category: .speech,
                    eventType: .startRecording,
                    message: "Microphone authorization failed",
                    metadata: ["status": micStatus.rawValue.description]
                )
            }
            onError?(error)
            throw error
        }
        
        Task {
            await AuditLogger.shared.info(
                category: .speech,
                eventType: .startRecording,
                message: "Recording started",
                metadata: ["locale": String(currentLanguage.identifier)]
            )
        }

        // Cancel any lingering task
        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let transcription = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.transcribedText = transcription
                    // Handle partial results
                    if !result.isFinal {
                        self.partialText = transcription
                        self.onPartialResult?(transcription)
                    }
                }
                if result.isFinal {
                    DispatchQueue.main.async {
                        self.onFinalResult?(transcription)
                    }
                }
            }

            if let error = error {
                let speechError = SpeechError.recognitionFailed(underlying: error)
                Logger.shared.error("Recognition error: \(error)")
                DispatchQueue.main.async { [weak self] in
                    self?.onError?(speechError)
                }
            }
            
            if error != nil || (result?.isFinal == true) {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                DispatchQueue.main.async { self.isListening = false }
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
            recordingStartTime = Date()
            startDurationTimer()
            if UserDefaults.standard.bool(forKey: "playSounds") {
                NSSound(named: "Tink")?.play()
            }
        } catch {
            let error = SpeechError.audioEngineFailed(underlying: error)
            Logger.shared.error("Audio engine failed to start: \(error)")
            onError?(error)
            throw error
        }
    }
    
    private func startDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.recordingStartTime else { return }
            self.recordingDuration = Date().timeIntervalSince(start)
        }
    }
    
    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }

    /// Stops capturing audio and halts speech recognition.
    /// 
    /// Ends the current recognition session gracefully by stopping the audio engine
    /// and signaling end of audio to the recognition request.
    func stopListening() {
        guard isListening else { return }
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isListening = false
        isPaused = false
        stopDurationTimer()
        recordingStartTime = nil
        pausedTimeOffset = 0
        
        Task {
            await AuditLogger.shared.info(
                category: .speech,
                eventType: .stopRecording,
                message: "Recording stopped",
                metadata: ["duration": String(format: "%.1f", recordingDuration)]
            )
        }
        
        if UserDefaults.standard.bool(forKey: "playSounds") {
            NSSound(named: "Pop")?.play()
        }
    }
    
    /// Pauses recording while preserving transcribed text.
    /// Call resumeListening() to continue the same session.
    func pauseListening() {
        guard isListening && !isPaused else { return }
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isPaused = true
        isListening = false
        pausedTimeOffset = recordingDuration
        stopDurationTimer()
        
        Task {
            await AuditLogger.shared.info(
                category: .speech,
                eventType: .pauseRecording,
                message: "Recording paused",
                metadata: ["offset": String(format: "%.1f", pausedTimeOffset)]
            )
        }
        
        Logger.shared.info("Recording paused at \(pausedTimeOffset)s")
    }
    
    /// Resumes recording after pause, preserving transcribed text.
    /// Continues the same recording session from where it left off.
    func resumeListening() throws {
        guard isPaused else { return }
        
        // Check microphone authorization
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        guard micStatus == .authorized else {
            let error = SpeechError.microphoneUnavailable
            Task {
                await AuditLogger.shared.error(
                    category: .speech,
                    eventType: .resumeRecording,
                    message: "Microphone authorization failed on resume",
                    metadata: ["status": micStatus.rawValue.description]
                )
            }
            onError?(error)
            throw error
        }
        
        Task {
            await AuditLogger.shared.info(
                category: .speech,
                eventType: .resumeRecording,
                message: "Recording resumed",
                metadata: ["offset": String(format: "%.1f", pausedTimeOffset)]
            )
        }
        
        // Cancel any lingering task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(macOS 13, *) {
            request.addsPunctuation = true
        }
        recognitionRequest = request
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            
            if let result {
                let transcription = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.transcribedText = transcription
                    if !result.isFinal {
                        self.partialText = transcription
                        self.onPartialResult?(transcription)
                    }
                }
                if result.isFinal {
                    DispatchQueue.main.async {
                        self.onFinalResult?(transcription)
                    }
                }
            }
            
            if let error = error {
                let speechError = SpeechError.recognitionFailed(underlying: error)
                Logger.shared.error("Recognition error: \(error)")
                DispatchQueue.main.async { [weak self] in
                    self?.onError?(speechError)
                }
            }
            
            if error != nil || (result?.isFinal == true) {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                DispatchQueue.main.async {
                    self.isListening = false
                    self.isPaused = false
                }
            }
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
            isPaused = false
            // Resume duration tracking from paused offset
            recordingStartTime = Date()
            startDurationTimer()
            Logger.shared.info("Recording resumed from \(pausedTimeOffset)s")
        } catch {
            let error = SpeechError.audioEngineFailed(underlying: error)
            Logger.shared.error("Audio engine failed to resume: \(error)")
            onError?(error)
            throw error
        }
    }

    /// Clears transcription state and stops any active recording.
    /// 
    /// Cancels any ongoing recognition task, clears the transcribed text, and stops
    /// the audio engine if running. Use this to reset the manager to its initial state.
    func resetTranscription() {
        if isListening { stopListening() }
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        transcribedText = ""
        partialText = ""
    }

    /// Clears transcribed text while keeping recording active for continuous dictation.
    /// 
    /// This method is ideal for a "next thought" workflow where the user wants to
    /// start a new transcription without losing the recording session. If not currently
    /// listening, it simply clears the text.
    func clearAndContinue() {
        guard isListening else {
            transcribedText = ""
            return
        }
        stopListening()
        transcribedText = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            try? self?.startListening()
        }
    }

    // MARK: - Streaming Mode

    /// Whether streaming mode is currently active.
    @Published var isStreamingMode = false

    /// Accumulated text from streaming mode sessions.
    @Published var streamingAccumulatedText = ""

    /// Starts speech recognition in streaming mode with partial result callbacks.
    /// 
    /// In streaming mode, partial results are continuously reported via onPartialResult
    /// callback and partialText published property. This is ideal for real-time feedback
    /// where you want to see transcription as the user speaks.
    /// 
    /// - Throws: SpeechError if microphone is unavailable or audio engine fails to start.
    func startStreamingMode() throws {
        guard isAvailable, !isListening else { return }

        // Reset streaming state
        partialText = ""
        streamingAccumulatedText = ""
        isStreamingMode = true

        // Check microphone authorization
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        guard micStatus == .authorized else {
            let error = SpeechError.microphoneUnavailable
            onError?(error)
            throw error
        }

        // Cancel any lingering task
        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(macOS 13, *) {
            request.addsPunctuation = true
        }
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let transcription = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.transcribedText = transcription
                    self.partialText = transcription
                    self.onPartialResult?(transcription)
                }

                if result.isFinal {
                    DispatchQueue.main.async {
                        self.streamingAccumulatedText = transcription
                        self.onFinalResult?(transcription)
                    }
                }
            }

            if let error = error {
                let speechError = SpeechError.recognitionFailed(underlying: error)
                Logger.shared.error("Streaming recognition error: \(error)")
                DispatchQueue.main.async { [weak self] in
                    self?.onError?(speechError)
                }
            }

            if error != nil || (result?.isFinal == true) {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                DispatchQueue.main.async {
                    self.isListening = false
                    self.isStreamingMode = false
                }
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
            if UserDefaults.standard.bool(forKey: "playSounds") {
                NSSound(named: "Tink")?.play()
            }
        } catch {
            isStreamingMode = false
            let error = SpeechError.audioEngineFailed(underlying: error)
            Logger.shared.error("Streaming audio engine failed to start: \(error)")
            onError?(error)
            throw error
        }
    }

    /// Stops streaming mode and returns the accumulated text.
    /// 
    /// Ends the current streaming recognition session and returns all text captured
    /// during the session. The partialText is cleared but streamingAccumulatedText
    /// retains the final result until the next startStreamingMode() call.
    /// 
    /// - Returns: The accumulated transcribed text from the streaming session.
    func stopStreamingMode() -> String {
        guard isStreamingMode || isListening else { return streamingAccumulatedText }

        audioEngine.stop()
        recognitionRequest?.endAudio()
        isListening = false
        isStreamingMode = false
        partialText = ""

        if UserDefaults.standard.bool(forKey: "playSounds") {
            NSSound(named: "Pop")?.play()
        }

        return streamingAccumulatedText
    }
}