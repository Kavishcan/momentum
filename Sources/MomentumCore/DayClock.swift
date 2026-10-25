import Foundation

public enum DayClock {
    /// Calendar-local Gregorian key; it does not change when the UI language changes.
    public static func dayKey(for date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    /// A night runs noon-to-noon so checking a step at 00:30 belongs to the same evening.
    public static func nightKey(for date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let day = calendar.component(.hour, from: date) < 12
            ? calendar.date(byAdding: .day, value: -1, to: date)!
            : date
        return dayKey(for: day, timeZone: timeZone)
    }
}

public struct ReminderPlan: Equatable, Sendable {
    public static let identifier = "momentum.night-shutdown"
    public let hour: Int
    public let minute: Int

    public init?(hour: Int, minute: Int) {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        self.hour = hour
        self.minute = minute
    }

    public var dateComponents: DateComponents {
        // No fixed time zone: follow the Mac's current local wall-clock time.
        DateComponents(hour: hour, minute: minute)
    }
}
