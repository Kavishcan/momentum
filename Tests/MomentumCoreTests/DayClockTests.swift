import XCTest
@testable import MomentumCore

final class DayClockTests: XCTestCase {
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

    func testDailyTasksUseLocalCalendarDate() {
        let instant = date("2026-10-24T20:00:00Z")
        XCTAssertEqual(DayClock.dayKey(for: instant, timeZone: TimeZone(identifier: "Asia/Colombo")!), "2026-10-25")
        XCTAssertEqual(DayClock.dayKey(for: instant, timeZone: TimeZone(secondsFromGMT: 0)!), "2026-10-24")
    }

    func testNightContinuesAfterMidnightAndResetsAtNoon() {
        let utc = TimeZone(secondsFromGMT: 0)!
        XCTAssertEqual(DayClock.nightKey(for: date("2026-10-24T22:00:00Z"), timeZone: utc), "2026-10-24")
        XCTAssertEqual(DayClock.nightKey(for: date("2026-10-25T00:30:00Z"), timeZone: utc), "2026-10-24")
        XCTAssertEqual(DayClock.nightKey(for: date("2026-10-25T11:59:59Z"), timeZone: utc), "2026-10-24")
        XCTAssertEqual(DayClock.nightKey(for: date("2026-10-25T12:00:00Z"), timeZone: utc), "2026-10-25")
    }

    func testNightBoundaryAcrossDaylightSavingAndYearBoundary() {
        let la = TimeZone(identifier: "America/Los_Angeles")!
        XCTAssertEqual(DayClock.nightKey(for: date("2026-11-01T09:30:00Z"), timeZone: la), "2026-10-31")
        XCTAssertEqual(DayClock.nightKey(for: date("2027-01-01T09:00:00Z"), timeZone: la), "2026-12-31")
    }

    func testReminderPlanRejectsInvalidTimesAndFollowsLocalZone() throws {
        XCTAssertNil(ReminderPlan(hour: 24, minute: 0))
        XCTAssertNil(ReminderPlan(hour: 22, minute: -1))
        let plan = try XCTUnwrap(ReminderPlan(hour: 22, minute: 15))
        XCTAssertEqual(plan.dateComponents.hour, 22)
        XCTAssertEqual(plan.dateComponents.minute, 15)
        XCTAssertNil(plan.dateComponents.timeZone)
        XCTAssertNil(plan.dateComponents.day)
        XCTAssertEqual(ReminderPlan.identifier, "momentum.night-shutdown")
    }
}
