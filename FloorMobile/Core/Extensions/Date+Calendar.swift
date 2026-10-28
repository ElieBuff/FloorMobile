//
//  Date+Calendar.swift
//  FloorMobile
//

import Foundation

nonisolated extension Date {
    /// Midnight at the start of this date's day, in the current calendar.
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// Midnight at the start of the day after this date's day.
    var startOfNextDay: Date {
        let start = startOfDay
        return Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
    }

    /// This date's day in `timeZone`, as the filters' date parameters take it:
    /// `YYYY-MM-DD`, the day the associate sees, never the UTC one — a 1 July
    /// picked in Auckland stays 1 July. ISO 8601, so a Gregorian year whatever
    /// the device's calendar, as the server reads it (`isCalendarDay`). The time
    /// zone is a parameter so that tests can fix one.
    func calendarDay(in timeZone: TimeZone = .current) -> String {
        formatted(Self.calendarDayStyle(in: timeZone))
    }

    /// The start of `calendarDay`'s day in `timeZone`, or `nil` for a text that
    /// is not a day as `calendarDay(in:)` writes it.
    init?(calendarDay: String, in timeZone: TimeZone = .current) {
        guard let date = try? Date(calendarDay, strategy: Self.calendarDayStyle(in: timeZone)) else { return nil }
        self = date
    }

    /// `YYYY-MM-DD` in `timeZone`.
    private static func calendarDayStyle(in timeZone: TimeZone) -> Date.ISO8601FormatStyle {
        Date.ISO8601FormatStyle(timeZone: timeZone).year().month().day()
    }
}
