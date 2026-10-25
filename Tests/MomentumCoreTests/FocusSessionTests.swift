import XCTest
@testable import MomentumCore

final class FocusSessionTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    func testTenAndTwentyFiveMinuteDeadlines() {
        for minutes in [10, 25] {
            var session = FocusSession()
            session.start(minutes: minutes, taskTitle: "Open the draft", now: start)
            XCTAssertEqual(session.deadline, start.addingTimeInterval(Double(minutes * 60)))
            XCTAssertEqual(session.clockText(at: start), minutes == 10 ? "10:00" : "25:00")
        }
    }

    func testPauseDoesNotConsumeTimeAndResumeUsesRemainingTime() {
        var session = FocusSession()
        session.start(minutes: 10, taskTitle: "Draft", now: start)
        session.pause(now: start.addingTimeInterval(90))
        XCTAssertEqual(session.remaining(at: start.addingTimeInterval(5_000)), 510)
        session.resume(now: start.addingTimeInterval(5_000))
        XCTAssertEqual(session.deadline, start.addingTimeInterval(5_510))
    }

    func testSleepAndRelaunchReconcileToFinishedExactlyOnce() throws {
        var session = FocusSession()
        session.start(minutes: 25, taskTitle: "Write one paragraph", now: start)
        let data = try JSONEncoder().encode(session)
        var restored = try JSONDecoder().decode(FocusSession.self, from: data)
        XCTAssertTrue(restored.reconcile(now: start.addingTimeInterval(2_000)))
        XCTAssertEqual(restored.phase, .finished)
        XCTAssertEqual(restored.clockText(at: start.addingTimeInterval(2_000)), "00:00")
        XCTAssertFalse(restored.reconcile(now: start.addingTimeInterval(3_000)))
        XCTAssertEqual(restored.taskTitle, "Write one paragraph")
    }

    func testPausedSessionSurvivesEncoding() throws {
        var session = FocusSession()
        session.start(minutes: 10, taskTitle: "Draft", now: start)
        session.pause(now: start.addingTimeInterval(100))
        let restored = try JSONDecoder().decode(FocusSession.self, from: JSONEncoder().encode(session))
        XCTAssertEqual(restored.phase, .paused)
        XCTAssertEqual(restored.remaining(at: start.addingTimeInterval(10_000)), 500)
    }

    func testPauseAtDeadlineFinishesAndClockNeverGoesNegative() {
        var session = FocusSession()
        session.start(minutes: 10, taskTitle: "", now: start)
        XCTAssertEqual(session.taskTitle, "One small step")
        XCTAssertEqual(session.clockText(at: start.addingTimeInterval(0.4)), "10:00")
        session.pause(now: start.addingTimeInterval(600))
        XCTAssertEqual(session.phase, .finished)
        XCTAssertEqual(session.remaining(at: start.addingTimeInterval(601)), 0)
        session.reset()
        XCTAssertEqual(session.phase, .idle)
    }

    func testUnsupportedDurationDoesNotStart() {
        var session = FocusSession()
        session.start(minutes: -10, taskTitle: "Draft", now: start)
        XCTAssertEqual(session.phase, .idle)
    }
}
