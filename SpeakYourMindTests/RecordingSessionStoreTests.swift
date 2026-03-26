import XCTest
import Combine
@testable import SpeakYourMind

final class RecordingSessionStoreTests: XCTestCase {

    // MARK: - Properties

    private var store: RecordingSessionStore!
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "recordingSessions")
        store = RecordingSessionStore()
    }

    override func tearDown() {
        store.deleteAllSessions()
        store.saveSessions()
        store = nil
        UserDefaults.standard.removeObject(forKey: "recordingSessions")
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func test_initialState_isEmpty() {
        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertNil(store.selectedSessionId)
    }

    func test_initialState_currentSessionIsNil() {
        XCTAssertNil(store.currentSession)
    }

    // MARK: - Create Session Tests

    func test_createNewSession_addsToSessions() {
        XCTAssertTrue(store.sessions.isEmpty)

        let session = store.createNewSession()

        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions.first?.id, session.id)
    }

    func test_createNewSession_setsSelectedId() {
        XCTAssertNil(store.selectedSessionId)

        let session = store.createNewSession()

        XCTAssertEqual(store.selectedSessionId, session.id)
    }

    func test_createNewSession_returnsNewSession() {
        let session = store.createNewSession()

        XCTAssertFalse(session.text.isEmpty == false)
        XCTAssertFalse(session.isCompleted)
        XCTAssertEqual(session.duration, 0)
    }

    func test_createMultipleSessions_keepsAll() {
        _ = store.createNewSession()
        _ = store.createNewSession()

        XCTAssertEqual(store.sessions.count, 2)
    }

    func test_createMultipleSessions_selectsLastCreated() {
        let session1 = store.createNewSession()
        let session2 = store.createNewSession()

        XCTAssertEqual(store.selectedSessionId, session2.id)
        XCTAssertNotEqual(store.selectedSessionId, session1.id)
    }

    // MARK: - Select Session Tests

    func test_selectSession_updatesSelectedId() {
        let session1 = store.createNewSession()
        let session2 = store.createNewSession()

        store.selectSession(session1.id)

        XCTAssertEqual(store.selectedSessionId, session1.id)
        XCTAssertEqual(store.currentSession?.id, session1.id)
    }

    // MARK: - Update Text Tests

    func test_updateCurrentText_updatesSession() {
        _ = store.createNewSession()
        let newText = TestConstants.sampleText

        store.updateCurrentText(newText)

        XCTAssertEqual(store.currentSession?.text, newText)
    }

    func test_updateCurrentText_noSession_doesNotCrash() {
        store.updateCurrentText(TestConstants.sampleText)
    }

    func test_updateCurrentText_reflectsInSessions() {
        let session = store.createNewSession()
        let newText = "Updated text"

        store.updateCurrentText(newText)

        if let updatedSession = store.sessions.first(where: { $0.id == session.id }) {
            XCTAssertEqual(updatedSession.text, newText)
        } else {
            XCTFail("Session not found")
        }
    }

    // MARK: - Update Duration Tests

    func test_updateCurrentDuration_updatesSession() {
        _ = store.createNewSession()
        let newDuration: TimeInterval = 30.0

        store.updateCurrentDuration(newDuration)

        XCTAssertEqual(store.currentSession?.duration, newDuration)
    }

    // MARK: - Mark Completed Tests

    func test_markCurrentCompleted_updatesSession() {
        let session = store.createNewSession()
        XCTAssertFalse(session.isCompleted)

        store.markCurrentCompleted()

        XCTAssertTrue(store.currentSession?.isCompleted ?? false)
    }

    // MARK: - Delete Session Tests

    func test_deleteSession_removesSession() {
        let session1 = store.createNewSession()
        let session2 = store.createNewSession()

        store.deleteSession(session1.id)

        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertFalse(store.sessions.contains { $0.id == session1.id })
        XCTAssertTrue(store.sessions.contains { $0.id == session2.id })
    }

    func test_deleteSession_selectedSession_updatesSelection() {
        let session1 = store.createNewSession()
        let session2 = store.createNewSession()
        store.selectSession(session1.id)

        store.deleteSession(session1.id)

        XCTAssertEqual(store.selectedSessionId, session2.id)
    }

    func test_deleteSession_lastSession_clearsSelection() {
        let session = store.createNewSession()

        store.deleteSession(session.id)

        XCTAssertNil(store.selectedSessionId)
    }

    func test_deleteSession_nonExistentId_doesNotCrash() {
        let session = store.createNewSession()

        store.deleteSession(UUID())

        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.selectedSessionId, session.id)
    }

    // MARK: - Delete All Sessions Tests

    func test_deleteAllSessions_clearsAll() {
        _ = store.createNewSession()
        _ = store.createNewSession()

        store.deleteAllSessions()

        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertNil(store.selectedSessionId)
    }

    func test_deleteAllSessions_resetsCurrentSession() {
        _ = store.createNewSession()

        store.deleteAllSessions()

        XCTAssertNil(store.currentSession)
    }

    // MARK: - Current Session Tests

    func test_currentSession_returnsSelectedSession() {
        let session1 = store.createNewSession()
        _ = store.createNewSession()
        store.selectSession(session1.id)

        XCTAssertEqual(store.currentSession?.id, session1.id)
    }

    func test_currentSession_nilWhenNoSessions() {
        XCTAssertNil(store.currentSession)
    }

    func test_currentSession_setNewValue_updatesSession() {
        _ = store.createNewSession()
        _ = store.createNewSession()
        let session2 = store.createNewSession()

        store.currentSession = session2

        XCTAssertEqual(store.sessions.first { $0.id == session2.id }?.text, session2.text)
    }

    func test_currentSession_setNewValue_appendsIfNotExists() {
        _ = store.createNewSession()
        let session2 = RecordingSession()

        store.currentSession = session2

        XCTAssertEqual(store.sessions.count, 2)
        XCTAssertTrue(store.sessions.contains { $0.id == session2.id })
    }

    // MARK: - Selected Session Index Tests

    func test_selectedSessionIndex_returnsCorrectIndex() {
        let session1 = store.createNewSession()
        let session2 = store.createNewSession()
        store.selectSession(session1.id)

        XCTAssertEqual(store.selectedSessionIndex, 0)

        store.selectSession(session2.id)

        XCTAssertEqual(store.selectedSessionIndex, 1)
    }

    func test_selectedSessionIndex_noSelection_returnsNegativeOne() {
        _ = store.createNewSession()
        store.deleteAllSessions()

        XCTAssertEqual(store.selectedSessionIndex, -1)
    }

    // MARK: - Persistence Tests

    func test_saveSessions_persistsToUserDefaults() {
        _ = store.createNewSession()
        store.updateCurrentText(TestConstants.sampleText)

        store.saveSessions()

        let data = UserDefaults.standard.data(forKey: "recordingSessions")
        XCTAssertNotNil(data)
    }

    func test_loadSessions_restoresFromUserDefaults() {
        _ = store.createNewSession()
        let text = "Persisted text"
        store.updateCurrentText(text)
        store.saveSessions()

        let newStore = RecordingSessionStore()

        XCTAssertEqual(newStore.sessions.count, 1)
        XCTAssertEqual(newStore.sessions.first?.text, text)
    }

    func test_loadSessions_restoresSelectedSession() {
        let session = store.createNewSession()
        store.saveSessions()

        let newStore = RecordingSessionStore()

        XCTAssertEqual(newStore.selectedSessionId, session.id)
    }

    func test_loadSessions_noData_loadsEmpty() {
        UserDefaults.standard.removeObject(forKey: "recordingSessions")

        let newStore = RecordingSessionStore()

        XCTAssertTrue(newStore.sessions.isEmpty)
        XCTAssertNil(newStore.selectedSessionId)
    }

    func test_deleteAllSessions_doesNotAffectPersistence() {
        _ = store.createNewSession()
        store.saveSessions()

        let initialNewStoreSessionCount = RecordingSessionStore().sessions.count
        store.deleteAllSessions()

        XCTAssertEqual(RecordingSessionStore().sessions.count, initialNewStoreSessionCount)
    }

    func test_persistence_multipleSessions() {
        _ = store.createNewSession()
        store.updateCurrentText("First session")
        _ = store.createNewSession()
        store.updateCurrentText("Second session")

        store.saveSessions()

        let newStore = RecordingSessionStore()

        XCTAssertEqual(newStore.sessions.count, 2)
        XCTAssertNotNil(newStore.selectedSessionId)
    }
}
