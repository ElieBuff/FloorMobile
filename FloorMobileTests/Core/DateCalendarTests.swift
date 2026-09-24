//
//  DateCalendarTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

/// The two bounds every day-scoped `@Query` in the agenda is built from, so an
/// error here shows up as a day that quietly holds the wrong rows.
@Suite("Day bounds")
struct DateCalendarTests {

    @Test("Any hour of a day answers the same midnight")
    func startOfDayIgnoresTheHour() throws {
        let calendar = Calendar.current
        let noon = try #require(calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 24, hour: 12)
        ))
        let lateEvening = try #require(calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 24, hour: 23, minute: 59)
        ))

        #expect(noon.startOfDay == lateEvening.startOfDay)
        #expect(calendar.component(.hour, from: noon.startOfDay) == 0)
    }

    @Test("The next day's bound is midnight, and it is the day after")
    func startOfNextDayIsTheFollowingMidnight() throws {
        let calendar = Calendar.current
        let noon = try #require(calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 24, hour: 12)
        ))

        let next = noon.startOfNextDay
        #expect(calendar.component(.day, from: next) == 25)
        #expect(calendar.component(.hour, from: next) == 0)
        #expect(next > noon.startOfDay)
    }

    /// The bound is a calendar day, not 86,400 seconds. On the day a clock
    /// goes forward or back the two differ by an hour, and a day queried in
    /// seconds would drop its last appointment or borrow the next day's first.
    @Test("A day that is not 24 hours long still ends at midnight")
    func springForwardStillEndsAtMidnight() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Paris"))
        // 29 March 2026: clocks go forward at 02:00, so this day is 23 hours.
        let springForward = try #require(calendar.date(
            from: DateComponents(year: 2026, month: 3, day: 29, hour: 12)
        ))

        let start = calendar.startOfDay(for: springForward)
        let next = try #require(calendar.date(byAdding: .day, value: 1, to: start))

        #expect(calendar.component(.hour, from: next) == 0)
        #expect(next.timeIntervalSince(start) != 86_400)
    }
}
