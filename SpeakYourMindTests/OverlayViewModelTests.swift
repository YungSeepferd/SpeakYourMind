import XCTest
import Combine
@testable import SpeakYourMind

final class OverlayViewModelTests: XCTestCase {

    // MARK: - Properties

    private var viewModel: OverlayViewModel!
    private var speechManager: SpeechManager!
    private var sessionStore: RecordingSessionStore!
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        speechManager = SpeechManager()
        sessionStore = RecordingSessionStore()
        UserDefaults.standard.removeObject(forKey: "recordingSessions")
        viewModel = OverlayViewModel(
            speechManager: speechManager,
            sessionStore: sessionStore,
            feedbackManager: UserFeedbackManager.shared
        )
    }

    override func tearDown() {
        viewModel = nil
        sessionStore.deleteAllSessions()
        sessionStore.saveSessions()
        sessionStore = nil
        speechManager = nil
        cancellables.removeAll()
        UserDefaults.standard.removeObject(forKey: "recordingSessions")
        super.tearDown()
    }

    // MARK: - Mode Tests

    func test_setMode_updatesCurrentMode() {
        XCTAssertEqual(viewModel.currentMode, .idle)

        viewModel.setMode(.overlayDictation)
        XCTAssertEqual(viewModel.currentMode, .overlayDictation)

        viewModel.setMode(.instantDictation)
        XCTAssertEqual(viewModel.currentMode, .instantDictation)

        viewModel.setMode(.edgeCapture)
        XCTAssertEqual(viewModel.currentMode, .edgeCapture)

        viewModel.setMode(.idle)
        XCTAssertEqual(viewModel.currentMode, .idle)
    }

    func test_setMode_updatesStatusMessage() {
        viewModel.setMode(.overlayDictation)
        XCTAssertEqual(viewModel.statusMessage, "Overlay ready")

        viewModel.setMode(.instantDictation)
        XCTAssertEqual(viewModel.statusMessage, "Instant ready")

        viewModel.setMode(.edgeCapture)
        XCTAssertEqual(viewModel.statusMessage, "Edge ready")

        viewModel.setMode(.processingAI)
        XCTAssertEqual(viewModel.statusMessage, "Processing AI…")
    }

    // MARK: - Output Action Tests

    func test_setOutputAction_updatesAction() {
        XCTAssertEqual(viewModel.outputAction, .saveSessionOnly)

        viewModel.setOutputAction(.injectOnStop)
        XCTAssertEqual(viewModel.outputAction, .injectOnStop)

        viewModel.setOutputAction(.copyToClipboard)
        XCTAssertEqual(viewModel.outputAction, .copyToClipboard)

        viewModel.setOutputAction(.saveSessionOnly)
        XCTAssertEqual(viewModel.outputAction, .saveSessionOnly)
    }

    // MARK: - Recording Start Tests

    func test_startRecording_createsSession() {
        XCTAssertNil(sessionStore.selectedSessionId)
        XCTAssertTrue(sessionStore.sessions.isEmpty)

        viewModel.startRecording()

        XCTAssertNotNil(sessionStore.selectedSessionId)
        XCTAssertEqual(sessionStore.sessions.count, 1)
        XCTAssertTrue(viewModel.isRecording)
    }

    func test_startRecording_updatesStatusMessage() {
        viewModel.setMode(.overlayDictation)
        viewModel.startRecording()

        XCTAssertEqual(viewModel.statusMessage, "Recording to overlay…")
    }

    // MARK: - Recording Stop Tests

    func test_stopRecording_savesSession() {
        viewModel.startRecording()
        speechManager.transcribedText = TestConstants.sampleText

        viewModel.stopRecording()

        XCTAssertFalse(viewModel.isRecording)
        XCTAssertTrue(sessionStore.sessions.first?.isCompleted ?? false)
    }

    func test_stopRecording_updatesStatusMessage() {
        viewModel.setMode(.overlayDictation)
        viewModel.startRecording()
        viewModel.stopRecording()

        XCTAssertEqual(viewModel.statusMessage, "Overlay ready")
    }

    // MARK: - Pause/Resume Tests

    func test_pauseResume_preservesTranscript() {
        viewModel.startRecording()
        speechManager.transcribedText = TestConstants.sampleText
        viewModel.pauseRecording()

        XCTAssertTrue(viewModel.isPaused)
        XCTAssertFalse(viewModel.isRecording)

        viewModel.resumeRecording()

        XCTAssertFalse(viewModel.isPaused)
        XCTAssertTrue(viewModel.isRecording)
        XCTAssertEqual(speechManager.transcribedText, TestConstants.sampleText)
    }

    // MARK: - Clear Text Tests

    func test_clearText_keepsRecording() {
        viewModel.startRecording()
        speechManager.transcribedText = TestConstants.sampleText

        viewModel.clearText()

        XCTAssertEqual(speechManager.transcribedText, "")
        XCTAssertTrue(viewModel.isRecording)
    }

    // MARK: - Delete All Tests

    func test_deleteAll_resetsTranscription() {
        viewModel.startRecording()
        speechManager.transcribedText = TestConstants.sampleText

        viewModel.deleteAll()

        XCTAssertEqual(speechManager.transcribedText, "")
    }

    // MARK: - AI Processing Tests

    func test_processTextWithAI_noOllamaManager_returnsError() {
        let expectation = XCTestExpectation(description: "Callback invoked")
        var callbackError: Error?

        viewModel.startRecording()
        speechManager.transcribedText = TestConstants.sampleText

        viewModel.processTextWithAI(
            instruction: "capitalize",
            ollamaManager: nil,
            settingsViewModel: nil
        ) { result in
            if case .failure(let error) = result {
                callbackError = error
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(callbackError)
        XCTAssertEqual(viewModel.aiErrorMessage, "Ollama is not configured")
    }

    func test_processTextWithAI_emptyText_returnsError() {
        let expectation = XCTestExpectation(description: "Callback invoked")
        let ollamaManager = OllamaManager()

        viewModel.startRecording()

        viewModel.processTextWithAI(
            instruction: "capitalize",
            ollamaManager: ollamaManager,
            settingsViewModel: nil
        ) { result in
            if case .failure = result {
                // Expected - empty text should fail
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
        XCTAssertFalse(viewModel.isProcessingAI)
    }

    func test_processTextWithAI_setsProcessingState() {
        let ollamaManager = OllamaManager()

        viewModel.startRecording()
        speechManager.transcribedText = TestConstants.sampleText

        viewModel.processTextWithAI(
            instruction: "capitalize",
            ollamaManager: ollamaManager,
            settingsViewModel: nil
        ) { _ in }

        XCTAssertTrue(viewModel.isProcessingAI)
    }

    // MARK: - Clipboard Tests

    func test_copyToClipboard_setsPasteboard() {
        viewModel.startRecording()
        speechManager.transcribedText = TestConstants.sampleText

        viewModel.copyToClipboard()

        let pasteboard = NSPasteboard.general
        XCTAssertEqual(pasteboard.string(forType: .string), TestConstants.sampleText)
    }

    // MARK: - New Session Tests

    func test_newSession_createsNewSession() {
        viewModel.startRecording()
        let firstSessionId = sessionStore.selectedSessionId

        viewModel.newSession()

        XCTAssertNotEqual(sessionStore.selectedSessionId, firstSessionId)
        XCTAssertEqual(sessionStore.sessions.count, 2)
    }

    func test_newSession_clearsTranscription() {
        viewModel.startRecording()
        speechManager.transcribedText = TestConstants.sampleText

        viewModel.newSession()

        XCTAssertEqual(speechManager.transcribedText, "")
    }

    // MARK: - Status Message Tests

    func test_statusMessage_reflectsProcessingMode() {
        viewModel.setMode(.processingAI)

        XCTAssertEqual(viewModel.statusMessage, "Processing AI…")
    }

    func test_statusMessage_reflectsErrorMode() {
        viewModel.setMode(.error)

        XCTAssertEqual(viewModel.statusMessage, "Error")
    }

    // MARK: - Has Text Tests

    func test_hasText_trueWhenTextPresent() {
        viewModel.startRecording()
        speechManager.transcribedText = TestConstants.sampleText

        viewModel.clearText()
        XCTAssertFalse(viewModel.hasText)

        speechManager.transcribedText = TestConstants.sampleText
        XCTAssertTrue(viewModel.hasText)
    }

    // MARK: - Ollama Available Tests

    func test_ollamaAvailable_initiallyFalse() {
        XCTAssertFalse(viewModel.ollamaAvailable)
    }

    // MARK: - Is Recording/Paused State Tests

    func test_isRecording_initiallyFalse() {
        XCTAssertFalse(viewModel.isRecording)
    }

    func test_isPaused_initiallyFalse() {
        XCTAssertFalse(viewModel.isPaused)
    }

    // MARK: - OutputAction Description Tests

    func test_outputAction_description() {
        XCTAssertEqual(OutputAction.saveSessionOnly.description, "Save to Session")
        XCTAssertEqual(OutputAction.injectOnStop.description, "Inject on Stop")
        XCTAssertEqual(OutputAction.copyToClipboard.description, "Copy to Clipboard")
    }
}
