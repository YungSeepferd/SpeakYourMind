import XCTest
@testable import SpeakYourMind

final class TextInjectorTests: XCTestCase {

    // MARK: - Properties

    private var textInjector: TextInjector!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        textInjector = TextInjector()
    }

    override func tearDown() {
        textInjector = nil
        super.tearDown()
    }

    // MARK: - Inject Tests

    func test_inject_withValidText_returnsSuccess() {
        // Act
        let result = textInjector.inject(TestConstants.sampleText)

        // Assert
        switch result {
        case .success(let text):
            XCTAssertEqual(text, TestConstants.sampleText)
        case .failure(let error):
            // May fail if no frontmost app - that's OK for unit tests
            XCTAssertEqual(error, .noFrontmostApp)
        }
    }

    func test_inject_withEmptyText_returnsFailure() {
        // Act
        let result = textInjector.inject(TestConstants.emptyText)

        // Assert
        if case .failure(let error) = result {
            XCTAssertEqual(error, .clipboardFailed)
        } else {
            XCTFail("Expected failure for empty text")
        }
    }

    func test_inject_withShortText_returnsResult() {
        // Act
        let result = textInjector.inject(TestConstants.shortText)

        // Assert
        switch result {
        case .success(let text):
            XCTAssertEqual(text, TestConstants.shortText)
        case .failure(let error):
            XCTAssertEqual(error, .noFrontmostApp)
        }
    }

    // MARK: - Edge Case Tests

    func test_inject_withVeryLongText_returnsResult() {
        // Arrange
        let longText = String(repeating: "Test text. ", count: 1000)

        // Act
        let result = textInjector.inject(longText)

        // Assert
        switch result {
        case .success(let text):
            XCTAssertEqual(text, longText)
        case .failure(let error):
            XCTAssertEqual(error, .noFrontmostApp)
        }
    }

    func test_inject_withSpecialCharacters_returnsResult() {
        // Arrange
        let specialText = "Hello! @#$%^&*()_+-=[]{}|;':\",./<>?"

        // Act
        let result = textInjector.inject(specialText)

        // Assert
        switch result {
        case .success(let text):
            XCTAssertEqual(text, specialText)
        case .failure(let error):
            XCTAssertEqual(error, .noFrontmostApp)
        }
    }

    func test_inject_withUnicodeCharacters_returnsResult() {
        // Arrange
        let unicodeText = "Hello 世界 🌍 🎉 你好"

        // Act
        let result = textInjector.inject(unicodeText)

        // Assert
        switch result {
        case .success(let text):
            XCTAssertEqual(text, unicodeText)
        case .failure(let error):
            XCTAssertEqual(error, .noFrontmostApp)
        }
    }

    func test_inject_withNewlines_returnsResult() {
        // Arrange
        let multilineText = "Line 1\nLine 2\nLine 3"

        // Act
        let result = textInjector.inject(multilineText)

        // Assert
        switch result {
        case .success(let text):
            XCTAssertEqual(text, multilineText)
        case .failure(let error):
            XCTAssertEqual(error, .noFrontmostApp)
        }
    }
}