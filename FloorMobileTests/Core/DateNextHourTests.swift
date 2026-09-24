//
//  DateNextHourTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("Next hour")
struct DateNextHourTests {

    /// A fixed zone: the rule is about the clock face, and a machine in another
    /// zone must not read it differently.
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt
        return calendar
    }()

    private static func moment(_ hour: Int, _ minute: Int = 0, _ second: Int = 0) throws -> Date {
        try #require(Self.calendar.date(from: DateComponents(
            year: 2026, month: 9, day: 24, hour: hour, minute: minute, second: second
        )))
    }

    @Test("Part of an hour rounds up to the next one")
    func partOfAnHourRoundsUp() throws {
        #expect(try Self.moment(11, 50).nextHour(Self.calendar) == Self.moment(12))
    }

    @Test("An instant already on the hour moves on rather than standing still")
    func wholeHourMovesOn() throws {
        #expect(try Self.moment(12).nextHour(Self.calendar) == Self.moment(13))
    }

    @Test("Seconds go the same way the minutes do")
    func secondsAreDropped() throws {
        #expect(try Self.moment(11, 50, 43).nextHour(Self.calendar) == Self.moment(12))
    }

    @Test("Late enough in the evening, the next hour is tomorrow")
    func crossesMidnight() throws {
        let midnight = try #require(Self.calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 25, hour: 0)
        ))
        #expect(try Self.moment(23, 30).nextHour(Self.calendar) == midnight)
    }
}
