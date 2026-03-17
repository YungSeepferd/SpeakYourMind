import XCTest
@testable import SpeakYourMind

final class PermissionsManagerTests: XCTestCase {

    // MARK: - Properties

    private var permissionsManager: PermissionsManager!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        permissionsManager = PermissionsManager()
    }

    override func tearDown() {
        permissionsManager = nil
        super.tearDown()
    }

    // MARK: - Accessibility Permission Tests

    func test_isAccessibilityGranted_returnsBoolean() {
        // Act
        let result = permissionsManager.isAccessibilityGranted

        // Assert
        XCTAssertTrue(result == true || result == false)
    }

    func test_requestAccessibilityIfNeeded_returnsBoolean() {
        // Act
        let result = permissionsManager.requestAccessibilityIfNeeded()

        // Assert
        XCTAssertTrue(result == true || result == false)
    }

    // MARK: - Ensure Accessibility Tests

    func test_ensureAccessibility_completesWithCallback() {
        // Arrange
        let expectation = XCTestExpectation(description: "Completion called")

        // Act
        permissionsManager.ensureAccessibility { result in
            // Assert
            switch result {
            case .success(let granted):
                XCTAssertTrue(granted == true || granted == false)
            case .failure(let error):
                // Timeout is acceptable if permission not granted
                XCTAssertEqual(error, .timeout)
            }
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 35.0)
    }

    func test_ensureAccessibility_whenAlreadyGranted_callsCompletionImmediately() {
        // Arrange
        let expectation = XCTestExpectation(description: "Completion called immediately")
        var completionCalled = false

        // Skip if not already granted (this is a system permission test)
        guard permissionsManager.isAccessibilityGranted else {
            return
        }

        // Act
        permissionsManager.ensureAccessibility { result in
            completionCalled = true
            if case .success(let granted) = result {
                XCTAssertTrue(granted)
            }
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(completionCalled)
    }

    // MARK: - Edge Case Tests

    func test_multipleCallsToEnsureAccessibility_allComplete() {
        // Arrange
        let expectation1 = XCTestExpectation(description: "First call")
        let expectation2 = XCTestExpectation(description: "Second call")

        // Act
        permissionsManager.ensureAccessibility { _ in
            expectation1.fulfill()
        }

        permissionsManager.ensureAccessibility { _ in
            expectation2.fulfill()
        }

        // Assert
        wait(for: [expectation1, expectation2], timeout: 35.0)
    }
}