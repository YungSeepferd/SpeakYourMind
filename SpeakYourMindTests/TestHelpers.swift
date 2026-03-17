import Foundation
import XCTest
import AVFoundation
import Speech
import Combine

// MARK: - Async Helper

/// Helper to wait for async expectations with a timeout
func waitForExpectation(
    timeout: TimeInterval = 5.0,
    file: StaticString = #file,
    line: UInt = #line,
    action: (XCTestExpectation) -> Void
) {
    let expectation = XCTestExpectation(description: "Async operation")
    action(expectation)
    let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
    if result != .completed {
        XCTFail("Expectation timed out or failed", file: file, line: line)
    }
}

// MARK: - Mock Objects

/// Mock for capturing callback invocations
final class CallbackCaptor<T> {
    private(set) var capturedValues: [T] = []
    private(set) var callCount = 0

    func capture(_ value: T) {
        capturedValues.append(value)
        callCount += 1
    }

    func reset() {
        capturedValues.removeAll()
        callCount = 0
    }
}

/// Mock for AVSpeechSynthesizer to avoid actual speech
final class MockSpeechSynthesizer {
    var speakCalled = false
    var lastUtterance: String?

    func speak(_ utterance: AVSpeechUtterance) {
        speakCalled = true
        lastUtterance = utterance.speechString
    }
}

/// Stub for NSPasteboard
final class StubPasteboard {
    static var shared: StubPasteboard?

    var changeCountValue = 0
    var stringValue: String?
    var items: [NSPasteboardItem]?

    var changeCount: Int {
        get { changeCountValue }
        set { changeCountValue = newValue }
    }

    func clearContents() {
        changeCountValue += 1
    }

    func setString(_ string: String, forType type: NSPasteboard.PasteboardType) {
        stringValue = string
        changeCountValue += 1
    }

    func string(forType type: NSPasteboard.PasteboardType) -> String? {
        stringValue
    }

    func pasteboardItems() -> [NSPasteboardItem]? {
        items
    }

    func writeObjects(_ objects: [NSPasteboardItem]) {
        // No-op for testing
    }
}

// MARK: - Test Constants

enum TestConstants {
    static let sampleText = "Hello, this is a test transcription."
    static let anotherText = "Another piece of text to inject."
    static let shortText = "Hi"
    static let emptyText = ""
}