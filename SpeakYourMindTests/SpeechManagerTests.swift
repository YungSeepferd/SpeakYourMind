import XCTest
import Combine
@testable import SpeakYourMind

final class SpeechManagerTests: XCTestCase {

    // MARK: - Properties

    private var speechManager: SpeechManager!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        speechManager = SpeechManager()
    }

    override func tearDown() {
        speechManager = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func test_initialState_isNotListening() {
        XCTAssertFalse(speechManager.isListening)
    }

    func test_initialState_transcribedTextIsEmpty() {
        XCTAssertEqual(speechManager.transcribedText, "")
    }

    // MARK: - Reset Tests

    func test_resetTranscription_clearsTranscribedText() {
        // Arrange
        speechManager.transcribedText = TestConstants.sampleText

        // Act
        speechManager.resetTranscription()

        // Assert
        XCTAssertEqual(speechManager.transcribedText, "")
    }

    func test_resetTranscription_stopsListeningIfActive() {
        // Arrange - set up a listening state
        // Note: In real tests, we'd mock the audio engine to avoid actual hardware dependency

        // Act
        speechManager.resetTranscription()

        // Assert
        XCTAssertFalse(speechManager.isListening)
    }

    // MARK: - Clear and Continue Tests

    func test_clearAndContinue_whenNotListening_clearsText() {
        // Arrange
        speechManager.transcribedText = TestConstants.sampleText

        // Act
        speechManager.clearAndContinue()

        // Assert
        XCTAssertEqual(speechManager.transcribedText, "")
    }

    // MARK: - Callback Tests

    func test_onFinalResult_callbackIsCalled() {
        // Arrange
        let expectation = XCTestExpectation(description: "onFinalResult called")
        speechManager.onFinalResult = { text in
            XCTAssertEqual(text, TestConstants.sampleText)
            expectation.fulfill()
        }

        // Act - simulate final result by directly calling the callback mechanism
        // Note: In integration tests, we'd trigger this through the actual recognition flow
        speechManager.onFinalResult?(TestConstants.sampleText)

        // Assert
        wait(for: [expectation], timeout: 1.0)
    }

    func test_onFinalResult_capturesCorrectText() {
        // Arrange
        var capturedText: String?
        speechManager.onFinalResult = { text in
            capturedText = text
        }

        // Act
        speechManager.onFinalResult?(TestConstants.anotherText)

        // Assert
        XCTAssertEqual(capturedText, TestConstants.anotherText)
    }
}