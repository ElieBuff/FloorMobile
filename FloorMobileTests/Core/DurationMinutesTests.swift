//
//  DurationMinutesTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("Duration from minutes")
struct DurationMinutesTests {

    @Test("Minutes become the seconds the API counts", arguments: [0, 15, 30, 45, 60, 90, 120, 1440])
    func minutesAreSixtySeconds(count: Int) {
        #expect(Duration.minutes(count) == .seconds(count * 60))
    }

    @Test("A negative count runs backwards rather than clamping")
    func negativeMinutesGoBackwards() {
        // A reminder offset is subtracted from a start date, so the sign has to
        // survive the conversion.
        #expect(Duration.minutes(-30) == .seconds(-1800))
    }

    /// The wording belongs to the locale, so the test pins what the *choice of
    /// units* guarantees rather than the strings themselves: past an hour, the
    /// label must not read as a raw count of minutes.
    @Test("Past an hour the label stops counting in minutes alone")
    func longDurationsCarryAnHour() {
        #expect(!Duration.minutes(90).hoursAndMinutes.contains("90"))
        #expect(!Duration.minutes(120).hoursAndMinutes.contains("120"))
    }

    @Test("Under an hour the label is minutes alone")
    func shortDurationsAreMinutesOnly() {
        #expect(Duration.minutes(30).hoursAndMinutes.contains("30"))
    }
}
